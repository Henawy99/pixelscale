import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/src/providers/generation_provider.dart';
import 'package:mycut_customer/src/widgets/preview_comparison_overlay.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// 4-up exploration grid showing AI-generated preview variations.
///
/// Subscribes to generation job status via Supabase Realtime and displays
/// skeleton loading → preview images → winner selection.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({
    required this.lookId,
    required this.sourcePhotoId,
    required this.style,
    super.key,
  });

  final String lookId;
  final String sourcePhotoId;
  final Hairstyle style;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with TickerProviderStateMixin {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    // Kick off generation immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(generationNotifierProvider.notifier).generate(
            lookId: widget.lookId,
            sourcePhotoId: widget.sourcePhotoId,
            styleKey: widget.style.key,
          );
    });
  }


  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(generationNotifierProvider);
    final credits = ref.watch(creditsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: MyCutColors.surface,
      appBar: AppBar(
        backgroundColor: MyCutColors.surfaceContainer,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.style.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: MyCutColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _statusLabel(genState),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _statusColor(genState),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          // Credit badge
          credits.when(
            data: (c) => _CreditBadge(credits: c),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── 4-Up Grid ──
          Expanded(
            child: genState.isFailed
                ? _ErrorView(
                    message: genState.error ??
                        genState.job?.errorMessage,
                    onRetry: _retry,
                  )
                : _FourUpGrid(
                    renders: genState.renders,
                    isLoading: genState.isRunning ||
                        genState.isRequesting,
                    selectedIndex: _selectedIndex,
                    onSelect: (i) =>
                        setState(() => _selectedIndex = i),
                    onLongPress: _showComparisonOverlay,
                  ),
          ),

          // ── Bottom Actions ──
          if (genState.isComplete && _selectedIndex != null)
            _BottomActionBar(
              onConfirm: _confirmSelection,
              onCompare: () =>
                  _showComparisonOverlay(_selectedIndex!),
            ),
        ],
      ),
    );
  }

  String _statusLabel(GenerationState state) {
    if (state.isRequesting) return 'Requesting generation…';
    if (state.job == null) return 'Preparing…';
    return switch (state.job!.status) {
      GenerationJobStatus.queued => 'Queued — waiting for AI…',
      GenerationJobStatus.running => 'Generating variations…',
      GenerationJobStatus.succeeded =>
        '${state.renders.length} variations ready',
      GenerationJobStatus.failed => 'Generation failed',
    };
  }

  Color _statusColor(GenerationState state) {
    if (state.isFailed) return MyCutColors.error;
    if (state.isComplete) return const Color(0xFF4CAF50);
    return MyCutColors.primary;
  }

  void _retry() {
    ref.read(generationNotifierProvider.notifier).generate(
          lookId: widget.lookId,
          sourcePhotoId: widget.sourcePhotoId,
          styleKey: widget.style.key,
        );
  }

  void _showComparisonOverlay(int index) {
    final renders = ref.read(generationNotifierProvider).renders;
    if (index >= renders.length) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => PreviewComparisonOverlay(
        sourcePhotoId: widget.sourcePhotoId,
        previewRender: renders[index],
      ),
    );
  }

  void _confirmSelection() {
    // TODO(mycut): Save the selected render as the primary
    // render and navigate back to LookDetailScreen.
    final renders = ref.read(generationNotifierProvider).renders;
    if (_selectedIndex == null || _selectedIndex! >= renders.length) return;

    Navigator.of(context).pop(renders[_selectedIndex!]);
  }
}

// ─────────── 4-Up Grid ───────────

class _FourUpGrid extends StatelessWidget {
  const _FourUpGrid({
    required this.renders,
    required this.isLoading,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLongPress,
  });

  final List<LookRender> renders;
  final bool isLoading;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          if (isLoading || index >= renders.length) {
            return _SkeletonCell(index: index);
          }
          return _PreviewCell(
            render: renders[index],
            index: index,
            isSelected: selectedIndex == index,
            onTap: () => onSelect(index),
            onLongPress: () => onLongPress(index),
          );
        },
      ),
    );
  }
}

// ─────────── Skeleton Loading Cell ───────────

class _SkeletonCell extends StatefulWidget {
  const _SkeletonCell({required this.index});

  final int index;

  @override
  State<_SkeletonCell> createState() => _SkeletonCellState();
}

class _SkeletonCellState extends State<_SkeletonCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-1 + _shimmerAnimation.value, 0),
              end: Alignment(_shimmerAnimation.value, 0),
              colors: [
                MyCutColors.surfaceContainerHigh,
                MyCutColors.surfaceContainerHighest.withValues(alpha: 0.8),
                MyCutColors.surfaceContainerHigh,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: MyCutColors.primary.withValues(alpha: 0.3),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Variation ${widget.index + 1}',
                  style: TextStyle(
                    color:
                        MyCutColors.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────── Preview Cell ───────────

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({
    required this.render,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final LookRender render;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MyCutColors.primary : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: MyCutColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 13 : 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Placeholder — in real app, load from signed URL
              ColoredBox(
                color: MyCutColors.surfaceContainerHigh,
                child: Image.network(
                  render.url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MyCutColors.primary,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint(
                      'Render image load error: $error (url: ${render.url})',
                    );
                    return _buildPlaceholder();
                  },
                ),
              ),

              // Variation label
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'V${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: MyCutColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: MyCutColors.onPrimary,
                      size: 18,
                    ),
                  ),
                ),

              // Long press hint
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.compare_rounded,
                        color: Colors.white70,
                        size: 12,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Hold',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
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
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_rounded,
            color: MyCutColors.onSurfaceVariant.withValues(alpha: 0.3),
            size: 40,
          ),
          const SizedBox(height: 4),
          Text(
            'Preview ${index + 1}',
            style: TextStyle(
              color: MyCutColors.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────── Error View ───────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: MyCutColors.errorContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: MyCutColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Generation Failed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MyCutColors.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'An unexpected error occurred',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MyCutColors.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: MyCutColors.primaryContainer,
                foregroundColor: MyCutColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────── Credit Badge ───────────

class _CreditBadge extends StatelessWidget {
  const _CreditBadge({required this.credits});

  final int credits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: credits > 0
            ? MyCutColors.primaryContainer.withValues(alpha: 0.2)
            : MyCutColors.errorContainer.withValues(alpha: 0.2),
        border: Border.all(
          color: credits > 0
              ? MyCutColors.primary.withValues(alpha: 0.5)
              : MyCutColors.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            color: credits > 0 ? MyCutColors.primary : MyCutColors.error,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '$credits',
            style: TextStyle(
              color:
                  credits > 0 ? MyCutColors.primary : MyCutColors.error,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────── Bottom Action Bar ───────────

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.onConfirm,
    required this.onCompare,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: MyCutColors.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: MyCutColors.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCompare,
                icon: const Icon(
                  Icons.compare_rounded,
                  size: 18,
                ),
                label: const Text('Compare'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      MyCutColors.onSurfaceVariant,
                  side: const BorderSide(
                    color: MyCutColors.outlineVariant,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(
                  Icons.check_rounded,
                  size: 18,
                ),
                label: const Text('Use This Look'),
                style: FilledButton.styleFrom(
                  backgroundColor: MyCutColors.primary,
                  foregroundColor: MyCutColors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
