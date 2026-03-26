import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:restaurantadmin/services/local_scan_server.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:restaurantadmin/services/gemini_service.dart';
import 'package:restaurantadmin/models/menu_item_model.dart'; // For passing menu items to Gemini
// import 'package:restaurantadmin/models/brand.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For fetching menu items by brand
import 'package:restaurantadmin/services/order_service.dart'; // Import OrderService
import 'package:restaurantadmin/models/order.dart'
    as app_order; // Import and alias Order model
import 'package:intl/intl.dart'; // For date formatting
import 'package:timeago/timeago.dart'
    as timeago; // For "x minutes ago" formatting

import 'package:restaurantadmin/services/remote_receipt_service.dart';

import 'package:restaurantadmin/screens/scan_settings_screen.dart';
import 'package:restaurantadmin/screens/widgets/receipt_edit_dialog.dart';

// Model for remote scanner status
class RemoteScannerStatus {
  final String scannerId;
  final String scannerName;
  final String hostname;
  final String watchPath;
  final String status;
  final DateTime lastHeartbeat;
  final DateTime updatedAt;

  RemoteScannerStatus({
    required this.scannerId,
    required this.scannerName,
    required this.hostname,
    required this.watchPath,
    required this.status,
    required this.lastHeartbeat,
    required this.updatedAt,
  });

  factory RemoteScannerStatus.fromJson(Map<String, dynamic> json) {
    return RemoteScannerStatus(
      scannerId: json['scanner_id'] as String? ?? '',
      scannerName: json['scanner_name'] as String? ?? 'Unknown Scanner',
      hostname: json['hostname'] as String? ?? 'unknown',
      watchPath: json['watch_path'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      lastHeartbeat:
          DateTime.tryParse(json['last_heartbeat'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  bool get isOnline {
    // Consider online if status is 'online' AND last heartbeat was within 90 seconds
    if (status != 'online') return false;
    final secondsSinceHeartbeat = DateTime.now()
        .difference(lastHeartbeat)
        .inSeconds;
    return secondsSinceHeartbeat < 90;
  }
}

class ReceiptScannerScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;
  const ReceiptScannerScreen({super.key, this.initialImageBytes});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

// Helper class for displaying enriched scanned items
class _DisplayableScannedItem {
  final String menuItemId; // From Gemini
  final String menuItemNameOnReceipt; // From Gemini
  final int quantity; // From Gemini
  final double priceAtPurchase; // Fetched from DB
  final String dbMenuItemName; // Fetched from DB (actual name)
  final String? imageUrl; // Menu item image

  _DisplayableScannedItem({
    required this.menuItemId,
    required this.menuItemNameOnReceipt,
    required this.quantity,
    required this.priceAtPurchase,
    required this.dbMenuItemName,
    this.imageUrl,
  });

  double get subtotal => priceAtPurchase * quantity;
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  String? _imagePath;
  File? _imageFile;
  String? _ocrText;
  bool _isProcessing = false;
  Map<String, dynamic>? _scannedOrderData; // Raw data from Gemini
  List<_DisplayableScannedItem> _displayableItems = []; // For UI
  double? _totalMaterialCostForScannedOrder;

  // MODE TOGGLE: Test mode vs Work mode
  bool _isTestMode =
      false; // false = Work mode (auto-create), true = Test mode (edit dialog)

  double? _estimatedProfit;

  // Auto-confirm timer (5s) after AI processing
  Timer? _autoConfirmTimer;
  int _countdown = 0;
  bool _autoConfirmScheduled = false;
  // Single-submit guard to prevent duplicate order creation from auto-confirm + manual tap
  bool _orderSubmitLocked = false;

  // Remote scanner status
  List<RemoteScannerStatus> _remoteScanners = [];
  RealtimeChannel? _scannerStatusChannel;
  Timer? _statusRefreshTimer;

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final GeminiService _geminiService = GeminiService();
  final OrderService _orderService = OrderService();

  // Feature flag: use Edge Function for server-side scanning + creation
  bool get _useEdgeFunction => true; // TODO: wire to settings/remote config
  Future<bool> _tryEdgeFunctionCreate() async {
    // Guard: only when feature flag enabled and we have image
    if (!_useEdgeFunction) return false;
    try {
      if (_imagePath == null && _imageFile == null) return false;
      final path = _imagePath ?? _imageFile!.path;
      // Use RemoteReceiptService to call the new Edge Function
      final service = RemoteReceiptService();
      final result = await service.processReceiptImage(
        imagePath: path,
        brandId: _targetBrandId,
        brandName: _targetBrandName,
      );
      // Expect { ok: true, id: ..., type: 'order' }
      return (result['ok'] == true && result['type'] == 'order');
    } catch (e) {
      // Swallow to allow fallback
      return false;
    }
  }

  final String _targetBrandId = '4446a388-aaa7-402f-be4d-b82b23797415';
  final String _targetBrandName = 'DEVILS SMASH BURGER';
  List<MenuItem> _targetBrandMenuItems = [];

  @override
  void initState() {
    super.initState();
    _fetchTargetBrandMenuItems();
    _fetchRemoteScannerStatus();
    _subscribeToScannerStatus();
    // Refresh status every 30 seconds to update "last seen" times
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchRemoteScannerStatus();
    });
    // If navigated here with an already-received image, process immediately
    if (widget.initialImageBytes != null) {
      // Slight delay to ensure context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleScannedImage(widget.initialImageBytes!);
      });
    }
  }

  @override
  void dispose() {
    _autoConfirmTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _scannerStatusChannel?.unsubscribe();
    try {
      // On Windows, ML Kit is not available; guard the close call.
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        _textRecognizer.close();
      }
    } catch (_) {}
    super.dispose();
  }

  // Fetch remote scanner status from Supabase
  Future<void> _fetchRemoteScannerStatus() async {
    try {
      final response = await Supabase.instance.client
          .from('scanner_heartbeats')
          .select()
          .order('last_heartbeat', ascending: false);

      if (mounted) {
        setState(() {
          _remoteScanners = (response as List)
              .map(
                (data) =>
                    RemoteScannerStatus.fromJson(data as Map<String, dynamic>),
              )
              .toList();
        });
      }
    } catch (e) {
      print('[ReceiptScanner] Error fetching scanner status: $e');
    }
  }

  // Subscribe to real-time scanner status changes
  void _subscribeToScannerStatus() {
    _scannerStatusChannel = Supabase.instance.client
        .channel('scanner_heartbeats_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scanner_heartbeats',
          callback: (payload) {
            print(
              '[ReceiptScanner] Scanner status change: ${payload.eventType}',
            );
            _fetchRemoteScannerStatus();
          },
        )
        .subscribe();
  }

  Future<void> _fetchTargetBrandMenuItems() async {
    try {
      final response = await Supabase.instance.client
          .from('menu_items')
          .select('id, name')
          .eq('brand_id', _targetBrandId);

      _targetBrandMenuItems = (response as List)
          .map(
            (data) => MenuItem.fromJson(
              data as Map<String, dynamic>
                ..putIfAbsent(
                  'created_at',
                  () => DateTime.now().toIso8601String(),
                )
                ..putIfAbsent('category_id', () => 'dummy_category')
                ..putIfAbsent('price', () => 0.0)
                ..putIfAbsent('display_order', () => 0)
                ..putIfAbsent('is_available', () => true),
            ),
          )
          .toList();
      print(
        'Fetched ${_targetBrandMenuItems.length} menu items for $_targetBrandName',
      );
    } catch (e) {
      print('Error fetching menu items for $_targetBrandName: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error fetching menu items for $_targetBrandName: $e',
            ),
          ),
        );
      }
    }
  }

  // Ensure we have a brandId on the scanned data by looking up Supabase brands by name.
  Future<void> _ensureBrandIdentity(Map<String, dynamic> data) async {
    if (data['brandId'] is String && (data['brandId'] as String).isNotEmpty) {
      return;
    }
    String? name = (data['brandName'] as String?)?.trim();
    // Fallback to the target brand configured for this scanner session
    name = (name == null || name.isEmpty) ? _targetBrandName : name;
    if (name.isEmpty) return;
    try {
      final supabase = Supabase.instance.client;
      final exact = await supabase
          .from('brands')
          .select('id')
          .eq('name', name)
          .maybeSingle();
      if (exact != null && exact['id'] is String) {
        data['brandId'] = exact['id'];
        return;
      }
      try {
        final ilike = await supabase
            .from('brands')
            .select('id,name')
            .ilike('name', name);
        if (ilike.isNotEmpty && ilike.first['id'] is String) {
          data['brandId'] = ilike.first['id'];
          return;
        }
      } catch (_) {}
    } catch (_) {}
  }

  // Normalize Gemini result to the shape the app expects
  void _normalizeScannedData(Map<String, dynamic> data) {
    // Ensure brandName present (fallback to target brand used by the scanner session)
    data['brandName'] ??= _targetBrandName;

    // Normalize totals
    if (data['totalPrice'] == null) {
      if (data['total'] is num) {
        data['totalPrice'] = (data['total'] as num).toDouble();
      } else if (data['subtotal'] is num) {
        data['totalPrice'] = (data['subtotal'] as num).toDouble();
      }
    }

    // Normalize platformOrderId
    data['platformOrderId'] ??= data['order_id'] ?? data['orderId'];

    // Normalize paymentMethod
    if (data['paymentMethod'] == null && data['payment_method'] is String) {
      final pm = (data['payment_method'] as String).trim().toLowerCase();
      final isCard =
          pm.contains('card') ||
          pm.contains('karte') ||
          pm.contains('visa') ||
          pm.contains('master') ||
          pm.contains('maestro') ||
          pm.contains('debit') ||
          pm.contains('credit') ||
          pm.contains('online');
      data['paymentMethod'] = isCard ? 'online' : 'cash';
    }

    // Normalize order items: support either 'orderItems' or generic 'items'
    if (data['orderItems'] is! List && data['items'] is List) {
      final List normalized = [];
      for (final it in (data['items'] as List)) {
        if (it is Map<String, dynamic>) {
          normalized.add({
            'menuItemId':
                it['menu_item_id'] ?? it['item_id'] ?? it['menuItemId'],
            'menuItemName':
                it['menu_item_name'] ??
                it['item_name'] ??
                it['name'] ??
                it['menuItemName'],
            'quantity': it['quantity'] ?? it['qty'] ?? it['count'],
          });
        }
      }
      data['orderItems'] = normalized;
    } else if (data['orderItems'] is List) {
      // Ensure keys inside are correct
      final List normalized = [];
      for (final it in (data['orderItems'] as List)) {
        if (it is Map<String, dynamic>) {
          normalized.add({
            'menuItemId':
                it['menuItemId'] ?? it['menu_item_id'] ?? it['item_id'],
            'menuItemName':
                it['menuItemName'] ?? it['menu_item_name'] ?? it['item_name'],
            'quantity': it['quantity'] ?? it['qty'] ?? it['count'],
          });
        }
      }
      data['orderItems'] = normalized;
    }
  }

  Future<void> _handleScannedImage(Uint8List imageBytes) async {
    if (!mounted) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageBytes);
      await _processImage(tempFile.path, rawBytes: imageBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error handling scanned image: ${e.toString()}'),
          ),
        );
      }
      print('Error in _handleScannedImage: $e');
    }
  }

  Future<void> _pickImageAndScan(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      await _processImage(pickedFile.path, rawBytes: bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')),
        );
      }
      print('Error in _pickImageAndScan: $e');
    }
  }

  Future<void> _processImage(String imagePath, {Uint8List? rawBytes}) async {
    setState(() {
      _isProcessing = true;
      _imagePath = imagePath;
      _imageFile = File(imagePath);
      _ocrText = null;
      _scannedOrderData = null;
      _displayableItems = [];
      _totalMaterialCostForScannedOrder = null;
      _estimatedProfit = null;
    });

    try {
      // Use ML Kit OCR only on mobile (Android/iOS). On Windows/Desktop, skip and rely on Gemini Vision.
      final bool supportsMlKit =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (supportsMlKit) {
        try {
          final inputImage = InputImage.fromFilePath(imagePath);
          final RecognizedText recognizedText = await _textRecognizer
              .processImage(inputImage);
          setState(() {
            _ocrText = recognizedText.text;
          });
        } on MissingPluginException {
          // Plugin not available on this platform — proceed without OCR
          setState(() {
            _ocrText = null;
          });
        } catch (_) {
          // Any OCR failure: continue with Vision path
          setState(() {
            _ocrText = null;
          });
        }
      } else {
        _ocrText = null;
      }

      if (_targetBrandMenuItems.isEmpty) {
        await _fetchTargetBrandMenuItems();
        if (_targetBrandMenuItems.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Menu items for $_targetBrandName could not be loaded. Cannot process with Gemini.',
              ),
            ),
          );
          setState(() => _isProcessing = false);
          return;
        }
      }

      Map<String, dynamic>? geminiResult;

      // Prefer OCR+text prompt if text found, otherwise fall back to vision
      if (_ocrText != null && _ocrText!.trim().isNotEmpty) {
        geminiResult = await _geminiService.processReceiptTextWithGemini(
          ocrText: _ocrText!,
          brandNameFromReceipt: _targetBrandName,
          menuItemsForBrand: _targetBrandMenuItems,
        );
      }

      // If text path failed or OCR empty, try vision with image bytes
      if (geminiResult == null) {
        final bytes = rawBytes ?? await File(imagePath).readAsBytes();
        geminiResult = await _geminiService.processReceiptImageWithGemini(
          imageBytes: bytes,
          brandNameFromReceipt: _targetBrandName,
          menuItemsForBrand: _targetBrandMenuItems,
        );
      }

      if (geminiResult != null) {
        // Ensure brandId is present by looking it up from Supabase when missing
        await _ensureBrandIdentity(geminiResult);
        // Normalize keys (items -> orderItems, total -> totalPrice, etc.) for UI and order creation
        _normalizeScannedData(geminiResult);
        _scannedOrderData = geminiResult;
        await _processAndEnrichScannedItems(geminiResult);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt processed by AI. Review the data.'),
            ),
          );
        }
        // In test mode, show edit dialog. In work mode, auto-create order
        if (_isTestMode) {
          _showEditDialog();
        } else {
          _startAutoConfirmCountdown();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI processing failed or returned no data.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during processing: ${e.toString()}')),
        );
      }
      print('Error in _processImage: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showEditDialog() async {
    if (_scannedOrderData == null) return;

    // Read the image bytes if available
    Uint8List? imageBytes;
    if (_imageFile != null) {
      imageBytes = await _imageFile!.readAsBytes();
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ReceiptEditDialog(
          scannedData: _scannedOrderData!,
          receiptImageBytes: imageBytes,
          receiptImagePath: _imagePath,
        ),
      ),
    );

    // If successfully saved to receipt watcher, navigate back
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt saved to watcher! Returning to home...'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _startAutoConfirmCountdown() {
    if (_autoConfirmScheduled ||
        _scannedOrderData == null ||
        _orderSubmitLocked) {
      return;
    }
    setState(() {
      _autoConfirmScheduled = true;
      _countdown = 5;
    });
    _autoConfirmTimer?.cancel();
    _autoConfirmTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        setState(() {
          _autoConfirmScheduled = false;
        });
        await _autoCreateOrder();
      } else {
        setState(() {
          _countdown -= 1;
        });
      }
    });
  }

  void _cancelAutoConfirm() {
    if (_autoConfirmTimer != null) {
      _autoConfirmTimer!.cancel();
    }
    setState(() {
      _autoConfirmScheduled = false;
    });
  }

  void _navigateToOrdersScreen() {
    // Proactively notify listeners to refresh
    try {
      // Import is at app level; using runtime access via WidgetsBinding to avoid import cycle
      // If available, we can directly use the notification service
    } catch (_) {}
    // Navigate to MainScreen with Orders tab selected (index 0)
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _autoCreateOrder() async {
    if (_scannedOrderData == null || _orderSubmitLocked) return;
    _orderSubmitLocked = true; // Lock to prevent duplicate submissions
    _autoConfirmTimer?.cancel();
    try {
      if (await _tryEdgeFunctionCreate()) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order created (server)')));
        _navigateToOrdersScreen();
        return;
      }
      final createdOrder = await _orderService.createOrderFromScannedData(
        _scannedOrderData!,
        fulfillmentType: 'delivery',
      );
      if (!mounted) return;
      if (createdOrder != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${createdOrder.id?.substring(0, 8)} created!'),
          ),
        );
        // Navigate to Orders screen to show the new order
        _navigateToOrdersScreen();
      } else {
        // If creation returned null, allow manual attempt
        _orderSubmitLocked = false;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-create failed: ${e.toString()}')),
      );
    } finally {
      _orderSubmitLocked = false; // Unlock in case of failure
    }
  }

  Future<void> _processAndEnrichScannedItems(
    Map<String, dynamic> geminiData,
  ) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _displayableItems = [];
      _totalMaterialCostForScannedOrder = null;
      _estimatedProfit = null;
    });

    List<_DisplayableScannedItem> tempDisplayableItems = [];
    double tempTotalMaterialCost = 0.0;

    final List<dynamic>? scannedItems =
        geminiData['orderItems'] as List<dynamic>?;

    if (scannedItems != null) {
      for (var itemData in scannedItems) {
        if (itemData is Map<String, dynamic>) {
          String? menuItemId = itemData['menuItemId'] as String?;
          String? menuItemNameOnReceipt = itemData['menuItemName'] as String?;
          int? quantity = (itemData['quantity'] as num?)?.toInt();

          if (menuItemId == null ||
              menuItemNameOnReceipt == null ||
              quantity == null ||
              quantity <= 0) {
            print(
              '[ReceiptScanner] Skipping invalid item from Gemini: $itemData',
            );
            continue;
          }

          try {
            final menuItemResponse = await Supabase.instance.client
                .from('menu_items')
                .select()
                .eq('id', menuItemId)
                .single();

            final fullMenuItem = MenuItem.fromJson(menuItemResponse);

            tempDisplayableItems.add(
              _DisplayableScannedItem(
                menuItemId: fullMenuItem.id,
                menuItemNameOnReceipt: menuItemNameOnReceipt,
                quantity: quantity,
                priceAtPurchase: fullMenuItem.price,
                dbMenuItemName: fullMenuItem.name,
                imageUrl: fullMenuItem.imageUrl,
              ),
            );

            double itemUnitMaterialCost =
                await _calculateMaterialCostForMenuItem(menuItemId);
            tempTotalMaterialCost += itemUnitMaterialCost * quantity;
          } catch (e) {
            print(
              '[ReceiptScanner] Error fetching/processing menu item $menuItemId: $e',
            );
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _displayableItems = tempDisplayableItems;
      _totalMaterialCostForScannedOrder = tempTotalMaterialCost;

      double scannedTotalPrice =
          (geminiData['totalPrice'] as num?)?.toDouble() ?? 0.0;
      if (_totalMaterialCostForScannedOrder != null) {
        _estimatedProfit =
            scannedTotalPrice - _totalMaterialCostForScannedOrder!;
      } else {
        _estimatedProfit = null;
      }
      _isProcessing = false;
    });
  }

  Future<double> _calculateMaterialCostForMenuItem(String menuItemId) async {
    double singleItemMaterialCost = 0.0;
    try {
      final mimResponse = await Supabase.instance.client
          .from('menu_item_materials')
          .select('quantity_used, material_id(average_unit_cost)')
          .eq('menu_item_id', menuItemId);

      if (mimResponse.isNotEmpty) {
        for (var mimData in mimResponse as List) {
          final double quantityUsed =
              (mimData['quantity_used'] as num?)?.toDouble() ?? 0.0;
          final materialData = mimData['material_id'] as Map<String, dynamic>?;
          final double? materialWac =
              (materialData?['average_unit_cost'] as num?)?.toDouble();

          if (materialWac != null && materialWac > 0) {
            singleItemMaterialCost += quantityUsed * materialWac;
          }
        }
      }
    } catch (e) {
      print(
        '[ReceiptScanner] Error calculating material cost for menu item $menuItemId: $e',
      );
    }
    return singleItemMaterialCost;
  }

  Widget _buildScannedDataReview() {
    if (_scannedOrderData == null) {
      return const Text('No data processed yet. Scan a receipt.');
    }

    List<Widget> details = [];
    final DateFormat dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    _scannedOrderData!.forEach((key, value) {
      if (key != 'orderItems' && value != null) {
        String displayValue = value.toString();
        if ((key == 'createdAt' || key == 'requestedDeliveryTime') &&
            value is String) {
          final dt = DateTime.tryParse(value);
          if (dt != null) {
            displayValue = dateFormat.format(dt);
          }
        }
        details.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatKey(key)}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: Text(
                    displayValue,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    details.add(const SizedBox(height: 12));
    details.add(
      const Text(
        'Items:',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );

    // If we have raw scanned orderItems but enrichment not done yet, show a compact preview instead of "Processing..."
    if (_displayableItems.isEmpty &&
        _scannedOrderData != null &&
        _scannedOrderData!['orderItems'] is List) {
      final rawItems = _scannedOrderData!['orderItems'] as List;
      for (final it in rawItems.take(5)) {
        if (it is Map<String, dynamic>) {
          details.add(
            ListTile(
              dense: true,
              leading: const Icon(Icons.fastfood, color: Colors.teal),
              title: Text(it['menuItemName']?.toString() ?? 'Item'),
              subtitle: Text(
                'x${it['quantity'] ?? 1} • ${it['menuItemId'] ?? ''}',
              ),
            ),
          );
        }
      }
      if (rawItems.length > 5) {
        details.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('…', textAlign: TextAlign.center),
          ),
        );
      }
    }

    if (_displayableItems.isNotEmpty) {
      for (var item in _displayableItems) {
        details.add(
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              dense: true,
              leading: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imageUrl != null
                          ? Image.network(
                              item.imageUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.teal.withValues(alpha: 0.08),
                                child: const Icon(
                                  Icons.fastfood,
                                  color: Colors.teal,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.teal.withValues(alpha: 0.08),
                              child: const Icon(
                                Icons.fastfood,
                                color: Colors.teal,
                              ),
                            ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'x${item.quantity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                item.menuItemNameOnReceipt,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'DB: ${item.dbMenuItemName} • Price: €${item.priceAtPurchase.toStringAsFixed(2)}/item',
              ),
              trailing: Text(
                '€${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }
    } else if (_scannedOrderData!['orderItems'] is List &&
        (_scannedOrderData!['orderItems'] as List).isNotEmpty) {
      // Removed noisy placeholder. Raw preview is shown above until enrichment finishes.
    } else {
      details.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'No items found or processed from receipt.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    details.add(const Divider(height: 24, thickness: 1.5));

    final double totalPriceFromGemini =
        (_scannedOrderData!['totalPrice'] as num?)?.toDouble() ?? 0.0;
    details.add(
      _buildSummaryRow(
        'Receipt Total:',
        '€${totalPriceFromGemini.toStringAsFixed(2)}',
        isTotal: true,
      ),
    );

    if (_totalMaterialCostForScannedOrder != null) {
      details.add(
        _buildSummaryRow(
          'Est. Material Cost:',
          '€${_totalMaterialCostForScannedOrder!.toStringAsFixed(2)}',
        ),
      );
    }
    if (_estimatedProfit != null) {
      details.add(
        _buildSummaryRow(
          'Est. Profit:',
          '€${_estimatedProfit!.toStringAsFixed(2)}',
          valueColor: _estimatedProfit! >= 0
              ? Colors.green.shade700
              : Colors.red.shade700,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
  }

  String _formatKey(String key) {
    if (key == 'createdAt') return 'Created At';
    if (key == 'orderTypeName') return 'Order Type';
    if (key == 'customerName') return 'Customer Name';
    if (key == 'customerStreet') return 'Street';
    if (key == 'customerPostcode') return 'Postcode';
    if (key == 'customerCity') return 'City';
    if (key == 'totalPrice') return 'Total Price';
    if (key == 'requestedDeliveryTime') return 'Requested Delivery';
    if (key == 'paymentMethod') return 'Payment';
    if (key == 'platformOrderId') return 'Platform Order ID';
    return key
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .capitalizeFirst();
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _createOrderFromScannedData() async {
    if (_orderSubmitLocked) {
      return; // Prevent double submit if auto-confirm already fired
    }
    _orderSubmitLocked = true;
    _autoConfirmTimer?.cancel();

    if (_scannedOrderData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No scanned data available to create order.'),
        ),
      );
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm Order Creation'),
          content: const Text(
            'Are you sure you want to create this order based on the scanned data?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              onPressed: () {
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Create Order'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Try server path first if feature flag is on
      if (await _tryEdgeFunctionCreate()) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order created (server)')));
        _navigateToOrdersScreen();
        return;
      }

      final app_order.Order? createdOrder = await _orderService
          .createOrderFromScannedData(
            _scannedOrderData!,
            fulfillmentType: 'delivery', // Pass fulfillmentType
          );

      if (mounted) {
        if (createdOrder != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${createdOrder.id?.substring(0, 8)} created successfully!',
              ),
            ),
          );
          _navigateToOrdersScreen();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create order from scanned data.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating order: ${e.toString()}')),
        );
      }
      print('Error in _createOrderFromScannedData: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // Build a tile showing remote scanner status
  Widget _buildRemoteScannerTile(RemoteScannerStatus scanner) {
    final isOnline = scanner.isOnline;
    final lastSeen = timeago.format(scanner.lastHeartbeat);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOnline ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.green : Colors.red,
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scanner.scannerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isOnline
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${scanner.hostname} • Last seen: $lastSeen',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isOnline ? Icons.check_circle : Icons.error_outline,
            color: isOnline ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isServerRunning = LocalScanServer().isRunning;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            tooltip: 'Scan Settings',
            icon: const Icon(Icons.settings_suggest),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Mode Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isTestMode
                      ? [Colors.orange.shade400, Colors.orange.shade600]
                      : [Colors.teal.shade400, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: (_isTestMode ? Colors.orange : Colors.teal)
                        .withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _isTestMode ? Icons.science : Icons.work,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isTestMode ? 'TEST MODE' : 'WORK MODE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isTestMode
                              ? 'Edit receipt → Save to watcher'
                              : 'Auto-create order',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isTestMode,
                    onChanged: (value) {
                      setState(() {
                        _isTestMode = value;
                        // Cancel any auto-confirm if switching to test mode
                        if (_isTestMode) {
                          _cancelAutoConfirm();
                        }
                      });
                    },
                    activeColor: Colors.orange.shade300,
                    activeTrackColor: Colors.white.withOpacity(0.5),
                    inactiveThumbColor: Colors.teal.shade300,
                    inactiveTrackColor: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isServerRunning
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isServerRunning
                      ? Colors.green.shade300
                      : Colors.red.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isServerRunning ? Icons.wifi : Icons.wifi_off,
                    color: isServerRunning
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isServerRunning
                        ? 'Ready for Scan - Listening on localhost:8080'
                        : 'Scanner Service Not Running',
                    style: TextStyle(
                      color: isServerRunning
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Remote Scanner Status Section
            if (_remoteScanners.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.computer,
                            size: 20,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Remote Scanners',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: _fetchRemoteScannerStatus,
                            tooltip: 'Refresh status',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._remoteScanners.map(
                        (scanner) => _buildRemoteScannerTile(scanner),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Show placeholder when no remote scanners
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.computer_outlined, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'No remote scanners registered',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Scanned receipts from your PC will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // Only show auto-confirm countdown in work mode
            if (!_isTestMode && _autoConfirmScheduled) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Auto-confirm in $_countdown seconds…',
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelAutoConfirm,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_isProcessing && _scannedOrderData == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              if (_imageFile != null) ...[
                const Text(
                  'Captured Image:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Image.file(_imageFile!, height: 200, fit: BoxFit.contain),
                const SizedBox(height: 16),
              ],
              if (_ocrText != null &&
                  _scannedOrderData == null &&
                  !_isProcessing) ...[
                const Text(
                  'Extracted Text (OCR):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    _ocrText!,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_scannedOrderData != null) ...[
                if (_isProcessing && _displayableItems.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  const Text(
                    'AI Processed Data (Review):',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _buildScannedDataReview(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // In Test Mode: Show "Edit & Save" button
                  // In Work Mode: Show "Create Order" button
                  if (_isTestMode)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit & Save to Receipt Watcher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isProcessing || _scannedOrderData == null
                          ? null
                          : _showEditDialog,
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: Text(
                        _orderSubmitLocked
                            ? 'Creating…'
                            : 'Create Order from Scan',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed:
                          _isProcessing ||
                              _scannedOrderData == null ||
                              _orderSubmitLocked
                          ? null
                          : () {
                              _createOrderFromScannedData();
                            },
                    ),
                ],
              ] else if (!_isProcessing &&
                  _imageFile != null &&
                  _ocrText == null) ...[
                const Center(
                  child: Text(
                    'Could not extract text from image or AI processing failed.',
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
