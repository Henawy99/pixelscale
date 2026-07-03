// Native (non-web) platform implementation.
// Called by label_print_dispatcher.dart on macOS / Linux / Windows / mobile.
// This file imports dart:io (via LabelPrinterService) which is safe on native.

import 'package:restaurantadmin/services/label_printer_service.dart';

/// Prints a label natively via CUPS on macOS/Linux using the ZD220.
Future<bool> printLabelForPlatform({
  required String itemName,
  required int quantity,
  required String orderId,
  String? orderType,
  String? fulfillmentType,
}) {
  return LabelPrinterService.printItemLabel(
    itemName: itemName,
    quantity: quantity,
    orderId: orderId,
    orderType: orderType,
    fulfillmentType: fulfillmentType,
  );
}
