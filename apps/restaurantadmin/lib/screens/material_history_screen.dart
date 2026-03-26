import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/material_item.dart';
import 'package:restaurantadmin/models/inventory_log_item.dart';

/// Model for linked purchase items
class LinkedPurchaseItem {
  final String id;
  final String rawName; // Catalog name
  final String? receiptName; // Exact name from receipt
  final String? itemNumber;
  final String? supplierName;
  final String? supplierId;
  final String? baseUnit;
  final double? conversionRatio;
  final double? lastUnitPrice;
  final double? lastTotalPrice;
  final double? lastQuantity;
  final String? lastUnit;
  final DateTime? lastPurchaseDate;
  final int purchaseCount;

  LinkedPurchaseItem({
    required this.id,
    required this.rawName,
    this.receiptName,
    this.itemNumber,
    this.supplierName,
    this.supplierId,
    this.baseUnit,
    this.conversionRatio,
    this.lastUnitPrice,
    this.lastTotalPrice,
    this.lastQuantity,
    this.lastUnit,
    this.lastPurchaseDate,
    this.purchaseCount = 0,
  });
}

/// Model for supplier group
class SupplierGroup {
  final String? supplierId;
  final String supplierName;
  final List<LinkedPurchaseItem> items;

  SupplierGroup({
    this.supplierId,
    required this.supplierName,
    required this.items,
  });
}

class MaterialHistoryScreen extends StatefulWidget {
  final MaterialItem materialItem;
  final int initialTab; // 0 = History, 1 = Linked Items

  const MaterialHistoryScreen({
    super.key,
    required this.materialItem,
    this.initialTab = 0,
  });

  @override
  State<MaterialHistoryScreen> createState() => _MaterialHistoryScreenState();
}

class _MaterialHistoryScreenState extends State<MaterialHistoryScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<InventoryLogItem> _historyLogs = [];
  List<LinkedPurchaseItem> _linkedPurchaseItems = [];
  List<SupplierGroup> _supplierGroups = [];
  bool _isLoading = true;
  bool _isLoadingLinked = true;
  String? _error;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _fetchMaterialHistory();
    _fetchLinkedPurchaseItems();
    _fetchLinkedPurchaseItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMaterialHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final response = await _supabase
          .from('inventory_log')
          .select()
          .eq('material_id', widget.materialItem.id)
          .inFilter('change_type', [
            'ENTRY',
            'INITIAL_STOCK',
            'MANUAL_RECEIPT',
          ]) // Filter for stock additions
          .order('created_at', ascending: false); // Latest entries first

      if (mounted) {
        final List<dynamic> data = response as List<dynamic>;
        setState(() {
          _historyLogs = data
              .map(
                (item) =>
                    InventoryLogItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching history for ${widget.materialItem.name}: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load history: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchLinkedPurchaseItems() async {
    if (mounted) {
      setState(() => _isLoadingLinked = true);
    }

    try {
      // First, fetch purchase catalog items linked to this material
      final catalogResponse = await _supabase
          .from('purchase_catalog_items')
          .select('id, name, base_unit, conversion_ratio, supplier_id')
          .eq('material_id', widget.materialItem.id);

      debugPrint(
        'Found ${(catalogResponse as List).length} linked catalog items for ${widget.materialItem.name}',
      );

      final List<LinkedPurchaseItem> items = [];
      final Map<String, String> supplierNames = {}; // Cache supplier names

      for (final row in catalogResponse) {
        final catalogId = row['id'] as String;
        final supplierId = row['supplier_id'] as String?;

        // Fetch supplier name (with caching)
        String? supplierName;
        if (supplierId != null) {
          if (supplierNames.containsKey(supplierId)) {
            supplierName = supplierNames[supplierId];
          } else {
            try {
              final supplierResp = await _supabase
                  .from('suppliers')
                  .select('name')
                  .eq('id', supplierId)
                  .maybeSingle();
              supplierName = supplierResp?['name'] as String?;
              if (supplierName != null) {
                supplierNames[supplierId] = supplierName;
              }
            } catch (e) {
              debugPrint('Error fetching supplier: $e');
            }
          }
        }

        // Also try to get item data from ai_training_samples
        String? itemNumber;
        String? receiptName;
        double? lastPrice;
        double? lastQty;
        String? lastUnit;
        double? lastTotalPrice;

        // First try ai_training_samples (from AI trainer)
        try {
          final trainingSamples = await _supabase
              .from('ai_training_samples')
              .select('parsed_items')
              .eq('supplier_id', supplierId ?? '')
              .order('created_at', ascending: false)
              .limit(10);

          for (final sample in (trainingSamples as List)) {
            final sampleItems = sample['parsed_items'] as List<dynamic>?;
            if (sampleItems != null) {
              for (final item in sampleItems) {
                final itemMap = item as Map<String, dynamic>;
                final rawName = itemMap['raw_name'] as String?;
                if (rawName != null &&
                    rawName.toUpperCase() ==
                        (row['name'] as String?)?.toUpperCase()) {
                  itemNumber ??= itemMap['item_number'] as String?;
                  receiptName ??= rawName;
                  lastPrice ??= (itemMap['unit_price'] as num?)?.toDouble();
                  lastQty ??= (itemMap['quantity'] as num?)?.toDouble();
                  lastUnit ??= itemMap['unit'] as String?;
                  lastTotalPrice ??= (itemMap['total_price'] as num?)
                      ?.toDouble();
                  break;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching training samples: $e');
        }

        // Then try purchase_items for actual purchase records
        List<Map<String, dynamic>> purchaseItemsList = [];
        DateTime? lastDate;
        try {
          final piResp = await _supabase
              .from('purchase_items')
              .select(
                'id, raw_name, quantity, unit, unit_price, total_item_price, item_number, created_at, purchases(receipt_date)',
              )
              .eq('purchase_catalog_item_id', catalogId)
              .order('created_at', ascending: false);
          purchaseItemsList = (piResp as List).cast<Map<String, dynamic>>();

          if (purchaseItemsList.isNotEmpty) {
            final pi = purchaseItemsList.first;
            itemNumber ??= pi['item_number'] as String?;
            receiptName ??= pi['raw_name'] as String?;
            lastPrice = (pi['unit_price'] as num?)?.toDouble() ?? lastPrice;
            lastQty = (pi['quantity'] as num?)?.toDouble() ?? lastQty;
            lastUnit = pi['unit'] as String? ?? lastUnit;
            lastTotalPrice =
                (pi['total_item_price'] as num?)?.toDouble() ?? lastTotalPrice;

            final purchase = pi['purchases'] as Map<String, dynamic>?;
            final dateStr =
                purchase?['receipt_date'] as String? ??
                pi['created_at'] as String?;
            lastDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
          }
        } catch (e) {
          debugPrint('Error fetching purchase items: $e');
        }

        items.add(
          LinkedPurchaseItem(
            id: catalogId,
            rawName: row['name'] as String? ?? 'Unknown',
            receiptName: receiptName ?? row['name'] as String?,
            itemNumber: itemNumber,
            supplierName: supplierName ?? 'Unknown Supplier',
            supplierId: supplierId,
            baseUnit: row['base_unit'] as String?,
            conversionRatio: (row['conversion_ratio'] as num?)?.toDouble(),
            lastUnitPrice: lastPrice,
            lastTotalPrice:
                lastTotalPrice ??
                (lastPrice != null && lastQty != null
                    ? lastPrice * lastQty
                    : null),
            lastQuantity: lastQty,
            lastUnit: lastUnit,
            lastPurchaseDate: lastDate,
            purchaseCount: purchaseItemsList.length,
          ),
        );
      }

      // Group items by supplier
      final Map<String, List<LinkedPurchaseItem>> groupedBySupplier = {};
      for (final item in items) {
        final key = item.supplierId ?? 'unknown';
        if (!groupedBySupplier.containsKey(key)) {
          groupedBySupplier[key] = [];
        }
        groupedBySupplier[key]!.add(item);
      }

      // Create supplier groups
      final List<SupplierGroup> groups = [];
      for (final entry in groupedBySupplier.entries) {
        final supplierItems = entry.value;
        groups.add(
          SupplierGroup(
            supplierId: entry.key == 'unknown' ? null : entry.key,
            supplierName:
                supplierItems.first.supplierName ?? 'Unknown Supplier',
            items: supplierItems,
          ),
        );
      }

      // Sort groups by supplier name
      groups.sort((a, b) => a.supplierName.compareTo(b.supplierName));

      if (mounted) {
        setState(() {
          _linkedPurchaseItems = items;
          _supplierGroups = groups;
          _isLoadingLinked = false;
        });
      }
    } catch (e) {
      print('Error fetching linked purchase items: $e');
      if (mounted) {
        setState(() => _isLoadingLinked = false);
      }
    }
  }

  bool _isSavingStock = false; // For loading indicator in dialog

  // Method to show the "Add Stock" dialog
  Future<void> _showAddStockDialog() async {
    final formKey = GlobalKey<FormState>();
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController totalPriceController = TextEditingController();
    final TextEditingController wholesalerController = TextEditingController();
    // Receipt date will default to today in the save method

    showDialog<bool>(
      // Expect a boolean result
      context: context,
      barrierDismissible: !_isSavingStock, // Prevent dismissing while saving
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add Stock for ${widget.materialItem.name}'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: quantityController,
                        decoration: InputDecoration(
                          labelText:
                              'Quantity Added (${widget.materialItem.unitOfMeasure})',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0)
                            return 'Must be > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: totalPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Total Price Paid (€)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null ||
                              double.parse(value) < 0)
                            return 'Must be >= 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: wholesalerController,
                        decoration: const InputDecoration(
                          labelText: 'Wholesaler (Optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: _isSavingStock
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSavingStock
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => _isSavingStock = true);
                            final success = await _saveManualStockEntry(
                              widget.materialItem,
                              double.parse(quantityController.text),
                              double.parse(totalPriceController.text),
                              wholesalerController.text.isNotEmpty
                                  ? wholesalerController.text
                                  : null,
                            );
                            setDialogState(() => _isSavingStock = false);
                            if (success && mounted) {
                              Navigator.of(dialogContext).pop(true);
                              await _fetchMaterialHistory(); // Refresh history list
                            }
                          }
                        },
                  child: _isSavingStock
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _saveManualStockEntry(
    MaterialItem material,
    double quantityAdded,
    double totalPricePaid,
    String? wholesalerName,
  ) async {
    try {
      // 1. Create a new receipt record in scanned_receipts (optional, for linking, or use a generic placeholder)
      // For simplicity, manual entries might not need a scanned_receipt entry, or we can create a generic one.
      // Let's assume manual entries create a simple log without a dedicated receipt record.
      // If a receipt_id is strictly needed for inventory_log, create a placeholder or use null if allowed.

      // For this implementation, we'll just update material and create an inventory_log entry.
      // The receipt_id in inventory_log might be nullable or we use a special placeholder.

      final newReceiptId =
          'manual-${DateTime.now().millisecondsSinceEpoch}'; // Placeholder for manual entries

      print(
        '[MaterialHistoryScreen] quantityAdded for unit price calc: $quantityAdded, totalPricePaid for unit price calc: $totalPricePaid',
      );
      // 2. Calculate Unit Price for this Batch
      final double unitPriceForThisBatch = (quantityAdded > 0)
          ? totalPricePaid / quantityAdded
          : 0;
      print(
        '[MaterialHistoryScreen] Calculated unitPriceForThisBatch to be saved in inventory_log: $unitPriceForThisBatch',
      );

      // 3. Fetch Current Material Data & Calculate Weighted Average Cost
      final materialRecordResponse = await _supabase
          .from('material')
          .select('current_quantity, average_unit_cost')
          .eq('id', material.id)
          .single();

      final double oldQuantity =
          (materialRecordResponse['current_quantity'] as num?)?.toDouble() ??
          0.0;
      final double oldAverageCost =
          (materialRecordResponse['average_unit_cost'] as num?)?.toDouble() ??
          0.0;

      final double oldTotalValue = oldQuantity * oldAverageCost;
      final double addedValue = totalPricePaid;

      final double newTotalQuantity = oldQuantity + quantityAdded;
      final double newOverallTotalValue = oldTotalValue + addedValue;
      final double newWeightedAverageCost = (newTotalQuantity > 0)
          ? newOverallTotalValue / newTotalQuantity
          : 0;

      // 4. Update material Table
      await _supabase
          .from('material')
          .update({
            'current_quantity': newTotalQuantity,
            'average_unit_cost': newWeightedAverageCost,
          })
          .eq('id', material.id);

      // 5. Create inventory_log Entry
      await _supabase.from('inventory_log').insert({
        'material_id': material.id,
        'material_name': material.name,
        'change_type':
            'MANUAL_RECEIPT', // Or a new type like 'QUICK_STOCK_ENTRY'
        'quantity_change': quantityAdded,
        'new_quantity_after_change': newTotalQuantity,
        'unit_price_paid': unitPriceForThisBatch,
        'total_price_paid': totalPricePaid,
        'source_details': 'Quick Stock: ${wholesalerName ?? "N/A"}',
        'receipt_id': newReceiptId,
        'user_id': _supabase.auth.currentUser?.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${material.name} stock updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      print('Error saving new stock entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save stock: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      // _isSavingStock is handled by the dialog's setDialogState
    }
  }

  Widget _buildMaterialInfoHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[700]!, Colors.indigo[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Material image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                widget.materialItem.itemImageUrl != null &&
                    widget.materialItem.itemImageUrl!.isNotEmpty
                ? Image.network(
                    widget.materialItem.itemImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.inventory_2,
                      color: Colors.indigo[300],
                      size: 32,
                    ),
                  )
                : Icon(Icons.inventory_2, color: Colors.indigo[300], size: 32),
          ),
          const SizedBox(width: 16),
          // Material info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.materialItem.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip(
                      '${widget.materialItem.currentQuantity.toStringAsFixed(widget.materialItem.currentQuantity == widget.materialItem.currentQuantity.roundToDouble() ? 0 : 1)} ${widget.materialItem.unitOfMeasure}',
                      Icons.inventory,
                    ),
                    const SizedBox(width: 8),
                    if (widget.materialItem.weightedAverageCost != null)
                      _buildInfoChip(
                        '€${widget.materialItem.weightedAverageCost!.toStringAsFixed(3)}/${widget.materialItem.unitOfMeasure}',
                        Icons.euro,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _fetchMaterialHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_historyLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No stock entry history found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add stock using the + button below',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMaterialHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _historyLogs.length,
        itemBuilder: (context, index) {
          final log = _historyLogs[index];
          final formattedDate = DateFormat(
            'dd MMM yyyy, HH:mm',
          ).format(log.createdAt);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_circle,
                  color: Colors.green[600],
                  size: 24,
                ),
              ),
              title: Text(
                '+${log.quantityChange.toStringAsFixed(log.quantityChange == log.quantityChange.roundToDouble() ? 0 : 2)} ${widget.materialItem.unitOfMeasure}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green[700],
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (log.sourceDetails != null &&
                      log.sourceDetails!.isNotEmpty)
                    Text(
                      log.sourceDetails!,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  Row(
                    children: [
                      if (log.unitPricePaid != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4, right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '€${log.unitPricePaid!.toStringAsFixed(3)}/${widget.materialItem.unitOfMeasure}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      if (log.totalPricePaid != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Total: €${log.totalPricePaid!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinkedPurchaseItemsTab() {
    if (_isLoadingLinked) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_linkedPurchaseItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No linked purchase items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Train the AI with purchase receipts\nand map items to this material',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchLinkedPurchaseItems,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Material ID: ${widget.materialItem.id}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLinkedPurchaseItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _supplierGroups.length,
        itemBuilder: (context, index) {
          final group = _supplierGroups[index];
          return _buildSupplierCard(group);
        },
      ),
    );
  }

  Widget _buildSupplierCard(SupplierGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Supplier header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[700]!, Colors.purple[500]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.supplierName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.items.length} linked item${group.items.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items list
          ...group.items.map((item) => _buildLinkedItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildLinkedItemRow(LinkedPurchaseItem item) {
    // Calculate cost per material unit
    String? costPerUnitStr;
    String? costPer1UnitStr;
    if (item.lastTotalPrice != null &&
        item.conversionRatio != null &&
        item.conversionRatio! > 0 &&
        item.lastQuantity != null) {
      final totalMaterialQty = item.lastQuantity! * item.conversionRatio!;
      if (totalMaterialQty > 0) {
        final costPerMaterialUnit = item.lastTotalPrice! / totalMaterialQty;
        final unit = widget.materialItem.unitOfMeasure.toLowerCase();
        // Cost per 1 unit
        costPer1UnitStr =
            '€${costPerMaterialUnit.toStringAsFixed(4)}/1${widget.materialItem.unitOfMeasure}';
        // Cost per 1000 units for small units
        if (unit == 'ml' || unit == 'g' || unit == 'gram') {
          costPerUnitStr =
              '€${(costPerMaterialUnit * 1000).toStringAsFixed(2)}/1000${widget.materialItem.unitOfMeasure}';
        } else {
          costPerUnitStr =
              '€${costPerMaterialUnit.toStringAsFixed(3)}/${widget.materialItem.unitOfMeasure}';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Receipt name with item number and delete button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.receiptName ?? item.rawName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    if (item.itemNumber != null &&
                        item.itemNumber!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.qr_code,
                            size: 14,
                            color: Colors.blue[600],
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SKU: ${item.itemNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red[400],
                  size: 22,
                ),
                onPressed: () => _confirmDeleteLinkedItem(item),
                tooltip: 'Remove link',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // Conversion badge
              if (item.conversionRatio != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.conversionRatio!.toStringAsFixed(
                          item.conversionRatio ==
                                  item.conversionRatio!.roundToDouble()
                              ? 0
                              : 0,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      Text(
                        widget.materialItem.unitOfMeasure,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Price and quantity info
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Quantity
              if (item.lastQuantity != null)
                _buildLinkedInfoChip(
                  icon: Icons.inventory_2,
                  label:
                      '${item.lastQuantity!.toStringAsFixed(item.lastQuantity == item.lastQuantity!.roundToDouble() ? 0 : 1)} ${item.lastUnit ?? 'pcs'}',
                  color: Colors.teal,
                ),

              // Unit price
              if (item.lastUnitPrice != null)
                _buildLinkedInfoChip(
                  icon: Icons.euro,
                  label: '€${item.lastUnitPrice!.toStringAsFixed(2)}/pc',
                  color: Colors.green,
                ),

              // Total price
              if (item.lastTotalPrice != null)
                _buildLinkedInfoChip(
                  icon: Icons.receipt,
                  label: '€${item.lastTotalPrice!.toStringAsFixed(2)} total',
                  color: Colors.blue,
                ),

              // Cost per 1 unit (small)
              if (costPer1UnitStr != null)
                _buildLinkedInfoChip(
                  icon: Icons.analytics,
                  label: costPer1UnitStr,
                  color: Colors.indigo,
                ),

              // Cost per 1000 units
              if (costPerUnitStr != null)
                _buildLinkedInfoChip(
                  icon: Icons.calculate,
                  label: costPerUnitStr,
                  color: Colors.purple,
                ),

              // Last purchase date
              if (item.lastPurchaseDate != null)
                _buildLinkedInfoChip(
                  icon: Icons.calendar_today,
                  label: DateFormat(
                    'MMM d, yyyy',
                  ).format(item.lastPurchaseDate!),
                  color: Colors.grey,
                ),
            ],
          ),

          // Show "No purchase data yet" if we don't have purchase info
          if (item.lastQuantity == null && item.lastUnitPrice == null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linked but no purchase data yet. Scan a receipt from this supplier to see pricing info.',
                      style: TextStyle(fontSize: 11, color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteLinkedItem(LinkedPurchaseItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Link?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to unlink this purchase item from ${widget.materialItem.name}?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.receiptName ?? item.rawName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (item.supplierName != null)
                    Text(
                      'From: ${item.supplierName}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will NOT delete the purchase item itself, only the link to this material.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Link'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteLinkedItem(item);
    }
  }

  Future<void> _deleteLinkedItem(LinkedPurchaseItem item) async {
    try {
      // Delete from purchase_catalog_items (removes the link)
      await _supabase.from('purchase_catalog_items').delete().eq('id', item.id);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unlinked "${item.receiptName ?? item.rawName}" from ${widget.materialItem.name}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the list
        _fetchLinkedPurchaseItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLinkedInfoChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color[800],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.materialItem.name),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.history),
              text: 'History (${_historyLogs.length})',
            ),
            Tab(
              icon: const Icon(Icons.link),
              text: 'Linked Items (${_linkedPurchaseItems.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildMaterialInfoHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildHistoryTab(), _buildLinkedPurchaseItemsTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'material_history_add_stock_fab',
        onPressed: _showAddStockDialog,
        label: const Text('Add Stock'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}
