// Platform-aware label printing entry point.
//
// Uses conditional imports so:
//   • dart:io (LabelPrinterService)  is NEVER compiled into web builds.
//   • dart:html (XHR sender)         is NEVER compiled into native builds.
//
// Both conditional-import targets expose exactly one function:
//   Future<bool> printLabelForPlatform({...})
//
//   • Non-web (macOS / desktop): calls LabelPrinterService → CUPS → ZD220 via USB.
//   • Web: POSTs JSON to http://localhost:8080/print-label → LocalScanServer →
//           LabelPrinterService → CUPS → ZD220 via USB.
//
// The desktop macOS app must be running when using the web path.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'web_label_sender_stub.dart'
    if (dart.library.html) 'web_label_sender_web.dart';

/// Prints one label for an order item on any supported platform.
/// Returns `true` on success.
Future<bool> printOrderItemLabel({
  required String itemName,
  required int quantity,
  required String orderId,
  String? orderType,
  String? fulfillmentType,
}) {
  return printLabelForPlatform(
    itemName: itemName,
    quantity: quantity,
    orderId: orderId,
    orderType: orderType,
    fulfillmentType: fulfillmentType,
  );
}

/// Shows a snackbar warning when the local bridge server is not reachable (web only).
void showWebPrinterBridgeWarning(BuildContext context) {
  if (!kIsWeb) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(
        '⚠️ Label printer bridge not reachable.\n'
        'Make sure the desktop app is running on the same Mac as the ZD220.',
      ),
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ),
  );
}
