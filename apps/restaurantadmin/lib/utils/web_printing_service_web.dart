// Web-specific implementation that uses dart:html
import 'dart:html' as html;
import 'package:flutter/material.dart';

void printHtmlOnWebImpl(String htmlContent, BuildContext context) {
  // This function contains the actual web printing logic
  html.BodyElement? originalBodyElement; // Store as BodyElement specifically
  try {
    // 1. Store the original body, ensuring it's a BodyElement
    if (html.document.body != null) {
      originalBodyElement = html.document.body!.clone(true) as html.BodyElement?;
    }

    // 2. Create a new body for the receipt
    final newBody = html.BodyElement();
    newBody.innerHtml = htmlContent; // Set the receipt HTML

    // 3. Replace the document's body
    html.document.body = newBody;

    // 4. Print
    html.window.print();

  } catch (e) {
    print("Error in printHtmlOnWebImpl: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparing receipt for printing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    // 5. Restore the original body
    // This needs to happen after the print dialog is closed.
    // A slight delay might be needed, or this could be tricky if print is async.
    // For simplicity, we restore immediately. If issues occur, this might need refinement.
    if (originalBodyElement != null) {
      html.document.body = originalBodyElement;
    } else {
      // Fallback if originalBody couldn't be cloned (should not happen ideally)
      // Or clear the body to avoid showing receipt content permanently
      html.document.body?.innerHtml = ''; 
    }
  }
} 