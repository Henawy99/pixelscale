import 'package:flutter/material.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Overlay for comparing an AI-generated preview against the original photo.
///
/// Displays a draggable slider (wipe-reveal) effect to let the customer
/// see the original photo on one side and the generated preview on the other.
class PreviewComparisonOverlay extends StatefulWidget {
  const PreviewComparisonOverlay({
    required this.sourcePhotoId,
    required this.previewRender,
    super.key,
  });

  /// The original source photo ID to load for comparison.
  final String sourcePhotoId;

  /// The AI-generated preview render to compare against.
  final LookRender previewRender;

  @override
  State<PreviewComparisonOverlay> createState() =>
      _PreviewComparisonOverlayState();
}

class _PreviewComparisonOverlayState extends State<PreviewComparisonOverlay>
    with SingleTickerProviderStateMixin {
  double _sliderPosition = 0.5;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final imageSize = size.width * 0.85;

    return FadeTransition(
      opacity: _fadeController,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: const BoxDecoration(
                color: MyCutColors.surfaceContainer,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.compare_rounded,
                    color: MyCutColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Compare with Original',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: MyCutColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 20,
                    color: MyCutColors.onSurfaceVariant,
                    style: IconButton.styleFrom(
                      backgroundColor: MyCutColors.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),

            // Comparison viewport
            Container(
              width: imageSize,
              height: imageSize,
              decoration: const BoxDecoration(
                color: MyCutColors.surfaceContainerLowest,
              ),
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _sliderPosition = (_sliderPosition +
                            details.delta.dx / imageSize)
                        .clamp(0.05, 0.95);
                  });
                },
                child: Stack(
                  children: [
                    // Right side: Generated preview (full)
                    Positioned.fill(
                      child: _buildImagePlaceholder(
                        label: 'AI Preview',
                        icon: Icons.auto_awesome_rounded,
                        color: MyCutColors.primary,
                      ),
                    ),

                    // Left side: Original (clipped)
                    ClipRect(
                      clipper: _HorizontalClipper(_sliderPosition),
                      child: SizedBox(
                        width: imageSize,
                        height: imageSize,
                        child: _buildImagePlaceholder(
                          label: 'Original',
                          icon: Icons.person_rounded,
                          color: MyCutColors.secondary,
                        ),
                      ),
                    ),

                    // Slider handle
                    Positioned(
                      left: imageSize * _sliderPosition - 16,
                      top: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Vertical line
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.white,
                            ),
                          ),
                          // Handle grip
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.drag_handle_rounded,
                              color: MyCutColors.surface,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Labels
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: _buildLabel('Original'),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: _buildLabel('AI Preview'),
                    ),
                  ],
                ),
              ),
            ),

            // Footer hint
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: const BoxDecoration(
                color: MyCutColors.surfaceContainer,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swipe_rounded,
                    color:
                        MyCutColors.onSurfaceVariant.withValues(alpha: 0.6),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Drag the slider to compare',
                    style: TextStyle(
                      color: MyCutColors.onSurfaceVariant
                          .withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return ColoredBox(
      color: MyCutColors.surfaceContainerHigh,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Custom clipper for the horizontal wipe-reveal effect.
class _HorizontalClipper extends CustomClipper<Rect> {
  _HorizontalClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(covariant _HorizontalClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}
