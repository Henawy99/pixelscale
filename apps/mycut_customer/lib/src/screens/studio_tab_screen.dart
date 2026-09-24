import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Studio Calibrator screen matching the user's Photo Upload & Camera design.
class StudioTabScreen extends StatefulWidget {
  const StudioTabScreen({super.key, this.isActive = false});

  final bool isActive;

  @override
  State<StudioTabScreen> createState() => _StudioTabScreenState();
}

class _StudioTabScreenState extends State<StudioTabScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isFlashAuto = true;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StudioTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MyCutColors.surface,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: MyCutColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingStudioDot(),
                    SizedBox(width: 6),
                    Text(
                      'STUDIO CALIBRATOR',
                      style: TextStyle(
                        color: MyCutColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Let's see what suits you.",
                style: TextStyle(
                  color: MyCutColors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'For the best AI simulation, use a clear, front-facing '
                'photograph with your hairline visible and good natural '
                'lighting.',
                style: TextStyle(
                  color: MyCutColors.secondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // ── Computational Viewfinder Chamber ──
              _buildViewfinder(context),
              const SizedBox(height: 18),

              // ── Framing Rules Checklist Card ──
              _buildChecklistCard(),
              const SizedBox(height: 22),

              // ── Shutter & Gallery Controls ──
              _buildShutterControls(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewfinder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 380,
      decoration: BoxDecoration(
        color: MyCutColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MyCutColors.surfaceContainerHigh,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background ambient dark gradient
          Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              gradient: RadialGradient(
                radius: 0.8,
                colors: [
                  Color(0xFF201F25),
                  Color(0xFF0E0E10),
                ],
              ),
            ),
          ),

          // Head contour silhouette wireframe
          Center(
            child: SizedBox(
              width: 180,
              height: 240,
              child: CustomPaint(
                painter: _HeadContourPainter(),
              ),
            ),
          ),

          // 4 Amber Reticle Brackets
          const Positioned(
            top: 24,
            left: 24,
            child: _ReticleBracket(alignment: Alignment.topLeft),
          ),
          const Positioned(
            top: 24,
            right: 24,
            child: _ReticleBracket(alignment: Alignment.topRight),
          ),
          const Positioned(
            bottom: 24,
            left: 24,
            child: _ReticleBracket(alignment: Alignment.bottomLeft),
          ),
          const Positioned(
            bottom: 24,
            right: 24,
            child: _ReticleBracket(alignment: Alignment.bottomRight),
          ),

          // Center pulsing crosshair
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Container(
                  width: 10 + _pulseController.value * 4,
                  height: 10 + _pulseController.value * 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MyCutColors.primary.withValues(alpha: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color:
                            MyCutColors.primary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Top Viewfinder Toolbar HUD
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Alignment Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingStudioDot(),
                      SizedBox(width: 6),
                      Text(
                        'Face Centered • Good Light',
                        style: TextStyle(
                          color: MyCutColors.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.verified_rounded,
                        color: MyCutColors.primary,
                        size: 13,
                      ),
                    ],
                  ),
                ),

                // Flash and flip controls
                Row(
                  children: [
                    _RoundIconButton(
                      icon: _isFlashAuto ? Icons.flash_auto : Icons.flash_on,
                      onPressed: () =>
                          setState(() => _isFlashAuto = !_isFlashAuto),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.flip_camera_ios_rounded,
                      onPressed: () =>
                          setState(() => _isFrontCamera = !_isFrontCamera),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Viewfinder Metric Badge
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ISO AUTO • 1/120S',
                    style: TextStyle(
                      color: MyCutColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '98.4% SYMMETRICAL',
                    style: TextStyle(
                      color: MyCutColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyCutColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MyCutColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CAPTURE CALIBRATION',
                style: TextStyle(
                  color: MyCutColors.outline,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'READY FOR NEURAL ENGINE',
                style: TextStyle(
                  color: MyCutColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChecklistItem(
            icon: Icons.check_rounded,
            iconColor: MyCutColors.primary,
            bgColor: MyCutColors.primaryContainer.withValues(alpha: 0.2),
            text: 'Face directly forward towards the camera',
          ),
          const SizedBox(height: 8),
          _buildChecklistItem(
            icon: Icons.check_rounded,
            iconColor: MyCutColors.primary,
            bgColor: MyCutColors.primaryContainer.withValues(alpha: 0.2),
            text: 'Hairline and both ears fully exposed',
          ),
          const SizedBox(height: 8),
          _buildChecklistItem(
            icon: Icons.close_rounded,
            iconColor: MyCutColors.error,
            bgColor: MyCutColors.errorContainer.withValues(alpha: 0.3),
            text: 'Avoid tinted glasses, hats, or harsh backlit shadows',
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MyCutColors.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: MyCutColors.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShutterControls(BuildContext context) {
    return Column(
      children: [
        // Pulsing shutter button
        Center(
          child: GestureDetector(
            onTap: () => context.push('/capture'),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MyCutColors.surfaceContainer,
                border: Border.all(
                  color: MyCutColors.primaryContainer.withValues(alpha: 0.5),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MyCutColors.primaryContainer.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      MyCutColors.primaryContainer,
                      MyCutColors.primary,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: MyCutColors.onPrimary,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Choose from Gallery
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: MyCutColors.surfaceContainerHigh,
              foregroundColor: MyCutColors.onSurface,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(
              Icons.add_photo_alternate_rounded,
              color: MyCutColors.secondary,
              size: 20,
            ),
            label: const Text(
              'CHOOSE FROM GALLERY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            onPressed: () => context.push('/capture'),
          ),
        ),
        const SizedBox(height: 12),

        // Privacy note
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: MyCutColors.outline,
              size: 13,
            ),
            SizedBox(width: 6),
            Text(
              'Processed securely • Photos never shared publicly',
              style: TextStyle(
                color: MyCutColors.outline,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: MyCutColors.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class _ReticleBracket extends StatelessWidget {
  const _ReticleBracket({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _ReticleBracketPainter(alignment: alignment),
      ),
    );
  }
}

class _ReticleBracketPainter extends CustomPainter {
  const _ReticleBracketPainter({required this.alignment});

  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MyCutColors.primary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (alignment == Alignment.topLeft) {
      path
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0);
    } else if (alignment == Alignment.topRight) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeadContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = MyCutColors.onSurfaceVariant.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Head oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: size.width * 0.75,
        height: size.height * 0.65,
      ),
      dashPaint,
    );

    // Shoulders arc
    final shoulderPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.95)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.8,
        size.width * 0.9,
        size.height * 0.95,
      );
    canvas.drawPath(shoulderPath, dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulsingStudioDot extends StatelessWidget {
  const _PulsingStudioDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: MyCutColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
