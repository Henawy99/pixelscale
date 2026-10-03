import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

/// Marker icons for the Google map (phones and web), painted once and cached.
///
/// Icons are painted at 3× and handed over with their logical size, so they come out
/// the same size on phones and in the browser.
class MapIcons {
  static const double _scale = 3;
  final Map<String, gmaps.BitmapDescriptor> _cache = {};
  final Map<String, Future<gmaps.BitmapDescriptor>> _pending = {};

  /// The icon for [key] if it is painted already.
  gmaps.BitmapDescriptor? peek(String key) => _cache[key];

  Future<gmaps.BitmapDescriptor> _get(String key, Size size, void Function(Canvas c, Size s) paint) {
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    return _pending[key] ??= () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(_scale);
      paint(canvas, size);
      final image = await recorder
          .endRecording()
          .toImage((size.width * _scale).ceil(), (size.height * _scale).ceil());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final icon = gmaps.BitmapDescriptor.bytes(
        bytes!.buffer.asUint8List(),
        width: size.width,
        height: size.height,
      );
      _cache[key] = icon;
      _pending.remove(key);
      return icon;
    }();
  }

  // ── Restaurant ────────────────────────────────────────────────────────────

  static const Size storeSize = Size(40, 40);

  Future<gmaps.BitmapDescriptor> store() => _get('store', storeSize, (c, s) {
        final center = Offset(s.width / 2, s.height / 2);
        c.drawCircle(center.translate(0, 1.5), 17, Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        c.drawCircle(center, 17, Paint()..color = Colors.white);
        c.drawCircle(center, 14.5, Paint()..color = const Color(0xFF111827));
        _icon(c, Icons.storefront_rounded, center, 17, Colors.white);
      });

  // ── Customer stop: numbered pin in the driver's colour ────────────────────

  static const Size stopSize = Size(30, 38);

  /// [style]: 'next' (filled, ringed), 'live' (filled), 'planned' (white with colour ring),
  /// 'done' (small grey check), 'selected' adds a dark ring.
  Future<gmaps.BitmapDescriptor> stop({
    required int number,
    required Color color,
    required String style,
    bool selected = false,
  }) =>
      _get('stop:$number:${color.toARGB32()}:$style:$selected', stopSize, (c, s) {
        final done = style == 'done';
        final filled = style == 'next' || style == 'live';
        final fill = done ? const Color(0xFF9CA3AF) : (filled ? color : Colors.white);
        final ring = done ? Colors.white : (filled ? Colors.white : color);
        const r = 13.0;
        final center = Offset(s.width / 2, r + 1.5);

        // Pin: circle with a point at the bottom.
        final pin = Path()
          ..addOval(Rect.fromCircle(center: center, radius: r))
          ..moveTo(center.dx - 6, center.dy + r - 3)
          ..lineTo(center.dx, s.height - 1)
          ..lineTo(center.dx + 6, center.dy + r - 3)
          ..close();
        c.drawPath(pin.shift(const Offset(0, 1)), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
        c.drawPath(pin, Paint()..color = selected ? const Color(0xFF111827) : ring);
        c.drawCircle(center, r - (selected ? 3 : 2.2), Paint()..color = fill);
        if (style == 'next') {
          c.drawCircle(center, r - 5, Paint()..color = Colors.white.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        }
        if (done) {
          _icon(c, Icons.check_rounded, center, 16, Colors.white);
        } else {
          _text(c, '$number', center, number > 9 ? 11.5 : 13.5, filled ? Colors.white : color);
        }
      });

  // ── Order waiting for a driver ────────────────────────────────────────────

  static const Size waitingSize = Size(30, 38);

  Future<gmaps.BitmapDescriptor> waiting() => _get('waiting', waitingSize, (c, s) {
        const r = 13.0;
        final center = Offset(s.width / 2, r + 1.5);
        final pin = Path()
          ..addOval(Rect.fromCircle(center: center, radius: r))
          ..moveTo(center.dx - 6, center.dy + r - 3)
          ..lineTo(center.dx, s.height - 1)
          ..lineTo(center.dx + 6, center.dy + r - 3)
          ..close();
        c.drawPath(pin.shift(const Offset(0, 1)), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
        c.drawPath(pin, Paint()..color = Colors.white);
        c.drawCircle(center, r - 2.2, Paint()..color = const Color(0xFFD97706));
        _icon(c, Icons.hourglass_top_rounded, center, 14, Colors.white);
      });

  // ── Driver: round badge with the initial and the name underneath ──────────

  static const Size driverSize = Size(96, 64);

  /// Anchor so the badge's centre (not the label) sits on the driver's position.
  static const Offset driverAnchor = Offset(0.5, 22 / 64);

  /// A round badge rather than a rotated car: the web map cannot rotate markers.
  Future<gmaps.BitmapDescriptor> driver({required String name, required Color color, bool stale = false}) =>
      _get('driver:$name:${color.toARGB32()}:$stale', driverSize, (c, s) {
        final center = Offset(s.width / 2, 22);
        final body = stale ? const Color(0xFF9CA3AF) : color;
        c.drawCircle(center, 21, Paint()..color = body.withValues(alpha: 0.2));
        c.drawCircle(center.translate(0, 1.5), 15, Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        c.drawCircle(center, 15, Paint()..color = Colors.white);
        c.drawCircle(center, 12.5, Paint()..color = body);
        _text(c, name.isNotEmpty ? name[0].toUpperCase() : '?', center, 14, Colors.white);

        // Name label.
        final label = name.length > 12 ? '${name.substring(0, 11)}…' : name;
        final tp = TextPainter(
          text: TextSpan(text: label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          textDirection: TextDirection.ltr,
        )..layout();
        final pill = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(s.width / 2, 52), width: tp.width + 12, height: tp.height + 4),
          const Radius.circular(8),
        );
        c.drawRRect(pill.shift(const Offset(0, 1)), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
        c.drawRRect(pill, Paint()..color = body);
        tp.paint(c, Offset(s.width / 2 - tp.width / 2, 52 - tp.height / 2));
      });

  // ── Painting helpers ──────────────────────────────────────────────────────

  static void _text(Canvas c, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  static void _icon(Canvas c, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }
}

/// Map style: hide shops, restaurants and transit labels so the tours stand out.
const String kCleanMapStyle = '''
[
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]
''';

/// Bearing-free helper used by the camera code: the bounds of some points, padded a little
/// so a single point still gets a sensible zoom.
({double south, double west, double north, double east}) boundsOf(Iterable<({double lat, double lng})> points) {
  var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
  for (final p in points) {
    s = math.min(s, p.lat);
    n = math.max(n, p.lat);
    w = math.min(w, p.lng);
    e = math.max(e, p.lng);
  }
  const minSpan = 0.004; // ~400 m
  if (n - s < minSpan) {
    final mid = (n + s) / 2;
    s = mid - minSpan / 2;
    n = mid + minSpan / 2;
  }
  if (e - w < minSpan) {
    final mid = (e + w) / 2;
    w = mid - minSpan / 2;
    e = mid + minSpan / 2;
  }
  return (south: s, west: w, north: n, east: e);
}
