import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Detail view for a saved Look, showing the cut specification
/// and QR handoff CTA.
class LookDetailScreen extends ConsumerWidget {
  const LookDetailScreen({
    required this.lookId,
    this.initialLook,
    super.key,
  });

  final String lookId;
  final Look? initialLook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final look = initialLook ??
        Look(
          id: lookId,
          userId: '',
          title: 'Selected Look',
        );

    final spec = look.cutSpec;
    final render = look.renders.isNotEmpty ? look.renders.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(look.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Render image preview
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: MyCutColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: MyCutColors.surfaceContainerHigh,
                ),
              ),
              child: render?.url != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        render!.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_outlined, size: 48),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.face_retouching_natural_rounded,
                        size: 64,
                        color: MyCutColors.secondary,
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // Title and style
            Text(
              look.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spec != null ? spec.describe() : 'Custom Look',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: MyCutColors.secondary,
              ),
            ),
            const SizedBox(height: 24),

            // Specification Card
            if (spec != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MyCutColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MyCutColors.surfaceContainerHighest,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten_rounded,
                          size: 20,
                          color: MyCutColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'BARBER SPECIFICATION',
                          style: theme.textTheme.labelMedium?.copyWith(
                            letterSpacing: 1.5,
                            color: MyCutColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _SpecRow(
                      label: 'Fade Profile',
                      value: '${spec.fadeType.name.toUpperCase()} FADE',
                    ),
                    _SpecRow(
                      label: 'Guard Range',
                      value: '#${spec.fadeGuardStart} to #${spec.fadeGuardEnd}',
                    ),
                    _SpecRow(
                      label: 'Top Length',
                      value: '${spec.topLengthMm}mm '
                          '(~${(spec.topLengthMm / 25.4).toStringAsFixed(1)}")',
                    ),
                    _SpecRow(
                      label: 'Neckline',
                      value: spec.neckline.name.toUpperCase(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Show QR CTA
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_rounded, size: 24),
              label: const Text('Show Barber QR Code'),
              onPressed: () => context.push('/looks/$lookId/qr', extra: look),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: MyCutColors.secondary,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: MyCutColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
