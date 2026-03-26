import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurantadmin/models/inventory_value_event.dart';
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/screens/receipt_detail_screen.dart';
import 'package:restaurantadmin/screens/order_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryValueHistoryScreen extends StatefulWidget {
  const InventoryValueHistoryScreen({super.key});

  @override
  State<InventoryValueHistoryScreen> createState() => _InventoryValueHistoryScreenState();
}

class _InventoryValueHistoryScreenState extends State<InventoryValueHistoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<InventoryValueEvent> _valueEvents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInventoryValueHistory();
  }

  Future<void> _fetchInventoryValueHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<InventoryValueEvent> combinedEvents = [];

      // Fetch active receipts (Value Added)
      final receiptsResponse = await _supabase
          .from('receipts')
          .select()
          .eq('status', 'active') // Only active receipts contribute to current value
          .order('created_at', ascending: false);

      for (var receiptData in (receiptsResponse as List)) {
        final receiptMap = receiptData as Map<String, dynamic>;
        final totalAmount = (receiptMap['total_amount'] as num?)?.toDouble() ?? 0.0;
        if (totalAmount > 0) { // Only consider receipts that added value
          combinedEvents.add(InventoryValueEvent(
            id: receiptMap['id'] as String,
            eventDate: DateTime.parse(receiptMap['receipt_date'] ?? receiptMap['created_at'] as String),
            type: InventoryValueEventType.added,
            valueChange: totalAmount,
            description: 'Receipt: ${receiptMap['wholesaler_name'] ?? 'N/A'}',
            rawData: receiptMap, // Store for navigation to ReceiptDetailScreen
          ));
        }
      }

      // Fetch completed orders (Value Deducted)
      // Assuming 'completed', 'paid', or similar statuses mean stock was consumed.
      // Adjust statuses as per your app's order lifecycle.
      // We also need orders that have a profit value, as COGS = Total - Profit
      final ordersResponse = await _supabase
          .from('orders')
          .select('*, brands(name)') // Ensure profit is selected if not default by '*'
          .not('status', 'in', ['cancelled_discarded', 'cancelled_stock_returned']) // Removed 'pending_payment'
          .not('profit', 'is', null) // Corrected filter for "is not null"
          .order('created_at', ascending: false);

      for (var orderData in (ordersResponse as List)) {
        final orderMap = orderData as Map<String, dynamic>;
        final order = app_order.Order.fromJson(orderMap); // Use your Order model
        
        final double totalPrice = order.totalPrice;
        final double? profit = order.profit;

        print('[InventoryValueHistoryScreen] Processing Order ID: ${order.id}, Status: ${order.status}, Total: $totalPrice, Profit: $profit');

        if (profit != null) {
          final double costOfGoodsSold = totalPrice - profit;
          print('[InventoryValueHistoryScreen] Calculated COGS: $costOfGoodsSold for Order ID: ${order.id}');
          if (costOfGoodsSold > 0) { // Only consider orders that deducted value
            combinedEvents.add(InventoryValueEvent(
              id: order.id!,
              eventDate: order.createdAt,
              type: InventoryValueEventType.deducted,
              valueChange: costOfGoodsSold, // Store as positive, type indicates deduction
              description: 'Order: #${order.id!.substring(0, 8)} for ${order.brandName ?? 'N/A'}',
              rawData: orderMap, // Store for navigation to OrderDetailScreen
            ));
          } else {
            print('[InventoryValueHistoryScreen] Skipped Order ID ${order.id} due to non-positive COGS.');
          }
        } else {
          print('[InventoryValueHistoryScreen] Skipped Order ID ${order.id} due to null profit.');
        }
      }

      // Fetch inventory checker corrections (treated as value added/deducted based on sign)
      final correctionsResponse = await _supabase
          .from('inventory_log')
          .select('id, created_at, material_name, quantity_change, total_price_paid, unit_price_paid')
          .eq('change_type', 'CORRECTION')
          .order('created_at', ascending: false);

      for (var corr in (correctionsResponse as List)) {
        final map = corr as Map<String, dynamic>;
        final qtyChange = (map['quantity_change'] as num?)?.toDouble() ?? 0.0;
        final totalPricePaid = (map['total_price_paid'] as num?)?.toDouble();
        final unitPricePaid = (map['unit_price_paid'] as num?)?.toDouble() ?? 0.0;
        final double magnitude = totalPricePaid != null && totalPricePaid > 0
            ? totalPricePaid
            : (qtyChange.abs() * unitPricePaid);
        if (magnitude <= 0) continue;

        final isLoss = qtyChange < 0; // negative qty indicates loss
        combinedEvents.add(InventoryValueEvent(
          id: map['id'] as String,
          eventDate: DateTime.parse(map['created_at'] as String),
          type: isLoss ? InventoryValueEventType.deducted : InventoryValueEventType.added,
          valueChange: magnitude,
          description: isLoss
              ? 'Inventory check loss: ${map['material_name'] ?? 'Unknown'}'
              : 'Inventory check gain: ${map['material_name'] ?? 'Unknown'}',
          rawData: map,
        ));
      }

      // Sort combined events by date, most recent first
      combinedEvents.sort((a, b) => b.eventDate.compareTo(a.eventDate));

      if (mounted) {
        setState(() {
          _valueEvents = combinedEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching inventory value history: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load history: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Value History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: _fetchInventoryValueHistory, child: const Text('Retry'))
                      ],
                    ),
                  ),
                )
              : _valueEvents.isEmpty
                  ? const Center(
                      child: Text(
                        'No inventory value changes found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchInventoryValueHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _valueEvents.length,
                        itemBuilder: (context, index) {
                          final event = _valueEvents[index];
                          final isAdded = event.type == InventoryValueEventType.added;
                          final icon = isAdded ? Icons.arrow_upward : Icons.arrow_downward;
                          final color = isAdded ? Colors.green : Colors.red;
                          final prefix = isAdded ? '+' : '-';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.1),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(event.description, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(event.eventDate.toLocal())),
                              trailing: Text(
                                '$prefix${event.valueChange.toStringAsFixed(2)} €',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              onTap: () {
                                if (event.rawData == null) return;

                                if (event.type == InventoryValueEventType.added) {
                                  // Navigate to ReceiptDetailScreen
                                  // We need to ensure ReceiptDetailScreen can handle the rawData or just the ID
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReceiptDetailScreen(
                                        receiptId: event.id,
                                        // Pass other initial data if available and needed by ReceiptDetailScreen
                                        initialWholesalerName: event.rawData!['wholesaler_name'] as String?,
                                        initialDate: event.eventDate,
                                        initialTotalAmount: event.valueChange,
                                        initialImageUrl: event.rawData!['receipt_image_url'] as String?,
                                      ),
                                    ),
                                  );
                                } else if (event.type == InventoryValueEventType.deducted) {
                                  // Navigate to OrderDetailScreen
                                  final order = app_order.Order.fromJson(event.rawData!);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrderDetailScreen(order: order),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
