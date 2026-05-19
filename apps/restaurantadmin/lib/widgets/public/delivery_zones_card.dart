import 'package:flutter/material.dart';
import 'package:restaurantadmin/config/delivery_zones.dart';

/// Shows supported PLZ, minimum order and delivery fee.
class DeliveryZonesCard extends StatelessWidget {
  final Color accentColor;
  final DeliveryZone? selectedZone;

  const DeliveryZonesCard({
    super.key,
    required this.accentColor,
    this.selectedZone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: accentColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: selectedZone == null,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(Icons.local_shipping_outlined, color: accentColor),
          title: Text(
            selectedZone != null
                ? 'PLZ ${selectedZone!.plz}: Min. ${formatEuro(selectedZone!.minimumOrder)}, Lieferung ${formatEuro(selectedZone!.deliveryFee)}'
                : 'Liefergebiete Salzburg',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: selectedZone == null
              ? Text(
                  'Ab ${kKitchenAddress}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                )
              : null,
          children: [
            ...kSalzburgDeliveryZones.map((z) {
              final selected = selectedZone?.plz == z.plz;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      'PLZ ${z.plz}',
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? accentColor : null,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ab ${formatEuro(z.minimumOrder)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+ ${formatEuro(z.deliveryFee)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
