import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/src/data/hairstyle_catalog.dart';
import 'package:mycut_customer/src/screens/explore_screen.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Browse curated hairstyles by category and select one for AI generation.
class StyleBrowserScreen extends ConsumerStatefulWidget {
  const StyleBrowserScreen({
    required this.lookId,
    required this.sourcePhotoId,
    super.key,
  });

  /// The look to generate variations for.
  final String lookId;

  /// The source photo to preserve identity from.
  final String sourcePhotoId;

  @override
  ConsumerState<StyleBrowserScreen> createState() => _StyleBrowserScreenState();
}

class _StyleBrowserScreenState extends ConsumerState<StyleBrowserScreen> {
  HairstyleCategory? _selectedCategory;

  List<Hairstyle> get _filteredStyles =>
      getStylesByCategory(_selectedCategory);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: MyCutColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: MyCutColors.surfaceContainer,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Choose Your Style',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: MyCutColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              titlePadding:
                  const EdgeInsets.only(left: 16, bottom: 16),
            ),
          ),

          // ── Category Chips ──
          SliverToBoxAdapter(
            child: _CategoryChipBar(
              selected: _selectedCategory,
              onSelected: (cat) =>
                  setState(() => _selectedCategory = cat),
            ),
          ),

          // ── Style Grid ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final style = _filteredStyles[index];
                  return _StyleCard(
                    style: style,
                    onTap: () => _onStyleSelected(style),
                  );
                },
                childCount: _filteredStyles.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onStyleSelected(Hairstyle style) {
    if (widget.sourcePhotoId.isEmpty || widget.lookId.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: MyCutColors.surfaceContainer,
          title: const Text('Take Headshots First'),
          content: const Text(
            'To try this hairstyle on your own head, please capture '
            'your headshot photos first!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/capture');
              },
              child: const Text('Take Headshots'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreScreen(
          lookId: widget.lookId,
          sourcePhotoId: widget.sourcePhotoId,
          style: style,
        ),
      ),
    );
  }
}

// ─────────── Category Chip Bar ───────────

class _CategoryChipBar extends StatelessWidget {
  const _CategoryChipBar({
    required this.selected,
    required this.onSelected,
  });

  final HairstyleCategory? selected;
  final ValueChanged<HairstyleCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildChip(
            label: 'All',
            emoji: '✨',
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          ...HairstyleCategory.values.map(
            (cat) => _buildChip(
              label: cat.label,
              emoji: cat.emoji,
              isSelected: selected == cat,
              onTap: () => onSelected(cat),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? MyCutColors.primaryContainer.withValues(alpha: 0.3)
                  : MyCutColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? MyCutColors.primary
                    : MyCutColors.outlineVariant,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? MyCutColors.primary
                        : MyCutColors.onSurfaceVariant,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────── Style Card ───────────

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.onTap,
  });

  final Hairstyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: MyCutColors.surfaceContainerHigh,
            border: Border.all(
              color: MyCutColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Style visual placeholder with gradient
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _categoryColor(style.category)
                            .withValues(alpha: 0.2),
                        MyCutColors.surfaceContainer,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      style.category.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),

              // Style info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        style.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: MyCutColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          style.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: MyCutColors.onSurfaceVariant
                                .withValues(alpha: 0.8),
                            fontSize: 11,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Tags row
                      Wrap(
                        spacing: 4,
                        children: style.tags.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: MyCutColors.surfaceContainerLowest,
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 9,
                                color: MyCutColors.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(HairstyleCategory category) {
    return switch (category) {
      HairstyleCategory.fades => MyCutColors.primary,
      HairstyleCategory.classic => MyCutColors.tertiary,
      HairstyleCategory.textured => const Color(0xFF64DFDF),
      HairstyleCategory.buzz => const Color(0xFFFF6B6B),
      HairstyleCategory.long => const Color(0xFFB388FF),
    };
  }
}
