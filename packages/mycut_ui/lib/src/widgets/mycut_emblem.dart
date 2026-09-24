import 'package:flutter/material.dart';

/// The official MyCut Emblem vector icon.
///
/// Features a dark rounded container with subtle border, and a razor/shears
/// geometric apex icon with futuristic gold gradient and crossbar.
class MyCutEmblem extends StatelessWidget {
  const MyCutEmblem({
    super.key,
    this.size = 36.0,
    this.showBorder = true,
  });

  /// The size (width and height) of the emblem.
  final double size;

  /// Whether to draw the subtle outer container border.
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MyCutEmblemPainter(showBorder: showBorder),
      ),
    );
  }
}

class _MyCutEmblemPainter extends CustomPainter {
  const _MyCutEmblemPainter({required this.showBorder});

  final bool showBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas
      ..save()
      ..scale(scale, scale);

    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Radius.circular(28),
    );

    // Background container
    final bgPaint = Paint()
      ..color = const Color(0xFF121216)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    if (showBorder) {
      final borderPaint = Paint()
        ..color = const Color(0xFF2A2A32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(rrect, borderPaint);
    }

    final goldShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF5D77F),
        Color(0xFFD4AF37),
        Color(0xFF9A7B2C),
      ],
    ).createShader(const Rect.fromLTWH(0, 0, 100, 100));

    // Shears apex path: M30 72 L50 28 L70 72
    final apexPath = Path()
      ..moveTo(30, 72)
      ..lineTo(50, 28)
      ..lineTo(70, 72);

    final apexPaint = Paint()
      ..shader = goldShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(apexPath, apexPaint);

    // White crossbar: M38 56 L62 56
    final barPath = Path()
      ..moveTo(38, 56)
      ..lineTo(62, 56);

    final barPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(barPath, barPaint);

    // Center gold accent dot: cx 50, cy 44, r 3.5
    final dotPaint = Paint()
      ..shader = goldShader
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(50, 44), 3.5, dotPaint);

    // Subtle side slash accents: M26 34 L32 26 and M74 34 L68 26
    final slashPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final slash1 = Path()
      ..moveTo(26, 34)
      ..lineTo(32, 26);
    canvas.drawPath(slash1, slashPaint);

    final slash2 = Path()
      ..moveTo(74, 34)
      ..lineTo(68, 26);
    canvas
      ..drawPath(slash2, slashPaint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _MyCutEmblemPainter oldDelegate) =>
      oldDelegate.showBorder != showBorder;
}
