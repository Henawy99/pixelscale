import 'dart:io';
import 'dart:convert';

/// Service for printing ZPL labels on the Zebra ZD220 via macOS CUPS.
///
/// Labels are 50×30 mm at 203 dpi → 400 × 236 dots.
/// Sends raw ZPL bytes through the `lp` command (no additional packages needed).
class LabelPrinterService {
  LabelPrinterService._();

  // ─── ZPL label dimensions (50 mm × 30 mm at 203 dpi) ────────────────────
  static const int _labelWidthDots = 400; // 50 mm × 8 dots/mm (203 dpi ≈ 8 dots/mm)
  static const int _labelHeightDots = 236; // 30 mm × 8 dots/mm

  // ─── Printer name override (set via settings) ────────────────────────────
  /// If non-null, this name is used instead of auto-detection.
  static String? _overridePrinterName;

  /// Call this from the settings screen to pin a specific CUPS printer name.
  static void setOverridePrinterName(String? name) {
    _overridePrinterName = (name?.trim().isEmpty ?? true) ? null : name?.trim();
    print('[LabelPrinter] Printer name override set to: $_overridePrinterName');
  }

  static String? get overridePrinterName => _overridePrinterName;

  // ─── Auto-detect the Zebra printer from CUPS ─────────────────────────────
  /// Returns the CUPS printer name of the first Zebra/ZD220 printer found,
  /// or `null` if none is detected.
  static Future<String?> detectZebraPrinter() async {
    if (!Platform.isMacOS && !Platform.isLinux) return null;
    try {
      final result = await Process.run('lpstat', ['-p']);
      if (result.exitCode != 0) {
        print('[LabelPrinter] lpstat -p failed: ${result.stderr}');
        return null;
      }
      final lines = (result.stdout as String).split('\n');
      String? fallbackName;
      for (final line in lines) {
        // lpstat -p output: "printer ZD220_RAW is idle ..." or "printer Zebra_ZD220 is idle..."
        final lower = line.toLowerCase();
        // Prefer the dedicated raw ZPL queue (bypasses PPD rastertolabel filter)
        if (lower.contains('zd220_raw') || lower.contains('zd-220_raw')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            print('[LabelPrinter] Auto-detected raw ZPL queue: ${parts[1]}');
            return parts[1]; // Prefer raw queue immediately
          }
        }
        // Fall back to any Zebra/ZD220 queue
        if (lower.contains('zebra') || lower.contains('zd220') || lower.contains('zd-220')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            fallbackName = parts[1];
          }
        }
      }
      if (fallbackName != null) {
        print('[LabelPrinter] Auto-detected Zebra printer (fallback): $fallbackName');
        return fallbackName;
      }
      print('[LabelPrinter] No Zebra printer found in lpstat output.');
      return null;
    } catch (e) {
      print('[LabelPrinter] Exception during printer detection: $e');
      return null;
    }
  }

  /// Returns the effective printer name: override → auto-detect → null.
  static Future<String?> getEffectivePrinterName() async {
    if (_overridePrinterName != null && _overridePrinterName!.isNotEmpty) {
      return _overridePrinterName;
    }
    return detectZebraPrinter();
  }

  // ─── ZPL Generation ──────────────────────────────────────────────────────

  /// Generates a ZPL string for a single order-item label (50×30 mm).
  ///
  /// Layout: only the item name, large and centred.
  ///
  ///   ┌──────────────────────────────┐
  ///   │                              │
  ///   │    BBQ Bacon Smashed         │
  ///   │         Burger               │
  ///   │                              │
  ///   └──────────────────────────────┘
  static String generateZpl({
    required String itemName,
    required int quantity,
    required String orderId,
    String? orderType,
    String? fulfillmentType,
  }) {
    final zpl = StringBuffer();
    zpl.writeln('^XA');
    zpl.writeln('^PW$_labelWidthDots');  // 400 dots (50 mm)
    zpl.writeln('^LL$_labelHeightDots'); // 236 dots (30 mm)
    zpl.writeln('^CI28');                // UTF-8

    // ── Item name — large, centred, wraps up to 3 lines ─────────────────
    // ^FO10,40  → 10 dots from left, 40 from top (vertical centre)
    // ^A0N,60,54 → font height 60, width 54
    // ^FB380,3,6,C → 380-dot-wide block, max 3 lines, 6-dot spacing, centred
    zpl.writeln('^FO10,40^A0N,60,54^FB380,3,6,C^FD${_zplSafe(itemName)}^FS');

    zpl.writeln('^XZ');
    return zpl.toString();
  }

  // ─── Send to printer ─────────────────────────────────────────────────────

  /// Prints a single item label. Returns `true` on success.
  static Future<bool> printItemLabel({
    required String itemName,
    required int quantity,
    required String orderId,
    String? orderType,
    String? fulfillmentType,
  }) async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      print('[LabelPrinter] Label printing is only supported on macOS/Linux.');
      return false;
    }

    final printerName = await getEffectivePrinterName();
    if (printerName == null || printerName.isEmpty) {
      print('[LabelPrinter] No Zebra printer found. Label not printed.');
      return false;
    }

    final zpl = generateZpl(
      itemName: itemName,
      quantity: quantity,
      orderId: orderId,
      orderType: orderType,
      fulfillmentType: fulfillmentType,
    );

    return _sendRawZpl(printerName, zpl);
  }

  /// Sends raw ZPL content to the named CUPS printer via `lp`.
  static Future<bool> _sendRawZpl(String printerName, String zpl) async {
    try {
      // Write ZPL to a temp file then pipe it to lp.
      // Using stdin pipe avoids temp-file permission issues.
      final process = await Process.start(
        'lp',
        ['-d', printerName, '-o', 'raw', '-'],
      );

      // Send ZPL bytes via stdin
      process.stdin.add(utf8.encode(zpl));
      await process.stdin.close();

      final exitCode = await process.exitCode;
      final stderr = await process.stderr.transform(utf8.decoder).join();

      if (exitCode != 0) {
        print('[LabelPrinter] lp command failed (exit $exitCode): $stderr');
        return false;
      }
      print('[LabelPrinter] ✅ Label sent to "$printerName".');
      return true;
    } catch (e) {
      print('[LabelPrinter] Exception sending label: $e');
      return false;
    }
  }


  /// Escapes characters that would break ZPL field data.
  static String _zplSafe(String text) {
    return text
        .replaceAll('^', ' ')
        .replaceAll('~', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', '');
  }
}
