import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/src/providers/looks_provider.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Modern, clean Home Dashboard matching the MyCut client workspace design.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({
    required this.onNavigateToStudio,
    required this.onNavigateToGoLooks,
    required this.onNavigateToBarberQr,
    super.key,
  });

  final VoidCallback onNavigateToStudio;
  final VoidCallback onNavigateToGoLooks;
  final ValueChanged<String?> onNavigateToBarberQr;

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  String _selectedCategory = 'Fades';

  static const _categories = [
    'All Styles',
    'Fades',
    'Short',
    'Medium',
    'Long',
    'Curly',
    'Buzz Cuts',
    'Modern',
    'Classic',
  ];

  @override
  Widget build(BuildContext context) {
    final looksState = ref.watch(looksListProvider);
    final theme = Theme.of(context);

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
              // ── Greeting & Status ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: MyCutColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'CLIENT WORKSPACE',
                          style: TextStyle(
                            color: MyCutColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Good afternoon',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: MyCutColors.onSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ready for a new look?',
                        style: TextStyle(
                          color: MyCutColors.secondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'AI Hairstyle Studio & Barber Handoff',
                        style: TextStyle(
                          color: MyCutColors.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: MyCutColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: MyCutColors.primary,
                          size: 20,
                        ),
                        Positioned(
                          top: 9,
                          right: 9,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: MyCutColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Micro Stats Pacing Bar ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: MyCutColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MyCutColors.surfaceContainerHigh.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bookmarks_rounded,
                          color: MyCutColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          looksState.maybeWhen(
                            data: (looks) => '${looks.length} Saved Looks',
                            orElse: () => 'Curated Studio Book',
                          ),
                          style: const TextStyle(
                            color: MyCutColors.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 14,
                      color: MyCutColors.surfaceVariant,
                    ),
                    const Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: MyCutColors.primary,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Next Cut: Ready for Chair',
                          style: TextStyle(
                            color: MyCutColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Hero Feature Card: Try a New Haircut ──
              _buildHeroCard(context),
              const SizedBox(height: 24),

              // ── Categories Carousel ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'EXPLORATION SILHOUETTES',
                    style: TextStyle(
                      color: MyCutColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/styles'),
                    child: const Text(
                      'Browse All',
                      style: TextStyle(
                        color: MyCutColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        if (cat != 'All Styles') {
                          context.push('/styles');
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? MyCutColors.secondaryFixed
                              : MyCutColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? MyCutColors.onSecondaryFixed
                                : MyCutColors.secondary,
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // ── Your Looks Section ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Your Looks',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: MyCutColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: MyCutColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: widget.onNavigateToGoLooks,
                    child: const Row(
                      children: [
                        Text(
                          'View all saved styles',
                          style: TextStyle(
                            color: MyCutColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: MyCutColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Look Cards
              looksState.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => _buildDemoLookCard(context),
                data: (looks) {
                  if (looks.isEmpty) {
                    return _buildDemoLookCard(context);
                  }
                  return Column(
                    children: looks
                        .map((look) => _buildLiveLookCard(context, look))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: MyCutColors.surfaceContainerLow,
                        side: const BorderSide(
                          color: MyCutColors.surfaceContainerHigh,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 18,
                        color: MyCutColors.primary,
                      ),
                      label: const Text(
                        'Import Look from Gallery',
                        style: TextStyle(
                          fontSize: 12,
                          color: MyCutColors.onSurface,
                        ),
                      ),
                      onPressed: () => context.push('/import'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.folder_copy_outlined,
                    size: 16,
                    color: MyCutColors.secondary,
                  ),
                  label: const Text(
                    'My Saved Looks',
                    style: TextStyle(
                      fontSize: 12,
                      color: MyCutColors.secondary,
                    ),
                  ),
                  onPressed: widget.onNavigateToGoLooks,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MyCutColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MyCutColors.surfaceContainerHighest.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Corner reticle accents
          const Positioned(
            top: 12,
            left: 12,
            child: _ReticleCorner(isTop: true, isLeft: true),
          ),
          const Positioned(
            top: 12,
            right: 12,
            child: _ReticleCorner(isTop: true, isLeft: false),
          ),
          const Positioned(
            bottom: 12,
            left: 12,
            child: _ReticleCorner(isTop: false, isLeft: true),
          ),
          const Positioned(
            bottom: 12,
            right: 12,
            child: _ReticleCorner(isTop: false, isLeft: false),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Neural pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MyCutColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(),
                      SizedBox(width: 6),
                      Text(
                        'POWERED BY NEURAL DIFFUSION',
                        style: TextStyle(
                          color: MyCutColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Try a New Haircut',
                  style: TextStyle(
                    color: MyCutColors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Capture headshots and discover your next signature '
                  'style in high-fidelity seconds.',
                  style: TextStyle(
                    color: MyCutColors.secondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Spec preview tags
                const Row(
                  children: [
                    _SpecTag(label: '3D MESH READY'),
                    SizedBox(width: 8),
                    _SpecTag(label: 'TRUE-DENSITY'),
                  ],
                ),
                const SizedBox(height: 16),

                // Primary CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyCutColors.primary,
                      foregroundColor: MyCutColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: widget.onNavigateToStudio,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Start with AI',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
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

  Widget _buildLiveLookCard(BuildContext context, Look look) {
    final render = look.renders.isNotEmpty ? look.renders.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MyCutColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MyCutColors.surfaceContainerHigh,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image stage
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (render != null)
                    Image.network(
                      render.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderPhoto(),
                    )
                  else
                    _buildPlaceholderPhoto(),

                  // Scrim
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            MyCutColors.surfaceContainerLow,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.45],
                        ),
                      ),
                    ),
                  ),

                  // Top badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_rounded,
                            size: 12,
                            color: MyCutColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'READY TO SCAN',
                            style: TextStyle(
                              color: MyCutColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom spec tags
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _SpecTag(
                              label: look.styleKey,
                            ),
                            const SizedBox(width: 6),
                            const _SpecTag(label: 'MATTE CLAY'),
                          ],
                        ),
                        const Text(
                          'v2.4 Render',
                          style: TextStyle(
                            color: MyCutColors.secondary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Metadata & rapid QR action
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        look.title,
                        style: const TextStyle(
                          color: MyCutColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Verified Specification • Barber Ready',
                        style: TextStyle(
                          color: MyCutColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor:
                        MyCutColors.primary.withValues(alpha: 0.15),
                    foregroundColor: MyCutColors.primary,
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: () => widget.onNavigateToBarberQr(look.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoLookCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MyCutColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MyCutColors.surfaceContainerHigh,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPlaceholderPhoto(),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 12,
                            color: MyCutColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'AI READY',
                            style: TextStyle(
                              color: MyCutColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modern Low Fade',
                      style: TextStyle(
                        color: MyCutColors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ready to try on your headshot',
                      style: TextStyle(
                        color: MyCutColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    backgroundColor: MyCutColors.surfaceContainerHigh,
                    foregroundColor: MyCutColors.primary,
                  ),
                  onPressed: widget.onNavigateToStudio,
                  child: const Text('Try On'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPhoto() {
    return const ColoredBox(
      color: MyCutColors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.face_retouching_natural_rounded,
          size: 48,
          color: MyCutColors.secondary,
        ),
      ),
    );
  }
}

class _SpecTag extends StatelessWidget {
  const _SpecTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MyCutColors.surfaceDim,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: MyCutColors.secondary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _ReticleCorner extends StatelessWidget {
  const _ReticleCorner({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: CustomPaint(
        painter: _ReticleCornerPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _ReticleCornerPainter extends CustomPainter {
  const _ReticleCornerPainter({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MyCutColors.primary.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
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

class _PulsingDot extends StatelessWidget {
  const _PulsingDot();

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
