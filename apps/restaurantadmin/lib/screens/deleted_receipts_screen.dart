import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Model for displaying a cancelled receipt's summary
class CancelledReceiptSummary {
  final String originalReceiptId;
  final String? wholesalerName;
  final double? totalAmount;
  final DateTime? originalReceiptDate;
  final DateTime cancelledAt;
  final String? cancellationReason;
  final String? receiptImageUrl; // Added to potentially show image

  CancelledReceiptSummary({
    required this.originalReceiptId,
    this.wholesalerName,
    this.totalAmount,
    this.originalReceiptDate,
    required this.cancelledAt,
    this.cancellationReason,
    this.receiptImageUrl, // Added
  });

  factory CancelledReceiptSummary.fromJson(Map<String, dynamic> json) {
    return CancelledReceiptSummary(
      originalReceiptId: json['original_receipt_id'] as String? ?? json['id'] as String, // Fallback to id if original_receipt_id is null
      wholesalerName: json['wholesaler_name'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      originalReceiptDate: json['receipt_date'] != null ? DateTime.parse(json['receipt_date'] as String) : null,
      cancelledAt: DateTime.parse(json['cancelled_at'] as String),
      cancellationReason: json['cancellation_reason'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?, // Added
    );
  }
}

class DeletedReceiptsScreen extends StatefulWidget {
  const DeletedReceiptsScreen({super.key});

  @override
  State<DeletedReceiptsScreen> createState() => _DeletedReceiptsScreenState();
}

class _DeletedReceiptsScreenState extends State<DeletedReceiptsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<CancelledReceiptSummary> _cancelledReceipts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCancelledReceipts();
  }

  Future<void> _fetchCancelledReceipts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _supabase
          .from('canceled_receipts')
          .select()
          .order('cancelled_at', ascending: false);

      if (!mounted) return;

      final List<CancelledReceiptSummary> loadedReceipts = (response as List)
          .map((data) => CancelledReceiptSummary.fromJson(data as Map<String, dynamic>))
          .toList();
      
      setState(() {
        _cancelledReceipts = loadedReceipts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching cancelled receipts: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load cancelled receipts: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancelled Receipts Log'),
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
                        ElevatedButton(onPressed: _fetchCancelledReceipts, child: const Text('Retry'))
                      ],
                    ),
                  ),
                )
              : _cancelledReceipts.isEmpty
                  ? const Center(
                      child: Text('No cancelled receipts found.', style: TextStyle(fontSize: 16)),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchCancelledReceipts,
                      child: ListView.builder(
                        itemCount: _cancelledReceipts.length,
                        itemBuilder: (context, index) {
                          final receipt = _cancelledReceipts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red[100],
                                child: Icon(Icons.receipt_long_outlined, color: Colors.red[700]),
                              ),
                              title: Text(receipt.wholesalerName ?? 'Receipt ID: ${receipt.originalReceiptId.substring(0,8)}...'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (receipt.originalReceiptDate != null)
                                    Text('Original Date: ${DateFormat('dd MMM yyyy').format(receipt.originalReceiptDate!)}'),
                                  Text('Cancelled: ${DateFormat('dd MMM yyyy, HH:mm').format(receipt.cancelledAt)}'),
                                  if (receipt.totalAmount != null)
                                    Text('Total: €${receipt.totalAmount!.toStringAsFixed(2)}'),
                                  if (receipt.cancellationReason != null && receipt.cancellationReason!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text('Reason: ${receipt.cancellationReason}', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600])),
                                    ),
                                ],
                              ),
                              isThreeLine: true, // Adjust based on content
                              // Optional: onTap to view more details if needed, though most info is here
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
