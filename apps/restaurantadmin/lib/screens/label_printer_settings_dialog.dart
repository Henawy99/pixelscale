import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurantadmin/services/label_printer_service.dart';

/// A dialog / bottom-sheet for configuring the Zebra ZD220 label printer.
/// Shows the auto-detected CUPS printer name and lets the admin override it.
class LabelPrinterSettingsDialog extends StatefulWidget {
  const LabelPrinterSettingsDialog({super.key});

  @override
  State<LabelPrinterSettingsDialog> createState() =>
      _LabelPrinterSettingsDialogState();
}

class _LabelPrinterSettingsDialogState
    extends State<LabelPrinterSettingsDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _detectedPrinter;
  bool _detecting = false;
  bool _testPrinting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _controller.text = LabelPrinterService.overridePrinterName ?? '';
    _detect();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    if (defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.linux) {
      return;
    }
    setState(() => _detecting = true);
    final name = await LabelPrinterService.detectZebraPrinter();
    if (mounted) {
      setState(() {
        _detectedPrinter = name;
        _detecting = false;
      });
    }
  }

  Future<void> _testPrint() async {
    setState(() {
      _testPrinting = true;
      _testResult = null;
    });

    // Apply the current override before testing
    LabelPrinterService.setOverridePrinterName(
      _controller.text.trim().isEmpty ? null : _controller.text.trim(),
    );

    final success = await LabelPrinterService.printItemLabel(
      itemName: 'TEST LABEL',
      quantity: 1,
      orderId: 'TEST0001',
      orderType: 'Admin',
      fulfillmentType: 'Pickup',
    );

    if (mounted) {
      setState(() {
        _testPrinting = false;
        _testResult = success
            ? '✅ Test label sent successfully!'
            : '❌ Failed — check that the printer is on and connected.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.print, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Label Printer Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Auto-detected printer ──────────────────────────────────────
            _SectionLabel(label: 'Auto-detected Zebra printer'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _detecting
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Scanning CUPS printers…'),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          _detectedPrinter != null
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 18,
                          color: _detectedPrinter != null
                              ? Colors.green
                              : cs.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _detectedPrinter ?? 'No Zebra printer detected',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: _detectedPrinter != null
                                  ? null
                                  : cs.error,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: 'Re-scan',
                          onPressed: _detect,
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 20),

            // ── Manual override ────────────────────────────────────────────
            _SectionLabel(label: 'Override printer name (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: _detectedPrinter ?? 'e.g. ZD220, Zebra_ZD220',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.label_outline),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _controller.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text(
              'Leave blank to use the auto-detected printer.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),

            const SizedBox(height: 20),

            // ── Test result ────────────────────────────────────────────────
            if (_testResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResult!.startsWith('✅')
                      ? Colors.green.withValues(alpha: 0.1)
                      : cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult!.startsWith('✅')
                        ? Colors.green.shade800
                        : cs.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Actions ────────────────────────────────────────────────────
            Row(
              children: [
                // Test print
                OutlinedButton.icon(
                  onPressed: _testPrinting ? null : _testPrint,
                  icon: _testPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print),
                  label: const Text('Test Print'),
                ),
                const Spacer(),
                // Cancel
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                // Save
                FilledButton(
                  onPressed: () {
                    LabelPrinterService.setOverridePrinterName(
                      _controller.text.trim().isEmpty
                          ? null
                          : _controller.text.trim(),
                    );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LabelPrinterService.overridePrinterName != null
                              ? 'Printer set to: ${LabelPrinterService.overridePrinterName}'
                              : 'Using auto-detected printer.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
    );
  }
}
