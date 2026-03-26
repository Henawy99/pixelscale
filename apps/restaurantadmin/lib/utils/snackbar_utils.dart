import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows an error snackbar with a copy button
/// Use this for all error messages so users can easily copy and share errors
void showErrorSnackbar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red[700],
      duration: duration ?? const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: '📋 COPY',
        textColor: Colors.white,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: message));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Error copied to clipboard'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    ),
  );
}

/// Shows a success snackbar
void showSuccessSnackbar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green[600],
      duration: duration ?? const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shows a warning snackbar with optional copy button
void showWarningSnackbar(BuildContext context, String message, {bool copyable = false, Duration? duration}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.black87, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.amber[400],
      duration: duration ?? const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      action: copyable ? SnackBarAction(
        label: '📋 COPY',
        textColor: Colors.black87,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: message));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Copied to clipboard'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ) : null,
    ),
  );
}

/// Shows an info snackbar
void showInfoSnackbar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.blue[600],
      duration: duration ?? const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}





