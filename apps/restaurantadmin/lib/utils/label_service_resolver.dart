// Thin wrapper that delegates to LabelPrinterService on native (non-web) platforms.
// This file is imported by label_print_dispatcher.dart ONLY on non-web builds,
// keeping dart:io safely away from the web compilation unit.

import 'package:restaurantadmin/services/label_printer_service.dart';

Future<bool> printLabelNative({
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
