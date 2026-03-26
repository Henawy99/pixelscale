import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
    bool showCopyButton = false,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showCopyButton) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Error copied to clipboard!',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Copy error',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
        backgroundColor: isError 
            ? Colors.red.shade600 
            : const Color(0xFF00BF63),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: showCopyButton ? const Duration(seconds: 8) : duration,
        elevation: 6,
      ),
    );
  }

  static void showError(BuildContext context, String message, {bool showCopyButton = true}) {
    show(context, message: message, isError: true, showCopyButton: showCopyButton);
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, isError: false);
  }
}

