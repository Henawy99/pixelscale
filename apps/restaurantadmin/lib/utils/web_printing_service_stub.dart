// Stub implementation for non-web platforms
import 'package:flutter/material.dart';

void printHtmlOnWebImpl(String htmlContent, BuildContext context) {
  // This is a stub implementation for non-web platforms
  // The actual functionality is handled in the main service file
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printing is only supported on web platform'),
        backgroundColor: Colors.orange,
      ),
    );
  }
} 