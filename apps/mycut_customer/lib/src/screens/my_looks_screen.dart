import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/src/providers/looks_provider.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Gallery view of customer looks with quick handoff access.
class MyLooksScreen extends ConsumerWidget {
  const MyLooksScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final looksState = ref.watch(looksListProvider);

    final content = SafeArea(
      bottom: false,
      child: looksState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load looks',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(looksListProvider.notifier).loadLooks(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (looks) {
            if (looks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: MyCutColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.content_cut_rounded,
                          size: 36,
                          color: MyCutColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Looks Saved Yet',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Import a hairstyle photo from your gallery to '
                        'configure your first cut and generate a barber '
                        'QR code.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: MyCutColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: const Text('Import from Gallery'),
                        onPressed: () => context.push('/import'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: looks.length,
              itemBuilder: (context, index) {
                final look = looks[index];
                return _LookCard(look: look);
              },
            );
          },
        ),
      );

    if (isEmbedded) {
      return ColoredBox(
        color: MyCutColors.surface,
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Looks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import Look',
            onPressed: () => context.push('/import'),
          ),
        ],
      ),
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MyCutColors.primary,
        foregroundColor: MyCutColors.onPrimary,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('New Look'),
        onPressed: () => context.push('/import'),
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({required this.look});

  final Look look;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final render = look.renders.isNotEmpty ? look.renders.first : null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/looks/${look.id}', extra: look),
      child: Container(
        decoration: BoxDecoration(
          color: MyCutColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MyCutColors.surfaceContainerHigh,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview thumbnail
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: MyCutColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: render?.url != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.network(
                          render!.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_outlined, size: 36),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 40,
                          color: MyCutColors.secondary,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    look.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    look.cutSpec?.describe() ?? look.styleKey.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: MyCutColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.qr_code, size: 14),
                      label: const Text(
                        'Show QR',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () =>
                          context.push('/looks/${look.id}/qr', extra: look),
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
}
