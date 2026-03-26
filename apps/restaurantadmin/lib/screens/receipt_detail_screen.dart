import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/inventory_log_item.dart'; // Assuming this is still relevant for item details

// Model for the main receipt data, fetched for this screen
class ReceiptFullDetails {
  final String id;
  final DateTime createdAt;
  final String? wholesalerName;
  final double? totalAmount;
  final String? receiptImageUrl;
  final DateTime? receiptDate;
  final String? sourceDetails;
  final String? status; // Added status
  // Add other fields from your 'receipts' table as needed

  ReceiptFullDetails({
    required this.id,
    required this.createdAt,
    this.wholesalerName,
    this.totalAmount,
    this.receiptImageUrl,
    this.receiptDate,
    this.sourceDetails,
    this.status, // Added status
  });

  factory ReceiptFullDetails.fromJson(Map<String, dynamic> json) {
    return ReceiptFullDetails(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      wholesalerName: json['wholesaler_name'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      receiptImageUrl: json['receipt_image_url'] as String?,
      receiptDate: json['receipt_date'] != null
          ? DateTime.parse(json['receipt_date'] as String)
          : null,
      sourceDetails: json['source_details'] as String?,
      status:
          json['status'] as String? ??
          'active', // Added status, default to active
    );
  }
}

class ReceiptDetailScreen extends StatefulWidget {
  final String receiptId;
  // Optional: Pass initial summary data to avoid re-fetching some parts
  final String? initialWholesalerName;
  final DateTime? initialDate;
  final double? initialTotalAmount;
  final String? initialImageUrl;

  const ReceiptDetailScreen({
    super.key,
    required this.receiptId,
    this.initialWholesalerName,
    this.initialDate,
    this.initialTotalAmount,
    this.initialImageUrl,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  ReceiptFullDetails? _receiptDetails;
  List<InventoryLogItem> _receiptItems = [];
  bool _isLoading = true;
  bool _isCancelling = false; // State for cancellation process
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _fetchReceiptDetailsAndItems();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _fetchReceiptDetailsAndItems() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Fetch main receipt details
      final receiptResponse = await _supabase
          .from('receipts')
          .select() // Select all columns to get status
          .eq('id', widget.receiptId)
          .single();

      if (!mounted) return;
      _receiptDetails = ReceiptFullDetails.fromJson(receiptResponse);

      // Fetch items associated with this receipt
      final itemsResponse = await _supabase
          .from('inventory_log')
          .select()
          .eq('receipt_id', widget.receiptId)
          .order('material_name', ascending: true);

      if (!mounted) return;
      _receiptItems = (itemsResponse as List)
          .map(
            (item) => InventoryLogItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching receipt details: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load receipt details: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canCancel =
        _receiptDetails?.status == 'active' && !_isCancelling;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _receiptDetails?.wholesalerName ??
              widget.initialWholesalerName ??
              'Receipt Details',
        ),
        actions: [
          if (_receiptDetails != null && _receiptDetails!.status == 'cancelled')
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Chip(
                label: Text('Cancelled', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.red[400],
              ),
            ),
          if (canCancel)
            _isCancelling
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.cancel_outlined),
                    tooltip: 'Cancel Receipt',
                    onPressed: _showCancelConfirmationDialog,
                  ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _fetchReceiptDetailsAndItems,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _receiptDetails == null
          ? const Center(child: Text('Receipt not found.'))
          : RefreshIndicator(
              onRefresh: _fetchReceiptDetailsAndItems,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReceiptHeader(),
                    const SizedBox(height: 20),
                    if (_receiptDetails!.receiptImageUrl != null &&
                        _receiptDetails!.receiptImageUrl!.isNotEmpty) ...[
                      Text(
                        'Receipt Image',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // Optional: Show fullscreen image
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InteractiveViewer(
                                  child: Image.network(
                                    _receiptDetails!.receiptImageUrl!,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            _receiptDetails!.receiptImageUrl!,
                            height: 300,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (context, error, stack) => const Icon(
                              Icons.broken_image,
                              size: 100,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      'Items on this Receipt (${_receiptItems.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _buildItemsList(),
                  ],
                ),
              ),
            ),
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Cancellation'),
          content: const Text(
            'Are you sure you want to cancel this receipt? This action will reverse the stock additions and update inventory quantities. This cannot be easily undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('No, Keep Receipt'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Cancel Receipt'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                _cancelReceipt(); // Proceed with cancellation
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelReceipt() async {
    if (!mounted || _receiptDetails == null) return;
    setState(() => _isCancelling = true);

    try {
      // 1. Fetch original inventory log items for this receipt
      // We need items that were part of the original receipt addition.
      // Assuming 'MANUAL_RECEIPT' is the primary change_type for items added via ManualReceiptScreen.
      // If other change_types could be part of a receipt, this filter might need adjustment.
      final originalLogItemsResponse = await _supabase
          .from('inventory_log')
          .select(
            'id, material_id, material_name, quantity_change, unit_price_paid, total_price_paid',
          )
          .eq('receipt_id', widget.receiptId)
          .eq(
            'change_type',
            'MANUAL_RECEIPT',
          ); // Filter for the original addition logs

      if (!mounted) return;

      final List<Map<String, dynamic>> originalLogs =
          (originalLogItemsResponse as List).cast<Map<String, dynamic>>();

      List<Map<String, dynamic>> reversalLogEntries = [];
      List<Future<void>> materialUpdateFutures = [];

      for (var log in originalLogs) {
        final String materialId = log['material_id'] as String;
        final double originalQuantityAdded = (log['quantity_change'] as num)
            .toDouble();

        // Fetch current material quantity and average_unit_cost
        final materialRes = await _supabase
            .from('material')
            .select(
              'current_quantity, average_unit_cost',
            ) // Fetch average_unit_cost as well
            .eq('id', materialId)
            .maybeSingle(); // Use maybeSingle to handle cases where material might have been deleted

        if (materialRes == null) {
          print(
            "Error cancelling receipt: Material with ID $materialId not found for log entry ${log['id']}. Skipping stock reversal for this item.",
          );
          // Optionally, collect these errors to inform the user
          continue; // Skip to the next log item if material not found
        }

        final double currentMaterialQtyInStock =
            (materialRes['current_quantity'] as num?)?.toDouble() ?? 0.0;
        final double currentAverageUnitCost =
            (materialRes['average_unit_cost'] as num?)?.toDouble() ?? 0.0;
        final double totalPricePaidForThisBatchInReceipt =
            (log['total_price_paid'] as num?)?.toDouble() ?? 0.0;

        final double currentTotalValueInStock =
            currentMaterialQtyInStock * currentAverageUnitCost;

        final double newTotalQuantity =
            currentMaterialQtyInStock - originalQuantityAdded;
        // Ensure newTotalQuantity does not go below zero, though logically it shouldn't if data is consistent.
        // If newTotalQuantity is < 0, it implies an inconsistency (more was cancelled than existed based on current stock).
        // This could happen if other stock subtractions occurred between receipt entry and cancellation.
        // For simplicity, we'll cap at 0. A more robust solution might flag this as an inventory discrepancy.
        final double adjustedNewTotalQuantity = newTotalQuantity < 0
            ? 0.0
            : newTotalQuantity;

        final double newTotalValue =
            currentTotalValueInStock - totalPricePaidForThisBatchInReceipt;
        // Ensure newTotalValue doesn't go below zero if costs are positive.
        final double adjustedNewTotalValue = newTotalValue < 0
            ? 0.0
            : newTotalValue;

        final double newAverageUnitCost = (adjustedNewTotalQuantity > 0)
            ? adjustedNewTotalValue / adjustedNewTotalQuantity
            : 0.0;

        // Prepare material update
        materialUpdateFutures.add(
          _supabase
              .from('material')
              .update({
                'current_quantity': adjustedNewTotalQuantity,
                'average_unit_cost': newAverageUnitCost,
              })
              .eq('id', materialId),
        );

        // Prepare reversal inventory log entry
        reversalLogEntries.add({
          'material_id': materialId,
          'material_name': log['material_name'] as String,
          'change_type': 'RECEIPT_CANCELLED',
          'quantity_change': -originalQuantityAdded,
          'new_quantity_after_change': adjustedNewTotalQuantity,
          'unit_price_paid': (log['unit_price_paid'] as num?)?.toDouble(),
          'total_price_paid': totalPricePaidForThisBatchInReceipt != 0
              ? -totalPricePaidForThisBatchInReceipt
              : null,
          'source_details':
              'Reversal of cancelled receipt ID: ${widget.receiptId}',
          'receipt_id': widget.receiptId,
          'user_id': _supabase.auth.currentUser?.id,
        });
      }

      // Execute all material updates
      await Future.wait(materialUpdateFutures);

      // Insert all reversal log entries
      if (reversalLogEntries.isNotEmpty) {
        await _supabase.from('inventory_log').insert(reversalLogEntries);
      }

      // Insert into canceled_receipts table BEFORE updating the original status
      if (_receiptDetails != null) {
        await _supabase.from('canceled_receipts').insert({
          'original_receipt_id': _receiptDetails!.id,
          'wholesaler_name': _receiptDetails!.wholesalerName,
          'total_amount': _receiptDetails!.totalAmount,
          'receipt_date': _receiptDetails!.receiptDate?.toIso8601String(),
          'receipt_image_url': _receiptDetails!.receiptImageUrl,
          'source_details': _receiptDetails!.sourceDetails,
          'created_at': _receiptDetails!.createdAt
              .toIso8601String(), // Changed to 'created_at'
          // 'user_id': _receiptDetails!.user_id, // Assuming ReceiptFullDetails has user_id and canceled_receipts has user_id for original user
          'cancellation_reason': 'Cancelled via app by user.', // Default reason
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancelled_by_user_id': _supabase.auth.currentUser?.id,
          'original_status': _receiptDetails!.status ?? 'active',
        });
      }

      // Then, update the original receipt status
      await _supabase
          .from('receipts')
          .update({'status': 'cancelled'})
          .eq('id', widget.receiptId);

      if (!mounted) return;
      _showSuccessSnackBar(
        'Receipt cancelled and inventory updated successfully!',
      );
      Navigator.of(
        context,
      ).pop(true); // Pop and indicate success to refresh previous screen
    } catch (e) {
      print('Error cancelling receipt: $e');
      if (mounted) {
        _showErrorSnackBar('Error cancelling receipt: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Widget _buildReceiptHeader() {
    final receiptDate = _receiptDetails?.receiptDate ?? widget.initialDate;
    final totalAmount =
        _receiptDetails?.totalAmount ?? widget.initialTotalAmount;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_receiptDetails?.wholesalerName != null)
              Text(
                _receiptDetails!.wholesalerName!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (receiptDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Date: ${DateFormat('dd MMM yyyy').format(receiptDate)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            if (_receiptDetails?.sourceDetails != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Source: ${_receiptDetails!.sourceDetails}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            if (totalAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Total Amount: €${totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_receiptItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text('No items found for this receipt.')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _receiptItems.length,
      itemBuilder: (context, index) {
        final itemLog = _receiptItems[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            title: Text(itemLog.materialName),
            subtitle: Text(
              'Qty: ${itemLog.quantityChange.toStringAsFixed(itemLog.quantityChange.truncateToDouble() == itemLog.quantityChange ? 0 : 2)} - Unit Price: €${itemLog.unitPricePaid?.toStringAsFixed(3) ?? 'N/A'}',
            ), // Changed to 3 decimal places
            trailing: Text(
              'Total: €${itemLog.totalPricePaid?.toStringAsFixed(2) ?? 'N/A'}',
            ),
          ),
        );
      },
    );
  }
}
