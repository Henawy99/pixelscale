/// Kitchen / pickup location (Salzburg).
const String kKitchenAddress = 'Minnesheimstraße 5, 5023 Salzburg';

class DeliveryZone {
  final String plz;
  final double minimumOrder;
  final double deliveryFee;

  const DeliveryZone({
    required this.plz,
    required this.minimumOrder,
    required this.deliveryFee,
  });
}

/// Salzburg & surrounding delivery areas from Minnesheimstraße 5, 5023.
const List<DeliveryZone> kSalzburgDeliveryZones = [
  DeliveryZone(plz: '5020', minimumOrder: 19.99, deliveryFee: 1.99),
  DeliveryZone(plz: '5023', minimumOrder: 19.99, deliveryFee: 1.99),
  DeliveryZone(plz: '5026', minimumOrder: 25.00, deliveryFee: 2.99),
  DeliveryZone(plz: '5061', minimumOrder: 30.00, deliveryFee: 3.49),
  DeliveryZone(plz: '5071', minimumOrder: 30.00, deliveryFee: 3.49),
  DeliveryZone(plz: '5101', minimumOrder: 30.00, deliveryFee: 3.49),
  DeliveryZone(plz: '5161', minimumOrder: 35.00, deliveryFee: 3.49),
  DeliveryZone(plz: '5201', minimumOrder: 40.00, deliveryFee: 4.49),
  DeliveryZone(plz: '5300', minimumOrder: 25.00, deliveryFee: 2.49),
  DeliveryZone(plz: '5301', minimumOrder: 35.00, deliveryFee: 2.99),
  DeliveryZone(plz: '5321', minimumOrder: 40.00, deliveryFee: 4.49),
];

String normalizePostcode(String? raw) {
  if (raw == null) return '';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 4) return digits.substring(0, 4);
  return digits;
}

DeliveryZone? deliveryZoneForPostcode(String? raw) {
  final plz = normalizePostcode(raw);
  if (plz.length != 4) return null;
  for (final z in kSalzburgDeliveryZones) {
    if (z.plz == plz) return z;
  }
  return null;
}

String formatEuro(double value) => '€${value.toStringAsFixed(2)}';

double orderGrandTotal({
  required double subtotal,
  required bool isDelivery,
  DeliveryZone? zone,
}) {
  if (!isDelivery || zone == null) return subtotal;
  return subtotal + zone.deliveryFee;
}

double remainingForMinimum(double subtotal, DeliveryZone zone) {
  final diff = zone.minimumOrder - subtotal;
  return diff > 0 ? diff : 0;
}

bool meetsMinimumOrder(double subtotal, DeliveryZone zone) =>
    subtotal >= zone.minimumOrder - 0.001;
