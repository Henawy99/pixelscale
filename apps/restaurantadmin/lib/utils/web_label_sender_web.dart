// Web platform implementation.
// Called by label_print_dispatcher.dart when running in a browser.
// Uses dart:html XHR to POST label data to the local Dart bridge server
// (LocalScanServer running on the macOS desktop app), which forwards ZPL to the ZD220.

import 'dart:html' as html;
import 'dart:convert';

/// Sends a label print request to the local Dart bridge server at localhost:8080.
Future<bool> printLabelForPlatform({
  required String itemName,
  required int quantity,
  required String orderId,
  String? orderType,
  String? fulfillmentType,
}) async {
  const int port = 8080;
  final url = 'http://localhost:$port/print-label';
  final body = jsonEncode({
    'itemName': itemName,
    'quantity': quantity,
    'orderId': orderId,
    if (orderType != null) 'orderType': orderType,
    if (fulfillmentType != null) 'fulfillmentType': fulfillmentType,
  });

  try {
    final response = await html.HttpRequest.request(
      url,
      method: 'POST',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: body,
    );
    if (response.status == 200) {
      print('[WebLabelSender] Label sent successfully for "$itemName".');
      return true;
    } else {
      print('[WebLabelSender] Server returned ${response.status}: ${response.responseText}');
      return false;
    }
  } catch (e) {
    // Typically means the local desktop server is not running.
    print('[WebLabelSender] Could not reach local print server: $e');
    return false;
  }
}
