import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Clean, luxury glassmorphic bottom navigation bar matching the MyCut design.
class MyCutBottomNavBar extends StatelessWidget {
  const MyCutBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: MyCutColors.surfaceContainerLowest.withValues(alpha: 0.88),
            border: const Border(
              top: BorderSide(
                color: Color(0x332A2A32),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(bottom: bottomPadding),
          height: 64 + bottomPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home
              _NavBarItem(
                label: 'Home',
                icon: currentIndex == 0
                    ? Icons.explore_rounded
                    : Icons.explore_outlined,
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),

              // 2. Studio (Elevated Center Button)
              _StudioCenterButton(
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),

              // 3. Looks
              _NavBarItem(
                label: 'Looks',
                icon: currentIndex == 2
                    ? Icons.bookmarks_rounded
                    : Icons.bookmarks_outlined,
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),

              // 4. Barber QR
              _NavBarItem(
                label: 'Barber QR',
                icon: Icons.qr_code_scanner_rounded,
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? MyCutColors.primary : MyCutColors.secondary;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioCenterButton extends StatelessWidget {
  const _StudioCenterButton({
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: OverflowBox(
          maxHeight: 80,
          child: Transform.translate(
            offset: const Offset(0, -4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        MyCutColors.primaryContainer,
                        MyCutColors.primary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MyCutColors.primaryContainer
                            .withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_fix_high_rounded,
                    color: MyCutColors.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'STUDIO',
                  style: TextStyle(
                    color: MyCutColors.primary,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 1.1,
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
