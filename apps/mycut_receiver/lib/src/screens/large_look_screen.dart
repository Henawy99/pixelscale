import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_receiver/src/providers/receiver_provider.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Full-screen tablet consultation view for the barber.
///
/// Optimized for:
/// - Landscape tablet usage.
/// - Minimum 24pt typography for reading from 1.5m away with scissors.
/// - Dark high-contrast styling to eliminate shop glare.
/// - Structured CutSpec presentation with guard numbers and millimetre labels.
class LargeLookScreen extends ConsumerStatefulWidget {
  const LargeLookScreen({
    required this.payload,
    super.key,
  });

  final RedeemedLookPayload payload;

  @override
  ConsumerState<LargeLookScreen> createState() => _LargeLookScreenState();
}

class _LargeLookScreenState extends ConsumerState<LargeLookScreen> {
  int _selectedRenderIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final look = widget.payload.look;
    final spec = look.cutSpec;
    final renders = widget.payload.renders;
    final activeRender =
        renders.isNotEmpty && _selectedRenderIndex < renders.length
            ? renders[_selectedRenderIndex]
            : null;

    final topInches = spec != null
        ? (spec.topLengthMm / 25.4).toStringAsFixed(1)
        : null;

    return Scaffold(
      backgroundColor: MyCutColors.surface,
      body: SafeArea(
        child: Row(
          children: [
            // Left 55%: High-resolution visual render viewport
            Expanded(
              flex: 55,
              child: Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: MyCutColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: MyCutColors.surfaceContainerHigh,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Render image
                    Positioned.fill(
                      child: activeRender?.url != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.network(
                                activeRender!.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: 80,
                                    color: MyCutColors.secondary,
                                  ),
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.face_retouching_natural_rounded,
                                size: 100,
                                color: MyCutColors.secondary,
                              ),
                            ),
                    ),

                    // Multi-view switcher pills
                    if (renders.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(200),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < renders.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: ChoiceChip(
                                      label: Text(renders[i].view.label),
                                      selected: _selectedRenderIndex == i,
                                      onSelected: (val) {
                                        if (val) {
                                          setState(
                                            () => _selectedRenderIndex = i,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Right 45%: Customer Consultation & Cut Spec diagram card
            Expanded(
              flex: 45,
              child: Container(
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 24,
                  right: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer First Name Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: MyCutColors.primaryContainer.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MyCutColors.primary.withAlpha(100),
                        ),
                      ),
                      child: Text(
                        'CONSULTATION FOR '
                        '${widget.payload.customerFirstName.toUpperCase()}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: MyCutColors.primary,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Look Title
                    Text(
                      look.title,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: MyCutColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cut Specification Diagram Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: MyCutColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: MyCutColors.surfaceContainerHigh,
                            width: 1.5,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.straighten_rounded,
                                    size: 28,
                                    color: MyCutColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'CUT SPECIFICATION',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: MyCutColors.primary,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 28),

                              // Sides Guard Spec
                              _BarberSpecItem(
                                label: 'SIDES FADE',
                                value: spec != null
                                    ? '${spec.fadeType.name.toUpperCase()} '
                                        '(#${spec.fadeGuardStart} → '
                                        '#${spec.fadeGuardEnd})'
                                    : 'CUSTOM',
                                subtitle: spec != null
                                    ? 'Guard #${spec.fadeGuardStart} at base, '
                                        'blended to #${spec.fadeGuardEnd}'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Top Length Spec
                              _BarberSpecItem(
                                label: 'TOP LENGTH',
                                value: spec != null
                                    ? '${spec.topLengthMm}mm (~$topInches")'
                                    : 'AS SEEN',
                                subtitle:
                                    spec?.texture ?? 'Scissor trim on top',
                              ),
                              const SizedBox(height: 16),

                              // Neckline Spec
                              _BarberSpecItem(
                                label: 'NECKLINE',
                                value: spec != null
                                    ? spec.neckline.name.toUpperCase()
                                    : 'TAPERED',
                                subtitle: 'Clean edge finish',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 28),
                        label: const Text(
                          'Finish Consultation',
                          style: TextStyle(fontSize: 18),
                        ),
                        onPressed: () {
                          ref.read(receiverProvider.notifier).resetToIdle();
                          context.go('/');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarberSpecItem extends StatelessWidget {
  const _BarberSpecItem({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: MyCutColors.secondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: MyCutColors.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: MyCutColors.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ],
    );
  }
}
