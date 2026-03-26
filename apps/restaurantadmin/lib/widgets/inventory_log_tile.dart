import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:restaurantadmin/models/inventory_log_item.dart';

class InventoryLogTile extends StatelessWidget {
  final InventoryLogItem logItem;

  const InventoryLogTile({super.key, required this.logItem});

  @override
  Widget build(BuildContext context) {
    final bool isEntry = logItem.changeType == 'ENTRY' || logItem.changeType == 'INITIAL_STOCK';
    final String quantityPrefix = isEntry ? '+' : (logItem.changeType == 'OUT' ? '-' : ''); // CORRECTION could be +/-
    final Color quantityColor = isEntry ? Colors.green : (logItem.changeType == 'OUT' ? Colors.red : Colors.orange);
    final IconData quantityIcon = isEntry ? Icons.add_circle_outline : (logItem.changeType == 'OUT' ? Icons.remove_circle_outline : Icons.edit_note);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(quantityIcon, color: quantityColor, size: 30),
        title: Text(
          logItem.materialName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change: $quantityPrefix${logItem.quantityChange.abs()} (New Qty: ${logItem.newQuantityAfterChange})'),
            Text('Type: ${logItem.changeType}'),
            if (logItem.sourceDetails != null && logItem.sourceDetails!.isNotEmpty)
              Text('Source: ${logItem.sourceDetails}'),
            Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(logItem.createdAt.toLocal())}'),
          ],
        ),
        isThreeLine: logItem.sourceDetails != null && logItem.sourceDetails!.isNotEmpty,
        // dense: true,
      ),
    );
  }
}
