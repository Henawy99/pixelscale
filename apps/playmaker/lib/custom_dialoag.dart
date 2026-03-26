import 'package:flutter/material.dart';
class CustomDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? cancelText;
  final String confirmText;
  final Color? confirmColor;
  final IconData? icon;
  final Widget Function(BuildContext)? builder; // Changed to correct type
  final VoidCallback? onConfirm;
  final bool isDestructive;

  const CustomDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = 'Cancel',
    this.confirmText = 'Confirm',
    this.confirmColor,
    this.icon,
    this.builder,
    this.onConfirm,
    this.isDestructive = false,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String? cancelText,
    String? confirmText,
    Color? confirmColor,
    IconData? icon,
    Widget Function(BuildContext)? builder, // Added to static method
    VoidCallback? onConfirm,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => CustomDialog(
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText ?? 'Confirm',
        confirmColor: confirmColor,
        icon: icon,
        builder: builder,
        onConfirm: onConfirm,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            // Icon Section
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDestructive 
                      ? Colors.red 
                      : theme.colorScheme.primary
                  ).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isDestructive 
                      ? Colors.red 
                      : theme.colorScheme.primary,
                ),
              ),
            const SizedBox(height: 16),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            // Builder section
            if (builder != null) builder!(context),
            const SizedBox(height: 24),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  if (cancelText != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(cancelText!),
                      ),
                    ),
                  if (cancelText != null)
                    const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                        onConfirm?.call();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: confirmColor ?? (isDestructive 
                            ? Colors.red 
                            : null),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(confirmText),
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