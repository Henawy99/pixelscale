import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:intl/intl.dart'; // For date formatting
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/widgets/category_card.dart';
import 'package:restaurantadmin/screens/category_items_screen.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Temporarily disabled for iOS build

import 'package:restaurantadmin/screens/document_scanner_screen.dart';
import 'package:restaurantadmin/screens/manual_receipt_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:restaurantadmin/screens/deleted_receipts_screen.dart';
import 'package:restaurantadmin/screens/inventory_value_history_screen.dart';
import 'package:restaurantadmin/screens/inventory_statistics_screen.dart';
import 'package:restaurantadmin/screens/inventory_checker_screen.dart';
import 'package:restaurantadmin/models/scan_type.dart';
import 'package:restaurantadmin/screens/purchase_review_dialog.dart';

import 'package:restaurantadmin/screens/suppliers_screen.dart';

class ReceiptDisplayItem {
  final String receiptId;
  final DateTime createdAt;
  final String? wholesalerName;
  final double? totalAmount;
  final String? receiptImageUrl;
  final int itemCount;

  ReceiptDisplayItem({
    required this.receiptId,
    required this.createdAt,
    this.wholesalerName,
    this.totalAmount,
    this.receiptImageUrl,
    required this.itemCount,
  });
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _categoryCardData = [
    {
      'name': 'DRINKS',
      'imageUrl': 'assets/categories/drinks.jpg',
      'id': 'DRINKS',
      'icon': Icons.local_drink_outlined,
      'color': Colors.blue.shade600,
    },
    {
      'name': 'MEAT',
      'imageUrl': 'assets/categories/meatandchicken .jpg',
      'id': 'MEAT',
      'icon': Icons.kebab_dining_outlined,
      'color': Colors.red.shade600,
    },
    {
      'name': 'BREAD',
      'imageUrl': 'assets/categories/burgerbuns.jpg',
      'id': 'BREAD',
      'icon': Icons.bakery_dining_outlined,
      'color': Colors.orange.shade700,
    },
    {
      'name': 'FRUITS AND VEGETABLES',
      'imageUrl': 'assets/categories/fruitsandvegteables .jpeg',
      'id': 'FRUITS_AND_VEGETABLES',
      'icon': Icons.eco_outlined,
      'color': Colors.green.shade600,
    },
    {
      'name': 'SAUCES',
      'imageUrl': 'assets/categories/sauces.jpg',
      'id': 'SAUCES',
      'icon': Icons.blender_outlined,
      'color': Colors.brown.shade600,
    },
    {
      'name': 'PACKAGING',
      'imageUrl': 'assets/categories/packaging.png',
      'id': 'PACKAGING',
      'icon': Icons.inventory_2_outlined,
      'color': Colors.grey.shade700,
    },
    {
      'name': 'FINGERFOOD',
      'imageUrl': 'assets/categories/fingerfood.png',
      'id': 'FINGERFOOD',
      'icon': Icons.fastfood_outlined,
      'color': Colors.purple.shade600,
    },
    {
      'name': 'DESSERTS',
      'imageUrl': 'assets/categories/desserts.jpg',
      'id': 'DESSERTS',
      'icon': Icons.cake_outlined,
      'color': Colors.pink.shade400,
    },
  ];

  List<ReceiptDisplayItem> _receiptDisplayItems = [];
  bool _isLoadingLogs = true;

  double? _totalInventoryValue;
  bool _isCalculatingValue = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  RealtimeChannel? _purchasesInsertChannel;
  final Set<String> _recentOpenedPurchaseIds = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _setupRealtimeSubscriptions();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchReceiptLogs(forceRefresh: false);
    await _calculateTotalInventoryValue();
    if (mounted) _animationController.forward();
  }

  void _setupRealtimeSubscriptions() {
    // Use Postgres INSERT listener to avoid duplicate events/popups
    _purchasesInsertChannel = Supabase.instance.client
        .channel('purchases-insert-listener')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'purchases',
          callback: (payload) async {
            if (!mounted) return;
            final newRec = payload.newRecord;
            final purchaseId = newRec['id'] as String?;
            if (purchaseId != null &&
                !_recentOpenedPurchaseIds.contains(purchaseId)) {
              _recentOpenedPurchaseIds.add(purchaseId);
              await Future.delayed(const Duration(milliseconds: 300));
              if (!mounted) return;
              await _openPurchaseReviewFor(purchaseId);
              if (mounted) {
                _fetchReceiptLogs(forceRefresh: true);
                _calculateTotalInventoryValue();
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _openPurchaseReviewFor(String purchaseId) async {
    try {
      final supa = Supabase.instance.client;
      final header = await supa
          .from('purchases')
          .select('supplier_name, receipt_date, total_amount')
          .eq('id', purchaseId)
          .maybeSingle();

      // Poll for purchase_items in case the Edge Function inserts them after the header
      List<dynamic> items = [];
      for (int i = 0; i < 7; i++) {
        final resp = await supa
            .from('purchase_items')
            .select(
              'id, raw_name, brand_name, item_number, quantity, unit, unit_price, total_item_price, purchase_catalog_item_id(name, material_id, material_id(name, unit_of_measure), base_unit, conversion_ratio)',
            )
            .eq('purchase_id', purchaseId);
        if (resp.isNotEmpty) {
          items = resp;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final wholesalerName = header?['supplier_name'] as String?;
      final dateStr = header?['receipt_date'] as String?;
      final totalAmount = (header?['total_amount'] is num)
          ? (header!['total_amount'] as num).toDouble()
          : null;
      final receiptDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

      final List<PurchaseLine> lines = [];
      for (final row in items) {
        final pci = row['purchase_catalog_item_id'] as Map<String, dynamic>?;
        final mat = pci != null
            ? pci['material_id'] as Map<String, dynamic>?
            : null;
        lines.add(
          PurchaseLine(
            purchaseItemId: row['id'] as String?,
            rawName: (row['raw_name'] ?? '') as String,
            brandName: row['brand_name'] as String?,
            itemNumber: row['item_number'] as String?,
            quantity: (row['quantity'] is num)
                ? (row['quantity'] as num).toDouble()
                : 0.0,
            unit: (row['unit'] ?? '') as String,
            unitPrice: (row['unit_price'] is num)
                ? (row['unit_price'] as num).toDouble()
                : null,
            totalItemPrice: (row['total_item_price'] is num)
                ? (row['total_item_price'] as num).toDouble()
                : null,
            materialId: (mat != null) ? mat['id'] as String? : null,
            materialName: (mat != null) ? mat['name'] as String? : null,
            baseUnit: (pci != null)
                ? (pci['base_unit'] as String?) ??
                      (mat != null ? mat['unit_of_measure'] as String? : null)
                : null,
            conversionRatio: (pci != null && pci['conversion_ratio'] is num)
                ? (pci['conversion_ratio'] as num).toDouble()
                : 1.0,
          ),
        );
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PurchaseReviewDialog(
            wholesalerName: wholesalerName,
            receiptDate: receiptDate,
            totalAmount: totalAmount,
            lines: lines,
            receiptImageBytes: null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open purchase: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    try {
      _purchasesInsertChannel?.unsubscribe();
    } catch (_) {}
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchReceiptLogs({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingLogs = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('purchases')
          .select(
            'id, created_at, supplier_name, total_amount, receipt_date, purchase_items(count)',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      final List<ReceiptDisplayItem> newLogs = (response as List).map((data) {
        DateTime displayDate = data['receipt_date'] != null
            ? DateTime.parse(data['receipt_date'] as String)
            : DateTime.parse(data['created_at'] as String);
        final pic = data['purchase_items'] as List<dynamic>?;
        final count = (pic != null && pic.isNotEmpty)
            ? (pic[0]['count'] as int? ?? 0)
            : 0;
        return ReceiptDisplayItem(
          receiptId: data['id'] as String,
          createdAt: displayDate,
          wholesalerName: data['supplier_name'] as String?,
          totalAmount: (data['total_amount'] as num?)?.toDouble(),
          receiptImageUrl: null,
          itemCount: count,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _receiptDisplayItems = newLogs;
        });
      }
    } catch (e) {
      debugPrint("Error fetching purchases: $e");
      if (mounted) _showErrorSnackBar('Error fetching purchases: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLogs = false;
        });
      }
    }
  }

  Future<void> _calculateTotalInventoryValue() async {
    if (mounted) setState(() => _isCalculatingValue = true);
    try {
      final materialsResponse = await Supabase.instance.client
          .from('material')
          .select('current_quantity, average_unit_cost');
      if (!mounted) return;
      double currentTotalValue = 0.0;
      for (var materialData in (materialsResponse as List)) {
        final material = materialData as Map<String, dynamic>;
        final double currentQuantity =
            (material['current_quantity'] as num?)?.toDouble() ?? 0.0;
        final double? averageUnitCost = (material['average_unit_cost'] as num?)
            ?.toDouble();
        if (currentQuantity > 0 &&
            averageUnitCost != null &&
            averageUnitCost > 0) {
          currentTotalValue += currentQuantity * averageUnitCost;
        }
      }
      if (mounted) setState(() => _totalInventoryValue = currentTotalValue);
    } catch (e) {
      print("Error calculating total inventory value: $e");
      if (mounted) _showErrorSnackBar('Error calculating inventory value: $e');
    } finally {
      if (mounted) setState(() => _isCalculatingValue = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: '📋 COPY',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Error copied to clipboard'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
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

  Future<void> _scanDocument() async {
    if (kIsWeb) {
      _showErrorSnackBar('Document scanning is not available on web.');
      return;
    }
    final String? imagePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DocumentScannerScreen(scanType: ScanType.purchase),
      ),
    );
    if (!mounted || imagePath == null) return;

    // Temporarily disable OCR for iOS build
    _showErrorSnackBar('OCR functionality is temporarily disabled.');
    return;

    // The following OCR code is temporarily disabled.
    // final inputImage = InputImage.fromFilePath(imagePath);
    // final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    // try {
    //   final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    //   await textRecognizer.close();
    //   if (!mounted || recognizedText.text.isEmpty) {
    //     if (mounted) _showErrorSnackBar('OCR: No text found.');
    //     return;
    //   }
    //   showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: const Padding(padding: EdgeInsets.all(24.0), child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Processing OCR Data...")]))));
    //   Map<String, String> materialHints = {};
    //   try {
    //     final List<Map<String, dynamic>> response = await Supabase.instance.client.from('material').select('name, gemini_info').not('gemini_info', 'is', null).neq('gemini_info', '');
    //     for (var record in response) {
    //       if (record['name'] != null && record['gemini_info'] != null && (record['gemini_info'] as String).isNotEmpty) {
    //         materialHints[record['name'] as String] = record['gemini_info'] as String;
    //       }
    //     }
    //   } catch (e) { print("Error fetching material hints for scan: $e"); }
    //   final GeminiService geminiService = GeminiService();
    //   // TODO: The method 'processReceiptText' was called, but 'processReceiptTextWithGemini' is available.
    //   // This inventory scanning feature might need its own dedicated Gemini service method or an update to use the new one if appropriate.
    //   // Temporarily commenting out to resolve the build error and focus on order scanning.
    //   // final String? geminiJsonResponse = await geminiService.processReceiptText(recognizedText.text, materialHints: materialHints.isNotEmpty ? materialHints : null);
    //   String? geminiJsonResponse; // Placeholder
    //   if (mounted) Navigator.of(context).pop();
    //   if (geminiJsonResponse != null) {
    //     if (!mounted) return;
    //     final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => ReceiptReviewScreen(geminiResponseJson: geminiJsonResponse)));
    //     if (result == true && mounted) {
    //       _fetchReceiptLogs(forceRefresh: true);
    //       _showSuccessSnackBar('Receipt processed successfully!');
    //     }
    //   } else {
    //     if (!mounted) return;
    //     // Ensure recognizedText is available if this block is ever re-enabled
    //     // await showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('OCR (Gemini Failed)'), content: SingleChildScrollView(child: Text(recognizedText.text)), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
    //     await showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('OCR (Gemini Failed)'), content: SingleChildScrollView(child: Text("OCR processing failed or no text found.")), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
    //   }
    // } catch (e) {
    //   if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop(); // Ensure loading dialog is closed
    //   if (mounted) _showErrorSnackBar('Scan Error: $e');
    //   print("Scan/OCR/Gemini Error in InventoryScreen: $e");
    // }
  }

  Widget _buildInventoryValueCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Reduced bottom margin
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InventoryValueHistoryScreen(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ), // Adjusted padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: _isCalculatingValue
                          ? null
                          : _calculateTotalInventoryValue,
                      tooltip: 'Recalculate Value',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Total Inventory Value',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _isCalculatingValue
                    ? const SizedBox(
                        height: 28,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _totalInventoryValue != null
                            ? '€${_totalInventoryValue!.toStringAsFixed(2)}'
                            : '€0.00',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                const SizedBox(height: 4),
                const Text(
                  'Tap to view history',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryActionsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SuppliersScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.store_mall_directory,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suppliers & Purchase Items',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage suppliers and their catalog items',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGridTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), // Adjusted padding
      child: Text(
        'Browse Categories',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildReceiptList() {
    if (_isLoadingLogs && _receiptDisplayItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_receiptDisplayItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 50,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No purchase receipts found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add purchase receipts using the buttons above.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchReceiptLogs(forceRefresh: true),
      color: Theme.of(context).primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _receiptDisplayItems.length,
        itemBuilder: (context, index) {
          final receiptItem = _receiptDisplayItems[index];
          return Card(
            elevation: 1.5,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                try {
                  final supa = Supabase.instance.client;
                  final header = await supa
                      .from('purchases')
                      .select('supplier_name, receipt_date, total_amount')
                      .eq('id', receiptItem.receiptId)
                      .maybeSingle();
                  final items = await supa
                      .from('purchase_items')
                      .select(
                        'id, raw_name, brand_name, item_number, quantity, unit, unit_price, total_item_price, purchase_catalog_item_id(name, material_id, material_id(name, unit_of_measure), base_unit, conversion_ratio)',
                      )
                      .eq('purchase_id', receiptItem.receiptId);

                  final wholesaler = header?['supplier_name'] as String?;
                  final dateStr = header?['receipt_date'] as String?;
                  final totalAmt = (header?['total_amount'] is num)
                      ? (header!['total_amount'] as num).toDouble()
                      : null;
                  final dt = dateStr != null
                      ? DateTime.tryParse(dateStr)
                      : null;

                  final List<PurchaseLine> lines = [];
                  for (final row in (items as List)) {
                    final pci =
                        row['purchase_catalog_item_id']
                            as Map<String, dynamic>?;
                    final mat = pci != null
                        ? pci['material_id'] as Map<String, dynamic>?
                        : null;
                    lines.add(
                      PurchaseLine(
                        purchaseItemId: row['id'] as String?,
                        rawName: (row['raw_name'] ?? '') as String,
                        brandName: row['brand_name'] as String?,
                        itemNumber: row['item_number'] as String?,
                        quantity: (row['quantity'] is num)
                            ? (row['quantity'] as num).toDouble()
                            : 0.0,
                        unit: (row['unit'] ?? '') as String,
                        unitPrice: (row['unit_price'] is num)
                            ? (row['unit_price'] as num).toDouble()
                            : null,
                        totalItemPrice: (row['total_item_price'] is num)
                            ? (row['total_item_price'] as num).toDouble()
                            : null,
                        materialId: (mat != null) ? mat['id'] as String? : null,
                        materialName: (mat != null)
                            ? mat['name'] as String?
                            : null,
                        baseUnit: (pci != null)
                            ? (pci['base_unit'] as String?) ??
                                  (mat != null
                                      ? mat['unit_of_measure'] as String?
                                      : null)
                            : null,
                        conversionRatio:
                            (pci != null && pci['conversion_ratio'] is num)
                            ? (pci['conversion_ratio'] as num).toDouble()
                            : 1.0,
                      ),
                    );
                  }

                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      fullscreenDialog: false,
                      builder: (ctx) => PurchaseReviewDialog(
                        wholesalerName: wholesaler,
                        receiptDate: dt,
                        totalAmount: totalAmt,
                        lines: lines,
                        receiptImageBytes: null,
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  _showErrorSnackBar('Error loading purchase: $e');
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        receiptItem.receiptImageUrl != null
                            ? Icons.image_search_outlined
                            : Icons.receipt_long,
                        color: Colors.grey[700],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receiptItem.wholesalerName?.isNotEmpty ?? false
                                ? receiptItem.wholesalerName!
                                : 'Purchase Receipt - ${DateFormat('dd MMM').format(receiptItem.createdAt)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${receiptItem.itemCount} items • ${DateFormat('MMM d, yyyy').format(receiptItem.createdAt)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (receiptItem.totalAmount != null)
                      Text(
                        '€${receiptItem.totalAmount!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReceiptHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      color: Colors.grey[150], // Match overall background
      child: Row(
        children: [
          Icon(Icons.history_edu_outlined, color: Colors.grey[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recent Purchase Receipts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebar() {
    return Container(
      width: 260,
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
          // Header with inventory value
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[700]!, Colors.green[500]!],
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
                      Icons.inventory_2,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Inventory',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: _isCalculatingValue
                          ? null
                          : _calculateTotalInventoryValue,
                      tooltip: 'Recalculate Value',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Total Value',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _isCalculatingValue
                    ? const SizedBox(
                        height: 32,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _totalInventoryValue != null
                            ? '€${_totalInventoryValue!.toStringAsFixed(2)}'
                            : '€0.00',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InventoryValueHistoryScreen(),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        'View history',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Quick actions - Suppliers only
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Main Suppliers Card - Prominent
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SuppliersScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.store_mall_directory,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Suppliers',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Manage suppliers & items',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white.withOpacity(0.7),
                                size: 16,
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
        ],
      ),
    );
  }

  Widget _buildWebMainContent() {
    return Container(
      color: Colors.grey[100],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top action bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.dashboard, color: Colors.indigo[600], size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Inventory Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Quick action buttons
                  _buildHeaderActionButton(
                    'Manual Receipt',
                    Icons.add_circle_outline,
                    Colors.orange,
                    () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManualReceiptScreen(),
                        ),
                      );
                      if (result == true && mounted) {
                        _fetchReceiptLogs(forceRefresh: true);
                        _calculateTotalInventoryValue();
                        _showSuccessSnackBar(
                          'Manual receipt added successfully!',
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._buildWebActionButtons(),
                ],
              ),
            ),

            // Categories Section - Large and Prominent
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, color: Colors.grey[700], size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Browse Categories',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Responsive grid columns
                      int crossAxisCount = 4;
                      if (constraints.maxWidth > 1400) {
                        crossAxisCount = 4;
                      } else if (constraints.maxWidth > 1000)
                        crossAxisCount = 4;
                      else if (constraints.maxWidth > 700)
                        crossAxisCount = 3;
                      else
                        crossAxisCount = 2;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: _categoryCardData.length,
                        itemBuilder: (context, index) {
                          final category = _categoryCardData[index];
                          return _buildLargeCategoryCard(category);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // Receipts list header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.history_edu, color: Colors.grey[700], size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Recent Purchase Receipts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo[200]!),
                    ),
                    child: Text(
                      '${_receiptDisplayItems.length} receipts',
                      style: TextStyle(
                        color: Colors.indigo[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _fetchReceiptLogs(forceRefresh: true),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

            // Receipts grid (limited height with scrollable content)
            SizedBox(height: 400, child: _buildWebReceiptGrid()),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton(
    String label,
    IconData icon,
    MaterialColor color,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color[600]!, color[400]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
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
    );
  }

  Widget _buildLargeCategoryCard(Map<String, dynamic> category) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CategoryItemsScreen(categoryName: category['name'] as String),
            ),
          );
          if (mounted) {
            _fetchReceiptLogs(forceRefresh: true);
            _calculateTotalInventoryValue();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.asset(
              category['imageUrl'] as String,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: (category['color'] as Color? ?? Colors.grey).withOpacity(
                  0.2,
                ),
                child: Icon(
                  category['icon'] as IconData? ?? Icons.category,
                  color: category['color'] as Color? ?? Colors.grey,
                  size: 60,
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            // Category name and icon
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category['icon'] as IconData? ?? Icons.category,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    category['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Hover effect indicator
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWebActionButtons() {
    return [
      _buildHeaderButton(
        'Value History',
        Icons.trending_up,
        Colors.teal,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const InventoryValueHistoryScreen(),
          ),
        ),
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildHeaderButton(
    String label,
    IconData icon,
    MaterialColor color,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color[600]!, color[400]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
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
    );
  }

  Widget _buildWebReceiptGrid() {
    if (_isLoadingLogs && _receiptDisplayItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_receiptDisplayItems.isEmpty) {
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
              'No purchase receipts found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add purchase receipts using the buttons above.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1400) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 1100)
          crossAxisCount = 3;
        else if (constraints.maxWidth > 800)
          crossAxisCount = 2;

        return RefreshIndicator(
          onRefresh: () => _fetchReceiptLogs(forceRefresh: true),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.0,
            ),
            itemCount: _receiptDisplayItems.length,
            itemBuilder: (context, index) =>
                _buildWebReceiptCard(_receiptDisplayItems[index]),
          ),
        );
      },
    );
  }

  Widget _buildWebReceiptCard(ReceiptDisplayItem receiptItem) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          try {
            final supa = Supabase.instance.client;
            final header = await supa
                .from('purchases')
                .select('supplier_name, receipt_date, total_amount')
                .eq('id', receiptItem.receiptId)
                .maybeSingle();
            final items = await supa
                .from('purchase_items')
                .select(
                  'id, raw_name, brand_name, item_number, quantity, unit, unit_price, total_item_price, purchase_catalog_item_id(name, material_id, material_id(name, unit_of_measure), base_unit, conversion_ratio)',
                )
                .eq('purchase_id', receiptItem.receiptId);

            final wholesaler = header?['supplier_name'] as String?;
            final dateStr = header?['receipt_date'] as String?;
            final totalAmt = (header?['total_amount'] is num)
                ? (header!['total_amount'] as num).toDouble()
                : null;
            final dt = dateStr != null ? DateTime.tryParse(dateStr) : null;

            final List<PurchaseLine> lines = [];
            for (final row in (items as List)) {
              final pci =
                  row['purchase_catalog_item_id'] as Map<String, dynamic>?;
              final mat = pci != null
                  ? pci['material_id'] as Map<String, dynamic>?
                  : null;
              lines.add(
                PurchaseLine(
                  purchaseItemId: row['id'] as String?,
                  rawName: (row['raw_name'] ?? '') as String,
                  brandName: row['brand_name'] as String?,
                  itemNumber: row['item_number'] as String?,
                  quantity: (row['quantity'] is num)
                      ? (row['quantity'] as num).toDouble()
                      : 0.0,
                  unit: (row['unit'] ?? '') as String,
                  unitPrice: (row['unit_price'] is num)
                      ? (row['unit_price'] as num).toDouble()
                      : null,
                  totalItemPrice: (row['total_item_price'] is num)
                      ? (row['total_item_price'] as num).toDouble()
                      : null,
                  materialId: (mat != null) ? mat['id'] as String? : null,
                  materialName: (mat != null) ? mat['name'] as String? : null,
                  baseUnit: (pci != null)
                      ? (pci['base_unit'] as String?) ??
                            (mat != null
                                ? mat['unit_of_measure'] as String?
                                : null)
                      : null,
                  conversionRatio:
                      (pci != null && pci['conversion_ratio'] is num)
                      ? (pci['conversion_ratio'] as num).toDouble()
                      : 1.0,
                ),
              );
            }

            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: false,
                builder: (ctx) => PurchaseReviewDialog(
                  wholesalerName: wholesaler,
                  receiptDate: dt,
                  totalAmount: totalAmt,
                  lines: lines,
                  receiptImageBytes: null,
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            _showErrorSnackBar('Error loading purchase: $e');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.green[600],
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      receiptItem.wholesalerName?.isNotEmpty ?? false
                          ? receiptItem.wholesalerName!
                          : 'Purchase Receipt',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${receiptItem.itemCount} items • ${DateFormat('MMM d, yyyy').format(receiptItem.createdAt)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (receiptItem.totalAmount != null)
                    Text(
                      '€${receiptItem.totalAmount!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(child: _buildInventoryValueCard()),
            SliverToBoxAdapter(child: _buildInventoryActionsBar()),
            SliverToBoxAdapter(child: _buildCategoryGridTitle()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 800
                      ? 3
                      : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final category = _categoryCardData[index];
                  return CategoryCard(
                    categoryName: category['name'] as String,
                    imageUrl: category['imageUrl'] as String,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryItemsScreen(
                            categoryName: category['name'] as String,
                          ),
                        ),
                      );
                      if (mounted) {
                        _fetchReceiptLogs(forceRefresh: true);
                        _calculateTotalInventoryValue();
                      }
                    },
                  );
                }, childCount: _categoryCardData.length),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(_buildReceiptHeader()),
              pinned: true,
              floating: true,
            ),
          ];
        },
        body: _buildReceiptList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use web layout for wider screens
          if (kIsWeb && constraints.maxWidth > 900) {
            return Row(
              children: [
                _buildWebSidebar(),
                Expanded(child: _buildWebMainContent()),
              ],
            );
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._child);
  final Widget _child;

  @override
  double get minExtent => 60.0;
  @override
  double get maxExtent => 60.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.grey[150],
      child: _child,
    ); // Match overall background
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate._child != _child;
  }
}
