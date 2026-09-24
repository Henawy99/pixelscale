import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Clean, luxury app header matching the MyCut design.
class MyCutAppHeader extends StatelessWidget implements PreferredSizeWidget {
  const MyCutAppHeader({
    super.key,
    this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.trailing,
  });

  final String? title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: MyCutColors.surfaceContainerLowest.withValues(alpha: 0.85),
            border: const Border(
              bottom: BorderSide(
                color: Color(0x262A2A32),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Back button or MyCut Brand
              if (showBackButton)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: MyCutColors.onSurface,
                  ),
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MyCutEmblem(size: 28),
                    const SizedBox(width: 10),
                    Text(
                      title ?? 'MYCUT',
                      style: const TextStyle(
                        color: MyCutColors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3.2,
                      ),
                    ),
                  ],
                ),

              // Right: Profile Avatar or custom trailing
              trailing ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: MyCutColors.surfaceContainerHigh,
                              border: Border.all(
                                color: MyCutColors.surfaceContainerHighest,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: MyCutColors.secondary,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: MyCutColors.primary,
                                border: Border.all(
                                  color: MyCutColors.surfaceContainerLowest,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
