import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'widgets/receipt_viewer_dialog.dart';
import 'package:restaurantadmin/screens/scanned_order_receipt_screen.dart';
import 'package:restaurantadmin/screens/document_scanner_screen.dart';
import 'package:restaurantadmin/screens/purchase_ai_trainer_screen.dart';
import 'package:restaurantadmin/models/scan_type.dart';
import 'package:restaurantadmin/services/order_service.dart';
import 'package:restaurantadmin/models/order.dart';
import 'package:restaurantadmin/utils/snackbar_utils.dart' as snackbar_utils;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'receipt_watcher_download_stub.dart'
    if (dart.library.html) 'receipt_watcher_download_web.dart' as receipt_download;

const String _defaultOrderPrompt = '''
For an "order" receipt (e.g., from Lieferando, Wolt, Uber Eats), use this JSON structure:
{
  "classification": "order",
  "brandName": "string | null",
  "platformOrderId": "string | null",
  "orderDate": "string (YYYY-MM-DDTHH:mm:ssZ) | null",
  "fulfillmentType": "'delivery' | 'pickup' | null",
  "totalPrice": "number | null",
  "deliveryFee": "number | null",
  "paymentMethod": "'online' | 'cash' | 'card' | 'unknown' | null",
  "customerName": "string | null",
  "customerStreet": "string | null",
  "customerPostcode": "string | null",
  "customerCity": "string | null",
  "orderItems": [
    {
      "name": "string",
      "quantity": "number",
      "price": "number | null"
    }
  ],
  "note": "string | null (any special instructions or notes)",
  "fixedServiceFee": "number | null",
  "commissionAmount": "number | null",
  "orderTypeName": "string | null"
}''';

const String _defaultPurchasePrompt = '''
For a "purchase" receipt (e.g., from a supplier like Metro, Spar), use this JSON structure:
{
  "classification": "purchase",
  "supplierName": "string | null",
  "totalAmount": "number | null",
  "receiptDate": "string (YYYY-MM-DD) | null"
}

IMPORTANT: For receiptDate, look at the actual printed date on the receipt/invoice document. 
This is typically found near the top of the document, labeled as "Datum", "Date", "Rechnungsdatum", "Invoice Date", etc.
Extract this date in YYYY-MM-DD format. Do NOT use the current date - use the date printed on the document.''';

class ReceiptWatcherScreen extends StatefulWidget {
  const ReceiptWatcherScreen({super.key});

  @override
  State<ReceiptWatcherScreen> createState() => _ReceiptWatcherScreenState();
}

class _ReceiptWatcherScreenState extends State<ReceiptWatcherScreen> {
  final _supabase = Supabase.instance.client;
  final _orderService = OrderService();
  late RealtimeChannel _channel;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  // Filter and summary state
  dynamic _filterValue =
      'today'; // 'today', 'yesterday', 'this_week', or a DateTime
  double _orderTotal = 0.0;
  double _purchaseTotal = 0.0;
  List<DateTime> _availableDates = [];
  final List<dynamic> _displayList = []; // Flattened list for ListView

  // Scanner prompt state
  String? _promptError;
  String _currentOrderPrompt = '';
  String _currentPurchasePrompt = '';

  // Converting to order state
  String? _convertingReceiptId;

  // Scanning state
  bool _isScanning = false;

  // Gemini API configuration
  static const String _geminiApiKey = 'AIzaSyAiYA0l0aUtD-NSxoCElkMNPX9IQy25DZU';
  static const List<String> _geminiModels = [
    'gemini-2.5-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLatest();
    _loadPrompt();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    try {
      _channel.unsubscribe();
    } catch (_) {}
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('public:scanned_receipts:insert_listener')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scanned_receipts',
          callback: (payload) async {
            await _fetchLatest();
          },
        )
        .subscribe();
  }

  Future<void> _loadPrompt() async {
    setState(() {
      _promptError = null;
    });
    try {
      final row = await _supabase
          .from('scanner_settings')
          .select('id,order_prompt,purchase_prompt')
          .eq('id', 'default')
          .maybeSingle();
      if (mounted) {
        setState(() {
          _currentOrderPrompt =
              (row?['order_prompt'] as String?) ?? _defaultOrderPrompt;
          _currentPurchasePrompt =
              (row?['purchase_prompt'] as String?) ?? _defaultPurchasePrompt;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _promptError = e.toString();
          _currentOrderPrompt = _defaultOrderPrompt;
          _currentPurchasePrompt = _defaultPurchasePrompt;
        });
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _savePrompts(
    String newOrderPrompt,
    String newPurchasePrompt,
  ) async {
    try {
      await _supabase.from('scanner_settings').upsert({
        'id': 'default',
        'order_prompt': newOrderPrompt,
        'purchase_prompt': newPurchasePrompt,
      });
      setState(() {
        _currentOrderPrompt = newOrderPrompt;
        _currentPurchasePrompt = newPurchasePrompt;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prompts saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save prompts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchLatest() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('scanned_receipts')
          .select('*')
          .order('created_at', ascending: false)
          .limit(500);
      if (mounted) {
        _rows = List<Map<String, dynamic>>.from(data as List);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        _processData();
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _processData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // --- 1. Filter rows ---
    List<Map<String, dynamic>> filteredRows;

    if (_filterValue == 'today') {
      filteredRows = _rows.where((row) {
        final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
        // Check if same day (year, month, day match)
        return createdAt.year == now.year && 
               createdAt.month == now.month && 
               createdAt.day == now.day;
      }).toList();
    } else if (_filterValue == 'yesterday') {
      final yesterday = today.subtract(const Duration(days: 1));
      filteredRows = _rows.where((row) {
        final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
        return createdAt.isAfter(yesterday) && createdAt.isBefore(today);
      }).toList();
    } else if (_filterValue == 'this_week') {
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      filteredRows = _rows.where((row) {
        final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
        return createdAt.isAfter(startOfWeek);
      }).toList();
    } else if (_filterValue == 'this_month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      filteredRows = _rows.where((row) {
        final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
        return createdAt.isAfter(startOfMonth);
      }).toList();
    } else if (_filterValue is DateTime) {
      final filterDate = _filterValue as DateTime;
      filteredRows = _rows.where((row) {
        final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
        final dateKey = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
        );
        return dateKey.isAtSameMomentAs(filterDate);
      }).toList();
    } else {
      // 'all'
      filteredRows = List.from(_rows);
    }

    // --- 2. Calculate totals ---
    double orderTotal = 0;
    double purchaseTotal = 0;
    for (final row in filteredRows) {
      final data = row['extracted_data'];
      if (data is Map) {
        if (data['classification'] == 'order') {
          orderTotal += (data['totalPrice'] as num?) ?? 0.0;
        } else if (data['classification'] == 'purchase') {
          purchaseTotal += (data['totalAmount'] as num?) ?? 0.0;
        }
      }
    }

    // --- 3. Group rows ---
    final Map<DateTime, List<Map<String, dynamic>>> grouped = {};
    for (final row in filteredRows) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final dateKey = DateTime(createdAt.year, createdAt.month, createdAt.day);
      if (grouped[dateKey] == null) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(row);
    }

    // --- 4. Get available dates for filter dropdown ---
    final Set<DateTime> dates = {};
    for (final row in _rows) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      dates.add(DateTime(createdAt.year, createdAt.month, createdAt.day));
    }
    final sortedDates = dates.toList()..sort((a, b) => b.compareTo(a));

    // --- 5. Create flattened list for display ---
    _displayList.clear();
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final date in sortedKeys) {
      _displayList.add(date); // Add date header
      _displayList.addAll(grouped[date]!); // Add receipt items
    }

    // --- 6. Update state ---
    setState(() {
      _orderTotal = orderTotal;
      _purchaseTotal = purchaseTotal;
      if (_availableDates.isEmpty ||
          _availableDates.length != sortedDates.length) {
        _availableDates = sortedDates;
      }
    });
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (date.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat.yMMMMd().format(date);
    }
  }

  Future<String?> _signedUrlFor(Map<String, dynamic> row) async {
    try {
      final path = row['storage_path'] as String?;
      if (path == null || path.isEmpty) return null;
      final res = await _supabase.storage
          .from('scanned-receipts')
          .createSignedUrl(path, 60);
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadReceipt(Map<String, dynamic> row) async {
    final url = await _signedUrlFor(row);
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get receipt image'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final extractedData = row['extracted_data'];
      String name = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (extractedData is Map) {
        final isOrder = (row['scan_type'] as String?) == 'order';
        final brandOrSupplier = isOrder
            ? (extractedData['brandName'] as String?)
            : (extractedData['supplierName'] as String?);
        final dateStr = extractedData['receiptDate'] ?? row['created_at'];
        final date = dateStr != null ? DateTime.tryParse(dateStr.toString()) : null;
        final part1 = date != null ? DateFormat('yyyy-MM-dd').format(date) : '';
        final part2 = (brandOrSupplier ?? 'receipt')
            .toString()
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '_')
            .toLowerCase();
        if (part1.isNotEmpty || part2.isNotEmpty) {
          name = '${part1}_${part2}.jpg'.replaceAll(RegExp(r'^_|_$'), '');
          if (name.startsWith('_')) name = name.substring(1);
          if (name.isEmpty) name = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
      }
      await receipt_download.openReceiptDownload(url, suggestedFilename: name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb
                ? 'Receipt opened in new tab — save it from there'
                : 'Receipt saved to Downloads'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _aiSummaryForRow(Map<String, dynamic> row) async {
    try {
      final extractedData = row['extracted_data'];
      if (extractedData == null || extractedData is! Map) {
        // Fallback to old method for receipts processed before this change
        final isOrder = ((row['scan_type'] as String?) ?? 'order') == 'order';
        if (isOrder && row['created_order_id'] != null) {
          return await _fetchLegacyOrderSummary(row['created_order_id']);
        } else if (!isOrder && row['created_purchase_id'] != null) {
          return await _fetchLegacyPurchaseSummary(row['created_purchase_id']);
        }
        return '';
      }

      final data = Map<String, dynamic>.from(extractedData);
      final isOrder = data['classification'] == 'order';

      String fmtNum(n) => (n == null)
          ? '-'
          : NumberFormat.currency(
              symbol: '€',
            ).format((n is num) ? n : num.tryParse('$n') ?? 0);

      if (isOrder) {
        final parts = <String>[
          if (data['platformOrderId'] != null)
            'Platform ID: ${data['platformOrderId']}',
          'Total: ${fmtNum(data['totalPrice'])}',
          'Fees: Dlv ${fmtNum(data['deliveryFee'])}  Svc ${fmtNum(data['fixedServiceFee'])}  Com ${fmtNum(data['commissionAmount'])}',
          'Note: ${data['note']?.toString() ?? '-'}',
          if (data['orderTypeName'] != null) 'Type: ${data['orderTypeName']}',
          if (data['paymentMethod'] != null)
            'Payment: ${data['paymentMethod']}',
        ];
        return parts
            .where((s) => s.trim().isNotEmpty && !s.contains('€-'))
            .join('  •  ');
      } else {
        // Purchase
        final dt = (data['receiptDate'] is String)
            ? DateTime.tryParse(data['receiptDate'])
            : null;
        return 'Total: ${fmtNum(data['totalAmount'])}${dt != null ? '  •  ${DateFormat.yMMMd().format(dt.toLocal())}' : ''}';
      }
    } catch (_) {}
    return '';
  }

  // Helper for backwards compatibility
  Future<String> _fetchLegacyOrderSummary(String orderId) async {
    final data = await _supabase
        .from('orders')
        .select(
          'platform_order_id,total_price,fixed_service_fee,commission_amount,delivery_fee,note,order_type_name,payment_method',
        )
        .eq('id', orderId)
        .maybeSingle();
    if (data != null) {
      final m = Map<String, dynamic>.from(data);
      String fmtNum(n) => (n == null)
          ? '-'
          : NumberFormat.currency(
              symbol: '€',
            ).format((n is num) ? n : num.tryParse('$n') ?? 0);
      final parts = <String>[
        if (m['platform_order_id'] != null)
          'Platform ID: ${m['platform_order_id']}',
        'Total: ${fmtNum(m['total_price'])}',
        'Fees: Dlv ${fmtNum(m['delivery_fee'])}  Svc ${fmtNum(m['fixed_service_fee'])}  Com ${fmtNum(m['commission_amount'])}',
        'Note: ${m['note']?.toString() ?? '-'}',
        if (m['order_type_name'] != null) 'Type: ${m['order_type_name']}',
        if (m['payment_method'] != null) 'Payment: ${m['payment_method']}',
      ];
      return parts
          .where((s) => s.trim().isNotEmpty && !s.endsWith('-'))
          .join('  •  ');
    }
    return '';
  }

  Future<String> _fetchLegacyPurchaseSummary(String purchaseId) async {
    final data = await _supabase
        .from('purchases')
        .select('total_amount,receipt_date')
        .eq('id', purchaseId)
        .maybeSingle();
    if (data != null) {
      final m = Map<String, dynamic>.from(data);
      String fmtNum(n) => (n == null)
          ? '-'
          : NumberFormat.currency(
              symbol: '€',
            ).format((n is num) ? n : num.tryParse('$n') ?? 0);
      final dt = (m['receipt_date'] is String)
          ? DateTime.tryParse(m['receipt_date'])
          : null;
      return 'Total: ${fmtNum(m['total_amount'])}${dt != null ? '  •  ${DateFormat.yMMMd().format(dt.toLocal())}' : ''}';
    }
    return '';
  }

  /// Convert a scanned receipt to an order using Gemini AI
  Future<void> _convertToOrder(Map<String, dynamic> row) async {
    final receiptId = row['id']?.toString();
    if (receiptId == null) return;

    setState(() => _convertingReceiptId = receiptId);

    try {
      // Check if already has a created order
      if (row['created_order_id'] != null) {
        if (mounted) {
          snackbar_utils.showInfoSnackbar(
            context,
            'This receipt already has an order created (ID: ${row['created_order_id']})',
          );
        }
        return;
      }

      // Get the image from storage
      final storagePath = row['storage_path'] as String?;
      if (storagePath == null || storagePath.isEmpty) {
        throw Exception('No image found for this receipt');
      }

      // Check if we already have extracted_data that looks like an order
      Map<String, dynamic>? orderData;
      final existingData = row['extracted_data'];

      if (existingData is Map &&
          existingData['classification'] == 'order' &&
          existingData['brandName'] != null) {
        // Use existing order data
        orderData = Map<String, dynamic>.from(existingData);
      } else {
        // Need to analyze with Gemini
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analyzing receipt with AI...'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        }

        // Get signed URL and download image
        final signedUrl = await _supabase.storage
            .from('scanned-receipts')
            .createSignedUrl(storagePath, 120);

        final imageResponse = await http.get(Uri.parse(signedUrl));
        if (imageResponse.statusCode != 200) {
          throw Exception('Failed to download receipt image');
        }

        final base64Image = base64Encode(imageResponse.bodyBytes);

        // Detect MIME type
        String mimeType = 'image/jpeg';
        if (storagePath.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (storagePath.toLowerCase().endsWith('.pdf')) {
          mimeType = 'application/pdf';
        }

        // Call Gemini to analyze as order
        orderData = await _analyzeReceiptAsOrder(base64Image, mimeType);

        if (orderData == null) {
          throw Exception('AI could not analyze this receipt as an order');
        }
      }

      // Try to create order using OrderService first
      Order? createdOrder;
      String? lastError;

      try {
        createdOrder = await _orderService.createOrderFromScannedData(
          orderData,
          fulfillmentType: orderData['fulfillmentType'] as String?,
        );
      } catch (e) {
        debugPrint('OrderService error: $e');
        lastError = e.toString();
      }

      // If OrderService failed (likely brand/menu item mismatch), create order directly
      if (createdOrder == null) {
        debugPrint('OrderService failed, creating order directly...');
        try {
          createdOrder = await _createOrderDirectly(orderData);
        } catch (e) {
          debugPrint('Direct create error: $e');
          lastError = e.toString();
        }
      }

      if (createdOrder == null) {
        throw Exception(
          'Failed to create order: ${lastError ?? "Unknown error - check console logs"}',
        );
      }

      // Update the scanned_receipts record with the created order ID
      await _supabase
          .from('scanned_receipts')
          .update({
            'created_order_id': createdOrder.id,
            'scan_type': 'order',
            'brand_name': createdOrder.brandName ?? orderData['brandName'],
          })
          .eq('id', receiptId);

      // Refresh the list
      await _fetchLatest();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Created Successfully!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Order #${createdOrder.orderNumber ?? createdOrder.id?.substring(0, 8)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View Orders',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to orders screen (index 1 in main navigation)
                // For now just close snackbar
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error converting to order: $e');
      if (mounted) {
        snackbar_utils.showErrorSnackbar(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _convertingReceiptId = null);
      }
    }
  }

  /// Create an order directly without requiring menu item matching
  Future<Order?> _createOrderDirectly(Map<String, dynamic> orderData) async {
    try {
      // Get all brands from database for matching
      final allBrands = await _supabase.from('brands').select('id, name');

      debugPrint('Available brands: $allBrands');

      String? brandId;
      String? matchedBrandName;
      final brandName = orderData['brandName'] as String?;

      if (brandName != null && allBrands.isNotEmpty) {
        final searchName = brandName.toUpperCase().trim();
        debugPrint('Looking for brand: $searchName');

        // Try exact match (case-insensitive)
        for (final brand in allBrands) {
          final dbName = (brand['name'] as String?)?.toUpperCase().trim() ?? '';
          if (dbName == searchName) {
            brandId = brand['id'] as String?;
            matchedBrandName = brand['name'] as String?;
            debugPrint('Exact match found: $matchedBrandName ($brandId)');
            break;
          }
        }

        // Try partial/fuzzy match
        if (brandId == null) {
          for (final brand in allBrands) {
            final dbName =
                (brand['name'] as String?)?.toUpperCase().trim() ?? '';
            // Check if one contains the other, or significant word overlap
            if (dbName.contains(searchName) || searchName.contains(dbName)) {
              brandId = brand['id'] as String?;
              matchedBrandName = brand['name'] as String?;
              debugPrint('Partial match found: $matchedBrandName ($brandId)');
              break;
            }
            // Check word-by-word matching (e.g., "CRISPY CHICKEN LAB" matches "Crispy Chicken Lab")
            final dbWords = dbName
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .toSet();
            final searchWords = searchName
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .toSet();
            final commonWords = dbWords.intersection(searchWords);
            if (commonWords.length >= 2 ||
                (commonWords.length == 1 && searchWords.length == 1)) {
              brandId = brand['id'] as String?;
              matchedBrandName = brand['name'] as String?;
              debugPrint(
                'Word match found: $matchedBrandName ($brandId) - common words: $commonWords',
              );
              break;
            }
          }
        }
      }

      // If still no match, use first brand as fallback
      if (brandId == null && allBrands.isNotEmpty) {
        brandId = allBrands[0]['id'] as String?;
        matchedBrandName = allBrands[0]['name'] as String?;
        debugPrint('Using fallback brand: $matchedBrandName ($brandId)');
      }

      if (brandId == null) {
        debugPrint('No brands found in database!');
        return null;
      }

      debugPrint(
        'Final brand match: $matchedBrandName ($brandId) for "$brandName"',
      );

      // Generate order number
      final now = DateTime.now();
      final orderNumber =
          '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}${now.millisecondsSinceEpoch % 10000}';

      // Parse order date
      DateTime createdAt = now;
      if (orderData['createdAt'] != null) {
        createdAt = DateTime.tryParse(orderData['createdAt'].toString()) ?? now;
      }

      // Calculate total from items if not provided
      double totalPrice = (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
      if (totalPrice == 0 && orderData['orderItems'] is List) {
        for (final item in orderData['orderItems'] as List) {
          if (item is Map) {
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            totalPrice += qty * price;
          }
        }
      }

      // Geocode the delivery address
      double? deliveryLatitude;
      double? deliveryLongitude;

      final customerStreet = orderData['customerStreet']?.toString();
      final customerCity = orderData['customerCity']?.toString();
      final customerPostcode = orderData['customerPostcode']?.toString();

      if (customerStreet != null &&
          customerStreet.isNotEmpty &&
          customerCity != null &&
          customerCity.isNotEmpty) {
        try {
          debugPrint(
            'Geocoding address: $customerStreet, $customerPostcode $customerCity',
          );
          final geocodeResponse = await _supabase.functions.invoke(
            'geocode-address',
            body: {
              'street': customerStreet,
              'city': customerCity,
              'postcode': customerPostcode,
              'country': 'AT',
            },
          );

          if (geocodeResponse.data != null &&
              geocodeResponse.data['latitude'] != null &&
              geocodeResponse.data['longitude'] != null) {
            deliveryLatitude = (geocodeResponse.data['latitude'] as num)
                .toDouble();
            deliveryLongitude = (geocodeResponse.data['longitude'] as num)
                .toDouble();
            debugPrint(
              'Geocoding successful: $deliveryLatitude, $deliveryLongitude',
            );
          } else {
            debugPrint(
              'Geocoding returned no coordinates: ${geocodeResponse.data}',
            );
          }
        } catch (geoError) {
          debugPrint('Geocoding error: $geoError');
        }
      }

      // Insert order (let Supabase auto-generate UUID)
      // Status is 'confirmed' so no manual confirmation needed
      final orderRecord = {
        'order_number': orderNumber,
        'brand_id': brandId,
        'total_price': totalPrice,
        'status': 'confirmed', // Auto-confirmed, no manual confirmation needed
        'created_at': createdAt.toIso8601String(),
        'scanned_date': now.toIso8601String(),
        'payment_method': orderData['paymentMethod']?.toString() ?? 'unknown',
        'order_type_name': orderData['orderTypeName']?.toString(),
        'fulfillment_type':
            orderData['fulfillmentType']?.toString() ?? 'delivery',
        'customer_name': orderData['customerName']?.toString(),
        'customer_street': customerStreet,
        'customer_postcode': customerPostcode,
        'customer_city': customerCity,
        'platform_order_id': orderData['platformOrderId']?.toString(),
        'delivery_fee': (orderData['deliveryFee'] as num?)?.toDouble(),
        'note': orderData['note']?.toString(),
        'delivery_latitude': deliveryLatitude,
        'delivery_longitude': deliveryLongitude,
      };

      debugPrint('Inserting order: $orderRecord');

      String? orderId;
      try {
        final insertedRows = await _supabase
            .from('orders')
            .insert(orderRecord)
            .select('id');
        if (insertedRows.isNotEmpty) {
          orderId = insertedRows[0]['id'] as String?;
        }
        debugPrint('Order inserted successfully: $orderId');
      } catch (orderInsertError) {
        debugPrint('Order insert error: $orderInsertError');
        rethrow;
      }

      if (orderId == null) {
        throw Exception('Failed to get order ID after insert');
      }

      // Insert order items (without menu item matching)
      if (orderData['orderItems'] is List) {
        int itemCount = 0;
        for (final item in orderData['orderItems'] as List) {
          if (item is Map) {
            final itemName =
                item['menuItemName']?.toString() ??
                item['name']?.toString() ??
                'Unknown Item';
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;

            try {
              await _supabase.from('order_items').insert({
                'order_id': orderId,
                'menu_item_name': itemName,
                'quantity': qty,
                'price_at_purchase': price,
                'brand_id': brandId,
              });
              itemCount++;
            } catch (itemError) {
              debugPrint('Order item insert error for "$itemName": $itemError');
              // Continue with other items
            }
          }
        }
        debugPrint('Inserted $itemCount order items');
      }

      debugPrint('Order created directly: $orderId');

      // Return an Order object
      return Order(
        id: orderId,
        orderNumber: orderNumber,
        brandId: brandId,
        brandName: matchedBrandName ?? brandName,
        totalPrice: totalPrice,
        status: 'confirmed',
        createdAt: createdAt,
        paymentMethod: orderData['paymentMethod']?.toString() ?? 'unknown',
        orderTypeName: orderData['orderTypeName']?.toString(),
        fulfillmentType: orderData['fulfillmentType']?.toString() ?? 'delivery',
        customerName: orderData['customerName']?.toString(),
        customerStreet: customerStreet,
        customerPostcode: customerPostcode,
        customerCity: customerCity,
        platformOrderId: orderData['platformOrderId']?.toString(),
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
      );
    } catch (e) {
      debugPrint('Error creating order directly: $e');
      return null;
    }
  }

  /// Show the parsed Gemini data in a beautiful split-view dialog (image left, details right)
  void _showParsedDataDialog(Map<String, dynamic> row, String? imageUrl) {
    final extractedData = row['extracted_data'];
    final scanType = (row['scan_type'] as String?) ?? 'order';
    final isOrder = scanType == 'order';
    final brandOrSupplier = isOrder
        ? (row['brand_name'] as String?)
        : (row['supplier_name'] as String?);
    final createdAtStr = row['created_at'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)
        : null;
    final storagePath = row['storage_path'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use split view for wide screens, stacked for narrow
            final isWide = constraints.maxWidth > 700;

            return Container(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1100 : 600,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOrder
                            ? [Colors.blue[600]!, Colors.blue[400]!]
                            : [Colors.green[600]!, Colors.green[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOrder ? Icons.shopping_bag : Icons.receipt_long,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOrder ? 'Order Details' : 'Purchase Details',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (brandOrSupplier != null)
                                Text(
                                  brandOrSupplier,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (createdAt != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              DateFormat.yMMMd().add_Hm().format(
                                createdAt.toLocal(),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Content - Split View
                  Flexible(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // LEFT: Receipt Image
                              Expanded(
                                flex: 1,
                                child: _buildImagePanel(
                                  row,
                                  storagePath,
                                  imageUrl,
                                ),
                              ),
                              // Divider
                              Container(width: 1, color: Colors.grey[300]),
                              // RIGHT: Details
                              Expanded(
                                flex: 1,
                                child: _buildDetailsPanel(
                                  extractedData,
                                  isOrder,
                                  row,
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                // Image on top for mobile
                                SizedBox(
                                  height: 250,
                                  child: _buildImagePanel(
                                    row,
                                    storagePath,
                                    imageUrl,
                                  ),
                                ),
                                const Divider(height: 1),
                                // Details below
                                _buildDetailsPanel(extractedData, isOrder, row),
                              ],
                            ),
                          ),
                  ),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        // Full Image Button
                        if (imageUrl != null || storagePath != null)
                          OutlinedButton.icon(
                            onPressed: () async {
                              String? url = imageUrl;
                              if (url == null && storagePath != null) {
                                url = await _signedUrlFor(row);
                              }
                              if (url != null && mounted) {
                                Navigator.pop(ctx);
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black87,
                                  builder: (ctx2) => ReceiptViewerDialog(
                                    url: url!,
                                    heroTag: (storagePath ?? row['id'] ?? url)
                                        .toString(),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.fullscreen, size: 18),
                            label: const Text('Full Image'),
                          ),
                        const SizedBox(width: 12),
                        const Spacer(),
                        // Convert to Order Button (if not already converted)
                        if (row['created_order_id'] == null)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _convertToOrder(row);
                            },
                            icon: const Icon(
                              Icons.shopping_cart_checkout,
                              size: 18,
                            ),
                            label: const Text('Convert to Order'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Order Created',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build the image panel for the dialog
  Widget _buildImagePanel(
    Map<String, dynamic> row,
    String? storagePath,
    String? imageUrl,
  ) {
    // Check if it's a PDF - can't display as image
    final path = storagePath ?? row['storage_path'] as String? ?? '';
    final isPdf = path.toLowerCase().endsWith('.pdf');

    if (isPdf) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 80, color: Colors.red[400]),
              const SizedBox(height: 16),
              const Text(
                'PDF Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'PDF preview not available',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              if (imageUrl != null || storagePath != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    // Open PDF in browser or external viewer
                    String? url = imageUrl;
                    url ??= await _signedUrlFor(row);
                    if (url != null) {
                      // Could use url_launcher here, but just show the URL for now
                      debugPrint('PDF URL: $url');
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open PDF'),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey[100],
      child: FutureBuilder<String?>(
        future: imageUrl != null ? Future.value(imageUrl) : _signedUrlFor(row),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final url = snapshot.data;
          if (url == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Image not available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Path: $path',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            );
          }

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (_, error, ___) {
                  debugPrint('Image load error: $error');
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          error.toString().length > 50
                              ? '${error.toString().substring(0, 50)}...'
                              : error.toString(),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build the details panel for the dialog
  Widget _buildDetailsPanel(
    dynamic extractedData,
    bool isOrder,
    Map<String, dynamic> row,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Info Cards
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (extractedData is Map) ...[
                _buildInfoChip(
                  icon: Icons.euro,
                  label: 'Total',
                  value: NumberFormat.currency(symbol: '€').format(
                    (extractedData[isOrder ? 'totalPrice' : 'totalAmount']
                            as num?) ??
                        0,
                  ),
                  color: isOrder ? Colors.blue : Colors.green,
                ),
                if (extractedData['paymentMethod'] != null)
                  _buildInfoChip(
                    icon: Icons.payment,
                    label: 'Payment',
                    value: extractedData['paymentMethod']
                        .toString()
                        .toUpperCase(),
                    color: Colors.purple,
                  ),
                if (extractedData['orderTypeName'] != null)
                  _buildInfoChip(
                    icon: Icons.local_shipping,
                    label: 'Platform',
                    value: extractedData['orderTypeName'].toString(),
                    color: Colors.orange,
                  ),
                if (extractedData['platformOrderId'] != null)
                  _buildInfoChip(
                    icon: Icons.tag,
                    label: 'Platform ID',
                    value: extractedData['platformOrderId'].toString(),
                    color: Colors.indigo,
                  ),
              ],
            ],
          ),

          // Customer Info (for orders)
          if (isOrder && extractedData is Map) ...[
            if (extractedData['customerName'] != null ||
                extractedData['customerStreet'] != null) ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Customer', Icons.person),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (extractedData['customerName'] != null)
                      Text(
                        extractedData['customerName'].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    if (extractedData['customerStreet'] != null)
                      Text(
                        extractedData['customerStreet'].toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    if (extractedData['customerPostcode'] != null ||
                        extractedData['customerCity'] != null)
                      Text(
                        '${extractedData['customerPostcode'] ?? ''} ${extractedData['customerCity'] ?? ''}'
                            .trim(),
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ],

          // Order Items
          if (isOrder &&
              extractedData is Map &&
              extractedData['orderItems'] is List) ...[
            const SizedBox(height: 16),
            _buildSectionTitle(
              'Items (${(extractedData['orderItems'] as List).length})',
              Icons.restaurant_menu,
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (extractedData['orderItems'] as List).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = (extractedData['orderItems'] as List)[index];
                  if (item is! Map) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${item['quantity'] ?? 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['menuItemName']?.toString() ??
                                item['name']?.toString() ??
                                'Unknown Item',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (item['price'] != null)
                          Text(
                            NumberFormat.currency(
                              symbol: '€',
                            ).format((item['price'] as num?) ?? 0),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          // Purchase Items
          if (!isOrder &&
              extractedData is Map &&
              extractedData['items'] is List) ...[
            const SizedBox(height: 16),
            _buildSectionTitle(
              'Items (${(extractedData['items'] as List).length})',
              Icons.inventory,
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (extractedData['items'] as List).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = (extractedData['items'] as List)[index];
                  if (item is! Map) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['raw_name']?.toString() ??
                                    item['name']?.toString() ??
                                    'Unknown Item',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              if (item['quantity'] != null &&
                                  item['unit'] != null)
                                Text(
                                  '${item['quantity']} ${item['unit']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item['total_item_price'] != null)
                          Text(
                            NumberFormat.currency(
                              symbol: '€',
                            ).format((item['total_item_price'] as num?) ?? 0),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          // Fees Section
          if (isOrder && extractedData is Map) _buildFeesSection(extractedData),

          // Raw JSON (collapsible)
          if (extractedData != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Icon(Icons.code, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Raw AI Data',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(extractedData),
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildFeesSection(Map<dynamic, dynamic> extractedData) {
    final fees = <MapEntry<String, double>>[];

    final deliveryFee = (extractedData['deliveryFee'] as num?)?.toDouble();
    if (deliveryFee != null && deliveryFee > 0) {
      fees.add(MapEntry('Delivery Fee', deliveryFee));
    }

    final serviceFee = (extractedData['fixedServiceFee'] as num?)?.toDouble();
    if (serviceFee != null && serviceFee > 0) {
      fees.add(MapEntry('Service Fee', serviceFee));
    }

    final commission = (extractedData['commissionAmount'] as num?)?.toDouble();
    if (commission != null && commission > 0) {
      fees.add(MapEntry('Commission', commission));
    }

    // Note: 'tip' field was renamed to 'note' (string for order notes, not a fee)

    if (fees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Fees & Charges', Icons.attach_money),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            children: fees
                .map(
                  (fee) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fee.key),
                        Text(
                          NumberFormat.currency(symbol: '€').format(fee.value),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Analyze a receipt image as an order using Gemini
  Future<Map<String, dynamic>?> _analyzeReceiptAsOrder(
    String base64Image,
    String mimeType,
  ) async {
    final prompt = '''
Analyze this receipt image and extract order information. Return a valid JSON object.

You MUST identify the brand name. Common brands are: "CRISPY CHICKEN LAB", "DEVILS SMASH BURGER", "THE BOWL SPOT", "TACOTASTIC".
If you cannot identify the exact brand, look for restaurant/brand names on the receipt.

Return this JSON structure (omit fields you cannot find):
{
  "classification": "order",
  "brandName": "string (restaurant/brand name)",
  "orderTypeName": "string (e.g., 'Lieferando', 'Foodora', 'Wolt', 'Uber Eats', 'Takeaway', 'Dine-in')",
  "customerName": "string",
  "customerStreet": "string (full street address)",
  "customerPostcode": "string",
  "customerCity": "string",
  "totalPrice": number,
  "deliveryFee": number,
  "fixedServiceFee": number,
  "commissionAmount": number,
  "note": "string | null (any special instructions or notes from customer)",
  "createdAt": "string (ISO 8601: YYYY-MM-DDTHH:mm:ss)",
  "paymentMethod": "string (cash/online/card/unknown)",
  "platformOrderId": "string (order ID from delivery platform)",
  "fulfillmentType": "string (delivery/pickup)",
  "orderItems": [
    {"menuItemName": "string", "quantity": number, "price": number}
  ]
}

IMPORTANT:
- DO NOT include markdown formatting (no ```json)
- Return ONLY the JSON object
- Ensure all numbers are actual numbers, not strings
- Extract ALL visible order items with their quantities
''';

    for (final model in _geminiModels) {
      try {
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey';

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'inline_data': {'mime_type': mimeType, 'data': base64Image},
                  },
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 4096},
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_NONE',
              },
            ],
          }),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          final text =
              result['candidates']?[0]?['content']?['parts']?[0]?['text'];

          if (text != null) {
            // Clean and parse JSON
            String jsonStr = text
                .toString()
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();

            // Find JSON object boundaries
            final start = jsonStr.indexOf('{');
            final end = jsonStr.lastIndexOf('}');
            if (start != -1 && end != -1 && end > start) {
              jsonStr = jsonStr.substring(start, end + 1);
            }

            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            data['classification'] = 'order'; // Ensure it's marked as order
            return data;
          }
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          // Rate limit or overload - try next model
          continue;
        } else {
          debugPrint(
            'Gemini error ($model): ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('Error with model $model: $e');
        continue;
      }
    }

    return null;
  }

  /// Scan a receipt - opens file picker, uses direct Gemini API (same as Purchase AI Trainer), saves to watcher
  Future<void> _scanReceipt() async {
    try {
      // Open file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        return; // User cancelled
      }

      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;

      setState(() => _isScanning = true);

      // Show scanning progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Scanning $fileName...')),
              ],
            ),
            backgroundColor: Colors.blue[600],
            duration: const Duration(seconds: 30),
          ),
        );
      }

      // Determine MIME type
      String mimeType = 'image/jpeg';
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lowerName.endsWith('.pdf')) {
        mimeType = 'application/pdf';
      }

      // Convert to base64
      final base64Image = base64Encode(fileBytes);

      // Call Gemini directly (same approach as Purchase AI Trainer that works!)
      Map<String, dynamic>? extractedData;
      String? geminiError;

      try {
        extractedData = await _analyzeReceiptWithGemini(base64Image, mimeType);
      } catch (e) {
        geminiError = e.toString();
        debugPrint('Gemini analysis error: $geminiError');
      }

      if (extractedData == null) {
        throw Exception(
          'AI could not analyze this receipt: ${geminiError ?? "No response from API"}',
        );
      }

      if (!mounted) return;

      // Determine scan type
      final classification =
          extractedData['classification']?.toString() ?? 'unknown';
      final isOrder = classification == 'order';
      final scanType = isOrder ? 'order' : 'purchase';

      // Upload image to Supabase storage
      final now = DateTime.now();
      final storagePath =
          '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.millisecondsSinceEpoch}_$fileName';

      await _supabase.storage
          .from('scanned-receipts')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(contentType: mimeType),
          );

      // Save to scanned_receipts table
      await _supabase.from('scanned_receipts').insert({
        'scan_type': scanType,
        'storage_path': storagePath,
        'raw_json': jsonEncode(extractedData),
        'extracted_data': extractedData,
        'brand_name': isOrder ? extractedData['brandName'] : null,
        'supplier_name': !isOrder ? extractedData['supplierName'] : null,
      });

      // Hide the scanning snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Success! Refresh the list
      await _fetchLatest();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt scanned successfully!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Type: ${scanType.toUpperCase()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (isOrder && extractedData['brandName'] != null)
                        Text(
                          'Brand: ${extractedData['brandName']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (!isOrder && extractedData['supplierName'] != null)
                        Text(
                          'Supplier: ${extractedData['supplierName']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        snackbar_utils.showErrorSnackbar(
          context,
          'Scan failed: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  /// Analyze receipt with Gemini (direct API call - same as Purchase AI Trainer)
  Future<Map<String, dynamic>?> _analyzeReceiptWithGemini(
    String base64Image,
    String mimeType,
  ) async {
    final prompt = '''
Analyze this receipt/invoice image and classify it.

FIRST determine if this is:
- "order" - A customer order from a delivery platform (Lieferando, Wolt, Uber Eats, Foodora) or restaurant receipt
- "purchase" - A purchase/invoice from a supplier (Metro, Spar, wholesale)

Then extract the relevant information.

For ORDER receipts, return:
{
  "classification": "order",
  "brandName": "string (restaurant name: CRISPY CHICKEN LAB, DEVILS SMASH BURGER, THE BOWL SPOT, TACOTASTIC, or other)",
  "orderTypeName": "string (Lieferando, Wolt, Uber Eats, etc.)",
  "customerName": "string",
  "customerStreet": "string",
  "customerPostcode": "string",
  "customerCity": "string",
  "totalPrice": number,
  "deliveryFee": number,
  "note": "string | null (any special instructions or notes)",
  "paymentMethod": "string (cash/online/card)",
  "platformOrderId": "string",
  "orderItems": [{"menuItemName": "string", "quantity": number, "price": number}]
}

For PURCHASE receipts, return:
{
  "classification": "purchase",
  "supplierName": "string",
  "totalAmount": number,
  "receiptDate": "string (YYYY-MM-DD)",
  "items": [{"raw_name": "string", "quantity": number, "unit": "string", "unit_price": number, "total_item_price": number}]
}

IMPORTANT:
- Return ONLY valid JSON, no markdown
- Ensure numbers are actual numbers, not strings
- For receiptDate, extract the actual date printed on the document
''';

    final List<String> errors = [];

    for (final model in _geminiModels) {
      try {
        debugPrint('Trying Gemini model: $model');
        debugPrint(
          'Image MIME type: $mimeType, Base64 length: ${base64Image.length}',
        );

        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey';

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'inline_data': {'mime_type': mimeType, 'data': base64Image},
                  },
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 4096},
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_NONE',
              },
            ],
          }),
        );

        debugPrint('Gemini response ($model): ${response.statusCode}');

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          final text =
              result['candidates']?[0]?['content']?['parts']?[0]?['text'];

          if (text != null) {
            debugPrint(
              'Gemini returned text: ${text.toString().substring(0, text.toString().length.clamp(0, 200))}...',
            );

            // Clean and parse JSON
            String jsonStr = text
                .toString()
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();

            // Find JSON object boundaries
            final start = jsonStr.indexOf('{');
            final end = jsonStr.lastIndexOf('}');
            if (start != -1 && end != -1 && end > start) {
              jsonStr = jsonStr.substring(start, end + 1);
            }

            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            debugPrint(
              'Successfully parsed Gemini response: ${data.keys.toList()}',
            );
            return data;
          } else {
            // Check for blocked content or other issues
            final blockReason = result['candidates']?[0]?['finishReason'];
            final safetyRatings = result['candidates']?[0]?['safetyRatings'];
            errors.add(
              '$model: No text returned (finishReason: $blockReason, safety: $safetyRatings)',
            );
            debugPrint(
              'Gemini returned no text. Body: ${response.body.substring(0, response.body.length.clamp(0, 500))}',
            );
          }
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          errors.add(
            '$model: Rate limited/overloaded (${response.statusCode})',
          );
          debugPrint('Model $model overloaded, trying next...');
          continue;
        } else {
          // Parse error message from response
          String errorMsg = 'Status ${response.statusCode}';
          try {
            final errBody = jsonDecode(response.body);
            errorMsg = errBody['error']?['message'] ?? errorMsg;
          } catch (_) {}
          errors.add('$model: $errorMsg');
          debugPrint(
            'Gemini error ($model): ${response.statusCode} - ${response.body}',
          );
          continue;
        }
      } catch (e) {
        errors.add('$model: $e');
        debugPrint('Error with model $model: $e');
        continue;
      }
    }

    // If we got here, all models failed
    throw Exception('All Gemini models failed: ${errors.join("; ")}');
  }

  Widget _buildListItem(Map<String, dynamic> row) {
    final scanType = (row['scan_type'] as String?) ?? 'order';
    final isOrder = scanType == 'order';
    final createdAtStr = row['created_at'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)
        : null;
    final brandOrSupplier = isOrder
        ? (row['brand_name'] as String?)
        : (row['supplier_name'] as String?);

    // Extract raw AI data if available
    final rawJson = row['raw_json'];
    final extractedData = row['extracted_data'];

    return FutureBuilder<String?>(
      future: _signedUrlFor(row),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showParsedDataDialog(row, url),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Time Column
                  if (createdAt != null)
                    SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat.Hm().format(createdAt.toLocal()),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d').format(createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (createdAt != null) const SizedBox(width: 12),

                  // Receipt Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 160,
                      child: url == null
                          ? Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Hero(
                                  tag:
                                      (row['storage_path'] ??
                                              row['id'] ??
                                              row['created_at'] ??
                                              url)
                                          .toString(),
                                  child: Image.network(url, fit: BoxFit.cover),
                                ),
                                // Type indicator overlay
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOrder
                                          ? Colors.blue[600]
                                          : Colors.green[600],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isOrder
                                          ? Icons.shopping_bag
                                          : Icons.receipt_long,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Details Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with type badge and timestamp
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isOrder
                                    ? Colors.blue[600]
                                    : Colors.green[600],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOrder
                                        ? Icons.shopping_bag
                                        : Icons.receipt_long,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOrder ? 'ORDER' : 'PURCHASE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (createdAt != null)
                              Expanded(
                                child: Text(
                                  'Scanned on ${DateFormat.yMMMd().format(createdAt.toLocal())}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Brand/Supplier Name
                        if (brandOrSupplier != null &&
                            brandOrSupplier.isNotEmpty)
                          Text(
                            brandOrSupplier,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),

                        const SizedBox(height: 8),

                        // AI Analysis Section
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AI Analysis',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              FutureBuilder<String>(
                                future: _aiSummaryForRow(row),
                                builder: (context, snap) {
                                  final summary = (snap.data ?? '').trim();
                                  if (summary.isEmpty) {
                                    return const Text(
                                      'No analysis data available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  }
                                  return Text(
                                    summary,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Convert to Order Button (for receipts not yet converted)
                        if (row['created_order_id'] == null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _convertingReceiptId == row['id']?.toString()
                                  ? null
                                  : () => _convertToOrder(row),
                              icon:
                                  _convertingReceiptId == row['id']?.toString()
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.shopping_cart_checkout,
                                      size: 18,
                                    ),
                              label: Text(
                                _convertingReceiptId == row['id']?.toString()
                                    ? 'Converting...'
                                    : 'Convert to Order',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Order Created',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Download receipt
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download_outlined, size: 20),
                              onPressed: () => _downloadReceipt(row),
                              tooltip: 'Download receipt',
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Download',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        // Raw extracted data preview (if available)
                        if (extractedData != null || rawJson != null) ...[
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(
                              left: 12,
                              bottom: 8,
                            ),
                            title: Row(
                              children: [
                                Icon(
                                  Icons.data_object,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Raw AI Data',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: SelectableText(
                                  extractedData?.toString() ??
                                      rawJson?.toString() ??
                                      'No data',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.black87,
                                  ),
                                  maxLines: 5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBulkDownloadDialog(BuildContext context) {
    DateTime? fromDate;
    DateTime? toDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.download, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text('Download Purchase Documents'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a date range to download all purchase receipt documents.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  // From Date
                  Text(
                    'From Date',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            fromDate ??
                            DateTime.now().subtract(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => fromDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            fromDate != null
                                ? DateFormat.yMMMd().format(fromDate!)
                                : 'Select start date',
                            style: TextStyle(
                              color: fromDate != null
                                  ? Colors.black87
                                  : Colors.grey[500],
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // To Date
                  Text(
                    'To Date',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: toDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => toDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            toDate != null
                                ? DateFormat.yMMMd().format(toDate!)
                                : 'Select end date',
                            style: TextStyle(
                              color: toDate != null
                                  ? Colors.black87
                                  : Colors.grey[500],
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preview count
                  if (fromDate != null && toDate != null)
                    FutureBuilder<int>(
                      future: _countPurchasesInRange(fromDate!, toDate!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text(
                            'Counting documents...',
                            style: TextStyle(color: Colors.grey),
                          );
                        }
                        final count = snapshot.data ?? 0;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: Colors.green[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$count purchase document${count == 1 ? '' : 's'} found',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: (fromDate != null && toDate != null)
                    ? () {
                        Navigator.pop(ctx);
                        _downloadPurchaseDocuments(fromDate!, toDate!);
                      }
                    : null,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<int> _countPurchasesInRange(DateTime from, DateTime to) async {
    final toEndOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);

    int count = 0;
    for (final row in _rows) {
      if ((row['scan_type'] as String?) != 'purchase') continue;

      // Try to get receipt date from extracted_data
      DateTime? receiptDate;
      final extractedData = row['extracted_data'];
      if (extractedData is Map && extractedData['receiptDate'] != null) {
        receiptDate = DateTime.tryParse(
          extractedData['receiptDate'].toString(),
        );
      }

      // Fallback to created_at
      receiptDate ??= DateTime.tryParse(row['created_at'] as String? ?? '');

      if (receiptDate != null) {
        final dateOnly = DateTime(
          receiptDate.year,
          receiptDate.month,
          receiptDate.day,
        );
        final fromDateOnly = DateTime(from.year, from.month, from.day);
        final toDateOnly = DateTime(
          toEndOfDay.year,
          toEndOfDay.month,
          toEndOfDay.day,
        );

        if (!dateOnly.isBefore(fromDateOnly) && !dateOnly.isAfter(toDateOnly)) {
          count++;
        }
      }
    }
    return count;
  }

  Future<void> _downloadPurchaseDocuments(DateTime from, DateTime to) async {
    final toEndOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);

    // Filter purchase receipts in range
    final purchasesInRange = <Map<String, dynamic>>[];
    for (final row in _rows) {
      if ((row['scan_type'] as String?) != 'purchase') continue;

      // Try to get receipt date from extracted_data
      DateTime? receiptDate;
      final extractedData = row['extracted_data'];
      if (extractedData is Map && extractedData['receiptDate'] != null) {
        receiptDate = DateTime.tryParse(
          extractedData['receiptDate'].toString(),
        );
      }

      // Fallback to created_at
      receiptDate ??= DateTime.tryParse(row['created_at'] as String? ?? '');

      if (receiptDate != null) {
        final dateOnly = DateTime(
          receiptDate.year,
          receiptDate.month,
          receiptDate.day,
        );
        final fromDateOnly = DateTime(from.year, from.month, from.day);
        final toDateOnly = DateTime(
          toEndOfDay.year,
          toEndOfDay.month,
          toEndOfDay.day,
        );

        if (!dateOnly.isBefore(fromDateOnly) && !dateOnly.isAfter(toDateOnly)) {
          purchasesInRange.add(row);
        }
      }
    }

    if (purchasesInRange.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No purchase documents found in the selected date range',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BulkDownloadProgressDialog(
        purchases: purchasesInRange,
        supabase: _supabase,
        fromDate: from,
        toDate: to,
      ),
    );
  }

  void _openSettingsDialog() async {
    final orderCtrl = TextEditingController(text: _currentOrderPrompt);
    final purchaseCtrl = TextEditingController(text: _currentPurchasePrompt);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini Prompts'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These prompts define the JSON structure Gemini should extract for each receipt type.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Order Prompt',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: orderCtrl,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter Gemini prompt for "order" receipts...',
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 24),
                Text(
                  'Purchase Prompt',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: purchaseCtrl,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter Gemini prompt for "purchase" receipts...',
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                if (_promptError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Note: $_promptError',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await _savePrompts(orderCtrl.text, purchaseCtrl.text);
    }
  }

  Widget _buildFilterChips() {
    final filters = [
      {'value': 'today', 'label': 'Today', 'icon': Icons.today},
      {'value': 'yesterday', 'label': 'Yesterday', 'icon': Icons.history},
      {'value': 'this_week', 'label': 'This Week', 'icon': Icons.date_range},
      {
        'value': 'this_month',
        'label': 'This Month',
        'icon': Icons.calendar_month,
      },
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final isSelected = _filterValue == filter['value'];
        return FilterChip(
          selected: isSelected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filter['icon'] as IconData,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(filter['label'] as String),
            ],
          ),
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _filterValue = filter['value'];
                _processData();
              });
            }
          },
          selectedColor: Colors.indigo[600],
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWebSidebar() {
    final orderCount = _displayList
        .whereType<Map<String, dynamic>>()
        .where((r) => (r['scan_type'] as String?) == 'order')
        .length;
    final purchaseCount = _displayList
        .whereType<Map<String, dynamic>>()
        .where((r) => (r['scan_type'] as String?) == 'purchase')
        .length;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.document_scanner,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Receipt Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: _openSettingsDialog,
                      tooltip: 'Scanner Settings',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildMiniStatCard(
                      'Orders',
                      orderCount.toString(),
                      Colors.blue[300]!,
                    ),
                    const SizedBox(width: 12),
                    _buildMiniStatCard(
                      'Purchases',
                      purchaseCount.toString(),
                      Colors.green[300]!,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter by Date',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFilterChips(),

                        if (_availableDates.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Or select a specific date',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<DateTime>(
                                value: _filterValue is DateTime
                                    ? _filterValue
                                    : null,
                                hint: const Text('Select date...'),
                                isExpanded: true,
                                items: _availableDates
                                    .map(
                                      (date) => DropdownMenuItem<DateTime>(
                                        value: date,
                                        child: Text(
                                          DateFormat.yMMMd().format(date),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _filterValue = newValue;
                                      _processData();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Summary Cards
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Period Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SummaryCard(
                          title: 'Order Total',
                          amount: _orderTotal,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        SummaryCard(
                          title: 'Purchase Total',
                          amount: _purchaseTotal,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Scan Button - Most Prominent
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple[600]!,
                                Colors.deepPurple[400]!,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _isScanning ? null : _scanReceipt,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _isScanning
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.document_scanner,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isScanning
                                            ? 'Scanning...'
                                            : 'Scan Receipt',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (!_isScanning)
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // AI Trainer Button - Prominent
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple[600]!,
                                Colors.purple[400]!,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PurchaseAiTrainerScreen(),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.psychology,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Purchase AI Trainer',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showBulkDownloadDialog(context),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download Purchases'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _fetchLatest,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing ${_displayList.whereType<Map<String, dynamic>>().length} receipts',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToScanOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannedOrderReceiptScreen(),
      ),
    ).then((_) {
      if (mounted) _fetchLatest();
    });
  }

  void _navigateToScanPurchase() {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Document scanning is not available on web. Please use the mobile app.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DocumentScannerScreen(scanType: ScanType.purchase),
      ),
    ).then((_) {
      if (mounted) _fetchLatest();
    });
  }

  Widget _buildWebReceiptGrid() {
    // Get only receipt items (not date headers) for grid
    final receipts = _displayList.whereType<Map<String, dynamic>>().toList();

    if (receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No receipts found for selected period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate grid columns based on width
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1400) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 1100)
          crossAxisCount = 3;
        else if (constraints.maxWidth > 800)
          crossAxisCount = 2;

        return CustomScrollView(
          slivers: [
            // Header with scan buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.grey[700], size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Scanned Receipts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.indigo[200]!),
                      ),
                      child: Text(
                        '${receipts.length} items',
                        style: TextStyle(
                          color: Colors.indigo[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Scan Order Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[600]!, Colors.blue[400]!],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _navigateToScanOrder,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.document_scanner,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Scan Order',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Scan Purchase Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[600]!, Colors.green[400]!],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _navigateToScanPurchase,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Scan Purchase',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Grid of receipts
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85, // Made taller to fit all content
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildWebReceiptCard(receipts[index]),
                  childCount: receipts.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
    );
  }

  Widget _buildWebReceiptCard(Map<String, dynamic> row) {
    final scanType = (row['scan_type'] as String?) ?? 'order';
    final isOrder = scanType == 'order';
    final createdAtStr = row['created_at'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)
        : null;
    final brandOrSupplier = isOrder
        ? (row['brand_name'] as String?)
        : (row['supplier_name'] as String?);
    final extractedData = row['extracted_data'];

    return FutureBuilder<String?>(
      future: _signedUrlFor(row),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showParsedDataDialog(row, url),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image section
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url != null)
                        Hero(
                          tag:
                              (row['storage_path'] ??
                                      row['id'] ??
                                      row['created_at'] ??
                                      url)
                                  .toString(),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      // Type badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isOrder
                                ? Colors.blue[600]
                                : Colors.green[600],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOrder
                                    ? Icons.shopping_bag
                                    : Icons.receipt_long,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOrder ? 'ORDER' : 'PURCHASE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Time badge
                      if (createdAt != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              DateFormat.Hm().format(createdAt.toLocal()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Info section
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brandOrSupplier ??
                              (isOrder ? 'Unknown Brand' : 'Unknown Supplier'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (createdAt != null)
                          Text(
                            DateFormat.yMMMd().format(createdAt.toLocal()),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        const Spacer(),
                        // Amount if available
                        if (extractedData is Map) ...[
                          Text(
                            isOrder
                                ? 'Total: ${NumberFormat.currency(symbol: '€').format((extractedData['totalPrice'] as num?) ?? 0)}'
                                : 'Total: ${NumberFormat.currency(symbol: '€').format((extractedData['totalAmount'] as num?) ?? 0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isOrder
                                  ? Colors.blue[700]
                                  : Colors.green[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                        // Convert to Order button for web grid
                        if (row['created_order_id'] == null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _convertingReceiptId == row['id']?.toString()
                                  ? null
                                  : () => _convertToOrder(row),
                              icon:
                                  _convertingReceiptId == row['id']?.toString()
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.shopping_cart_checkout,
                                      size: 14,
                                    ),
                              label: Text(
                                _convertingReceiptId == row['id']?.toString()
                                    ? 'Converting...'
                                    : 'To Order',
                                style: const TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[700],
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Order Created',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Download button for web grid
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _downloadReceipt(row),
                            icon: const Icon(Icons.download_outlined, size: 14),
                            label: const Text('Download', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              foregroundColor: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchLatest();
      },
      child: Column(
        children: [
          // Top bar with title and settings button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                const Text(
                  'Scanned Receipts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Scanner settings',
                  child: IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _openSettingsDialog,
                  ),
                ),
              ],
            ),
          ),

          // --- Summary Cards ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Order Total',
                    amount: _orderTotal,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Purchase Total',
                    amount: _purchaseTotal,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // --- Bulk Download Button for Purchases ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ElevatedButton.icon(
              onPressed: () => _showBulkDownloadDialog(context),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download Purchase Documents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // --- Filter Dropdown ---
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<dynamic>(
                      value: _filterValue,
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem(value: 'today', child: Text('Today')),
                        const DropdownMenuItem(
                          value: 'yesterday',
                          child: Text('Yesterday'),
                        ),
                        const DropdownMenuItem(
                          value: 'this_week',
                          child: Text('This Week'),
                        ),
                        const DropdownMenuItem(
                          value: 'this_month',
                          child: Text('This Month'),
                        ),
                        if (_availableDates.isNotEmpty)
                          const DropdownMenuItem<dynamic>(child: Divider()),
                        ..._availableDates.map(
                          (date) => DropdownMenuItem<DateTime>(
                            value: date,
                            child: Text(DateFormat.yMMMd().format(date)),
                          ),
                        ),
                      ],
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _filterValue = newValue;
                            _processData();
                          });
                        }
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey),
                  onPressed: _fetchLatest,
                  tooltip: 'Refresh Receipts',
                ),
              ],
            ),
          ),

          // --- Grouped List View ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: _displayList.length,
              itemBuilder: (context, index) {
                final item = _displayList[index];
                if (item is DateTime) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      _formatDateHeader(item),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  );
                } else if (item is Map<String, dynamic>) {
                  return _buildListItem(item);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _fetchLatest, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No scanned receipts yet.'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await _fetchLatest();
                await _loadPrompt();
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use web layout for wider screens
        if (constraints.maxWidth > 800) {
          return Stack(
            children: [
              Row(
                children: [
                  _buildWebSidebar(),
                  Expanded(
                    child: Container(
                      color: Colors.grey[50],
                      child: _buildWebReceiptGrid(),
                    ),
                  ),
                ],
              ),
              // Floating scan button for web
              Positioned(right: 24, bottom: 24, child: _buildScanFAB()),
            ],
          );
        } else {
          return Stack(
            children: [
              _buildMobileLayout(),
              // Floating scan button for mobile
              Positioned(right: 16, bottom: 16, child: _buildScanFAB()),
            ],
          );
        }
      },
    );
  }

  Widget _buildScanFAB() {
    return FloatingActionButton.extended(
      heroTag: 'receipt_watcher_scan_fab',
      onPressed: _isScanning ? null : _scanReceipt,
      backgroundColor: _isScanning ? Colors.grey : Colors.deepPurple,
      foregroundColor: Colors.white,
      icon: _isScanning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.document_scanner),
      label: Text(_isScanning ? 'Scanning...' : 'Scan Receipt'),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(symbol: '€').format(amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkDownloadProgressDialog extends StatefulWidget {
  final List<Map<String, dynamic>> purchases;
  final SupabaseClient supabase;
  final DateTime fromDate;
  final DateTime toDate;

  const _BulkDownloadProgressDialog({
    required this.purchases,
    required this.supabase,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<_BulkDownloadProgressDialog> createState() =>
      _BulkDownloadProgressDialogState();
}

class _BulkDownloadProgressDialogState
    extends State<_BulkDownloadProgressDialog> {
  int _currentIndex = 0;
  int _successCount = 0;
  int _failCount = 0;
  bool _isComplete = false;
  bool _isCancelled = false;
  String _statusMessage = 'Preparing download...';
  String? _errorMessage;
  String? _downloadedFilePath;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final archive = Archive();
      final dateFormatter = DateFormat('yyyy-MM-dd');

      for (int i = 0; i < widget.purchases.length && !_isCancelled; i++) {
        if (!mounted) return;

        setState(() {
          _currentIndex = i + 1;
          _statusMessage =
              'Downloading ${i + 1} of ${widget.purchases.length}...';
        });

        final row = widget.purchases[i];
        final storagePath = row['storage_path'] as String?;

        if (storagePath == null || storagePath.isEmpty) {
          _failCount++;
          continue;
        }

        try {
          // Get signed URL
          final signedUrl = await widget.supabase.storage
              .from('scanned-receipts')
              .createSignedUrl(storagePath, 120);

          // Download the image
          final response = await http.get(Uri.parse(signedUrl));

          if (response.statusCode == 200) {
            // Create a meaningful filename
            final extractedData = row['extracted_data'];
            String supplierName = 'unknown';
            String receiptDateStr = '';

            if (extractedData is Map) {
              supplierName =
                  (extractedData['supplierName'] as String?) ?? 'unknown';
              final receiptDate = extractedData['receiptDate'] != null
                  ? DateTime.tryParse(extractedData['receiptDate'].toString())
                  : null;
              if (receiptDate != null) {
                receiptDateStr = dateFormatter.format(receiptDate);
              }
            }

            // Fallback to created_at for date
            if (receiptDateStr.isEmpty) {
              final createdAt = DateTime.tryParse(
                row['created_at'] as String? ?? '',
              );
              if (createdAt != null) {
                receiptDateStr = dateFormatter.format(createdAt);
              }
            }

            // Sanitize supplier name for filename
            supplierName = supplierName
                .replaceAll(RegExp(r'[^\w\s-]'), '')
                .replaceAll(RegExp(r'\s+'), '_')
                .toLowerCase();

            final fileName = '${receiptDateStr}_${supplierName}_${i + 1}.jpg';

            // Add to archive
            archive.addFile(
              ArchiveFile(
                fileName,
                response.bodyBytes.length,
                response.bodyBytes,
              ),
            );
            _successCount++;
          } else {
            _failCount++;
          }
        } catch (e) {
          _failCount++;
          debugPrint('Failed to download: $e');
        }
      }

      if (_isCancelled) {
        if (mounted) Navigator.pop(context);
        return;
      }

      if (_successCount == 0) {
        setState(() {
          _isComplete = true;
          _errorMessage = 'No documents could be downloaded';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Creating ZIP file...';
      });

      // Encode the archive
      final zipData = ZipEncoder().encode(archive);

      // Save the ZIP file
      final fromStr = DateFormat('yyyy-MM-dd').format(widget.fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(widget.toDate);
      final zipFileName = 'purchases_${fromStr}_to_$toStr.zip';

      if (kIsWeb) {
        // For web, trigger download via browser
        // ignore: avoid_web_libraries_in_flutter
        await _downloadForWeb(Uint8List.fromList(zipData), zipFileName);
      } else {
        // For mobile/desktop, save to documents directory and share
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$zipFileName';
        final file = File(filePath);
        await file.writeAsBytes(zipData);
        _downloadedFilePath = filePath;
      }

      setState(() {
        _isComplete = true;
        _statusMessage = 'Download complete!';
      });
    } catch (e) {
      setState(() {
        _isComplete = true;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _downloadForWeb(Uint8List bytes, String fileName) async {
    // For web platform, we'd use dart:html or universal_html
    // For now, we'll show a message since this is primarily a mobile app
    setState(() {
      _statusMessage = 'ZIP file ready with $_successCount documents';
    });
  }

  void _shareFile() async {
    if (_downloadedFilePath != null) {
      await Share.shareXFiles(
        [XFile(_downloadedFilePath!)],
        text:
            'Purchase documents from ${DateFormat.yMMMd().format(widget.fromDate)} to ${DateFormat.yMMMd().format(widget.toDate)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (!_isComplete)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_errorMessage != null)
            const Icon(Icons.error_outline, color: Colors.red)
          else
            Icon(Icons.check_circle, color: Colors.green[600]),
          const SizedBox(width: 12),
          Text(_isComplete ? 'Download Complete' : 'Downloading...'),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isComplete) ...[
              LinearProgressIndicator(
                value: widget.purchases.isEmpty
                    ? 0
                    : _currentIndex / widget.purchases.length,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              _statusMessage,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _errorMessage != null ? Colors.red : Colors.black87,
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],

            if (_isComplete && _errorMessage == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check, color: Colors.green[700], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '$_successCount document${_successCount == 1 ? '' : 's'} downloaded',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    if (_failCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$_failCount document${_failCount == 1 ? '' : 's'} failed',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (!_isComplete) ...[
              const SizedBox(height: 12),
              Text(
                '$_currentIndex of ${widget.purchases.length} • $_successCount downloaded, $_failCount failed',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isComplete)
          TextButton(
            onPressed: () {
              _isCancelled = true;
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        if (_isComplete) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (_downloadedFilePath != null && !kIsWeb)
            FilledButton.icon(
              onPressed: _shareFile,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share ZIP'),
            ),
        ],
      ],
    );
  }
}
