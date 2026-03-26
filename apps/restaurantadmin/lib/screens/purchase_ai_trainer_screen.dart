import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:restaurantadmin/models/material_item.dart';
import 'package:restaurantadmin/screens/material_history_screen.dart';

/// Training step enum
enum TrainingStep {
  idle,
  analyzingReceipt,
  confirmingSupplier,
  confirmingItems,
  confirmingMappings,
  saving,
  complete,
}

/// Chat message model
class ChatMessage {
  final String text;
  final bool isAi;
  final DateTime timestamp;
  final Widget? actionWidget;

  ChatMessage({
    required this.text,
    required this.isAi,
    DateTime? timestamp,
    this.actionWidget,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Parsed item from receipt
class ParsedItem {
  String rawName;
  String? brandName;
  String? itemNumber;
  double quantity;
  String unit;
  double? unitPrice;
  double? totalPrice;
  bool isApproved;

  // Material mapping
  String? materialId;
  String? materialName;
  double? conversionRatio;
  String? baseUnit;

  // Extracted per-piece quantity from item name (e.g., "1000ML" from "MAYO 1000ML")
  // User can edit this if AI extracted wrong
  double? extractedPerPieceQty;
  String? extractedPerPieceUnit;

  ParsedItem({
    required this.rawName,
    this.brandName,
    this.itemNumber,
    required this.quantity,
    required this.unit,
    this.unitPrice,
    this.totalPrice,
    this.isApproved = false,
    this.materialId,
    this.materialName,
    this.conversionRatio,
    this.baseUnit,
    this.extractedPerPieceQty,
    this.extractedPerPieceUnit,
  });

  Map<String, dynamic> toJson() => {
    'raw_name': rawName,
    'brand_name': brandName,
    'item_number': itemNumber,
    'quantity': quantity,
    'unit': unit,
    'unit_price': unitPrice,
    'total_price': totalPrice,
    'material_id': materialId,
    'material_name': materialName,
    'conversion_ratio': conversionRatio,
    'base_unit': baseUnit,
    'extracted_per_piece_qty': extractedPerPieceQty,
    'extracted_per_piece_unit': extractedPerPieceUnit,
  };
}

class PurchaseAiTrainerScreen extends StatefulWidget {
  const PurchaseAiTrainerScreen({super.key});

  @override
  State<PurchaseAiTrainerScreen> createState() =>
      _PurchaseAiTrainerScreenState();
}

class _PurchaseAiTrainerScreenState extends State<PurchaseAiTrainerScreen> {
  final _supabase = Supabase.instance.client;
  final _scrollController = ScrollController();

  // Gemini API Key
  late final String _geminiApiKey;

  // State
  TrainingStep _currentStep = TrainingStep.idle;
  Uint8List? _imageBytes;
  String? _fileName;
  final List<ChatMessage> _messages = [];

  // Parsed data
  String? _detectedSupplier;
  String? _confirmedSupplierId;
  String? _confirmedSupplierName;
  double? _totalReceiptAmount;
  List<ParsedItem> _parsedItems = [];
  List<Map<String, dynamic>> _availableSuppliers = [];
  List<Map<String, dynamic>> _availableMaterials = [];

  // Training stats
  int _trainingCount = 0;

  @override
  void initState() {
    super.initState();
    _initGemini();
    _loadInitialData();
    _addWelcomeMessage();
  }

  void _initGemini() {
    _geminiApiKey = _resolveApiKey();
  }

  static String _resolveApiKey() {
    const fromDefine = String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromDotenv = dotenv.maybeGet('GEMINI_API_KEY');
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    return 'AIzaSyAiYA0l0aUtD-NSxoCElkMNPX9IQy25DZU';
  }

  Future<void> _loadInitialData() async {
    try {
      // Load suppliers
      final suppliers = await _supabase
          .from('suppliers')
          .select('id, name')
          .order('name');
      _availableSuppliers = (suppliers as List).cast<Map<String, dynamic>>();

      // Load materials
      final materials = await _supabase
          .from('material')
          .select('id, name, unit_of_measure, category, item_image_url')
          .order('name');
      _availableMaterials = (materials as List).cast<Map<String, dynamic>>();

      // Count training samples
      final countResp = await _supabase
          .from('ai_training_samples')
          .select('id')
          .count(CountOption.exact);
      _trainingCount = countResp.count;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text:
            '''👋 Welcome to the **Purchase Receipt AI Trainer**!

🔧 **VERSION 4.7 - CHAT INTERFACE** 🔧

I'll help you train me to recognize your purchase receipts:

1. **Upload a receipt** - Click 📎 or drag & drop 📄
2. **Confirm the supplier** - I'll show the total! 💰
3. **Verify the items** - With item numbers 🏷️
4. **Map to materials** - Smart matching

✨ **New Chat Features:**
• **Type messages** - Correct totals, ask questions
• **Restart button** - 🔄 Clear and start fresh
• **Linked materials** - View in Inventory

💬 **Tips:**
• Type "total 1234.56" to correct the receipt total
• Use buttons for supplier/item actions
• Type anything to chat!

📊 **Training samples:** $_trainingCount

**Ready?** Upload a receipt or type a message!''',
        isAi: true,
      ),
    );
  }

  void _addMessage(String text, {bool isAi = false, Widget? actionWidget}) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isAi: isAi, actionWidget: actionWidget),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Export chat to clipboard for debugging
  Future<void> _exportChat() async {
    final buffer = StringBuffer();
    buffer.writeln('=== PURCHASE AI TRAINER CHAT EXPORT ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Current Step: $_currentStep');
    buffer.writeln('Training Count: $_trainingCount');
    buffer.writeln('');

    for (final msg in _messages) {
      final sender = msg.isAi ? '🤖 AI' : '👤 User';
      final time = DateFormat('HH:mm:ss').format(msg.timestamp);
      buffer.writeln('[$time] $sender:');
      buffer.writeln(msg.text);
      buffer.writeln('');
    }

    // Add parsed items info if available
    if (_parsedItems.isNotEmpty) {
      buffer.writeln('=== PARSED ITEMS ===');
      for (final item in _parsedItems) {
        buffer.writeln('- ${item.rawName}');
        buffer.writeln('  Qty: ${item.quantity} ${item.unit}');
        if (item.materialId != null) {
          final unitFactor = _getUnitConversionFactor(
            item.unit,
            item.baseUnit ?? item.unit,
          );
          final qtyToAdd = _calculateQtyToAdd(item);
          buffer.writeln(
            '  → Mapped to: ${item.materialName} (base unit: ${item.baseUnit})',
          );
          buffer.writeln(
            '  → Unit conversion: ${item.unit} → ${item.baseUnit} (factor: $unitFactor)',
          );
          buffer.writeln(
            '  → Additional ratio: ${item.conversionRatio ?? 1.0}',
          );
          buffer.writeln(
            '  → Qty to add: ${qtyToAdd.toStringAsFixed(2)} ${item.baseUnit ?? item.unit}',
          );
        }
        buffer.writeln('');
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Chat exported to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Convert between units - returns multiplier to convert from sourceUnit to targetUnit
  /// e.g., convertUnits('kg', 'g') returns 1000 (1 kg = 1000 g)
  static double _getUnitConversionFactor(String sourceUnit, String targetUnit) {
    final source = sourceUnit.toLowerCase().trim();
    final target = targetUnit.toLowerCase().trim();

    // If same unit, no conversion needed
    if (source == target) return 1.0;

    // Define unit equivalents in base units
    // Weight: base unit = gram
    final weightToGrams = {
      'kg': 1000.0,
      'kilogram': 1000.0,
      'kilograms': 1000.0,
      'g': 1.0,
      'gram': 1.0,
      'grams': 1.0,
      'gr': 1.0,
      'mg': 0.001,
      'milligram': 0.001,
      'milligrams': 0.001,
      'lb': 453.592,
      'lbs': 453.592,
      'pound': 453.592,
      'pounds': 453.592,
      'oz': 28.3495,
      'ounce': 28.3495,
      'ounces': 28.3495,
    };

    // Volume: base unit = milliliter
    final volumeToMl = {
      'l': 1000.0,
      'liter': 1000.0,
      'liters': 1000.0,
      'litre': 1000.0,
      'litres': 1000.0,
      'ml': 1.0,
      'milliliter': 1.0,
      'milliliters': 1.0,
      'millilitre': 1.0,
      'millilitres': 1.0,
      'cl': 10.0,
      'centiliter': 10.0,
      'centiliters': 10.0,
      'dl': 100.0,
      'deciliter': 100.0,
      'deciliters': 100.0,
      'gal': 3785.41,
      'gallon': 3785.41,
      'gallons': 3785.41,
      'pt': 473.176,
      'pint': 473.176,
      'pints': 473.176,
      'qt': 946.353,
      'quart': 946.353,
      'quarts': 946.353,
      'fl oz': 29.5735,
      'fluid ounce': 29.5735,
    };

    // Check if both are weight units
    if (weightToGrams.containsKey(source) &&
        weightToGrams.containsKey(target)) {
      final sourceInGrams = weightToGrams[source]!;
      final targetInGrams = weightToGrams[target]!;
      return sourceInGrams / targetInGrams;
    }

    // Check if both are volume units
    if (volumeToMl.containsKey(source) && volumeToMl.containsKey(target)) {
      final sourceInMl = volumeToMl[source]!;
      final targetInMl = volumeToMl[target]!;
      return sourceInMl / targetInMl;
    }

    // Can't convert between different unit types or unknown units
    // Return 1.0 and let the user adjust manually
    return 1.0;
  }

  /// Extract quantity per piece from item name (e.g., "MAYO 1000ML" -> 1000, "ml")
  /// Returns (quantity, unit) or null if not found
  /// Also handles patterns like "10X113G" (10 pieces of 113g each = 1130g)
  /// IMPROVED: Better handling of European decimal comma (3,1 -> 3.1)
  static (double, String)? _extractQtyFromName(String itemName) {
    final name = itemName.toUpperCase();

    // First, check for "NUMBERxNUMBER" pattern like "10X113G" or "24X0,33L"
    // This means multiple items per package
    final multiPattern = RegExp(
      r'(\d+)\s*[xX×]\s*(\d+(?:[.,]\d+)?)\s*(G|KG|ML|L|GR|GRAM|CL|DL)(?:\s|$|[^A-Z])',
      caseSensitive: false,
    );
    final multiMatch = multiPattern.firstMatch(name);
    if (multiMatch != null) {
      final count = double.tryParse(multiMatch.group(1)!) ?? 1;
      final perPiece =
          double.tryParse(multiMatch.group(2)!.replaceAll(',', '.')) ?? 0;
      final unitRaw = multiMatch.group(3)!.toUpperCase();
      final unitMap = {
        'G': 'g',
        'GR': 'g',
        'GRAM': 'g',
        'KG': 'kg',
        'ML': 'ml',
        'L': 'L',
        'CL': 'cl',
        'DL': 'dl',
      };
      final unit = unitMap[unitRaw] ?? unitRaw.toLowerCase();
      if (count > 0 && perPiece > 0) {
        return (count * perPiece, unit); // Total per package
      }
    }

    // Check for "NUMBER STK/STÜCK" pattern meaning pieces in a pack
    final stkPattern = RegExp(
      r'(\d+)\s*(STK|STÜCK|STUCK|PCS|PC|PIECES)(?:\s|$|[^A-Z])',
      caseSensitive: false,
    );
    final stkMatch = stkPattern.firstMatch(name);
    if (stkMatch != null) {
      final count = double.tryParse(stkMatch.group(1)!) ?? 1;
      if (count > 0) {
        return (count, 'piece'); // Return as pieces
      }
    }

    // IMPORTANT: Match quantity BEFORE unit, handling European comma decimals
    // Pattern: NUMBER followed by UNIT (with optional space)
    // Examples: "3,1KG", "3.1 KG", "1000ML", "0,33L"
    final patterns = [
      // Weight patterns - order matters, KG before G to match correctly
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(KG|KILOGRAM|KILOGRAMS|KILO)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(G|GRAM|GRAMS|GR)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(MG|MILLIGRAM|MILLIGRAMS)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      // Volume patterns - order matters, L patterns that won't match ML first
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(ML|MILLILITER|MILLILITERS)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(CL|CENTILITER|CENTILITERS)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(DL|DECILITER|DECILITERS)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(?<!M)(L|LITER|LITERS|LITRE|LITRES)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(CCM|CM3|CC)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      // Other weight patterns
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(LB|LBS|POUND|POUNDS)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(OZ|OUNCE|OUNCES)(?:\s|$|[^A-Z])',
        caseSensitive: false,
      ),
    ];

    // Normalize unit names
    final unitMap = {
      'ML': 'ml',
      'MILLILITER': 'ml',
      'MILLILITERS': 'ml',
      'L': 'L',
      'LITER': 'L',
      'LITERS': 'L',
      'LITRE': 'L',
      'LITRES': 'L',
      'CL': 'cl',
      'CENTILITER': 'cl',
      'CENTILITERS': 'cl',
      'DL': 'dl',
      'DECILITER': 'dl',
      'DECILITERS': 'dl',
      'CCM': 'ml',
      'CM3': 'ml',
      'CC': 'ml',
      'KG': 'kg',
      'KILOGRAM': 'kg',
      'KILOGRAMS': 'kg',
      'KILO': 'kg',
      'G': 'g',
      'GRAM': 'g',
      'GRAMS': 'g',
      'GR': 'g',
      'MG': 'mg',
      'MILLIGRAM': 'mg',
      'MILLIGRAMS': 'mg',
      'LB': 'lb',
      'LBS': 'lb',
      'POUND': 'lb',
      'POUNDS': 'lb',
      'OZ': 'oz',
      'OUNCE': 'oz',
      'OUNCES': 'oz',
    };

    for (final pattern in patterns) {
      final match = pattern.firstMatch(name);
      if (match != null) {
        // Replace comma with dot for European decimal format
        final qtyStr = match.group(1)!.replaceAll(',', '.');
        final qty = double.tryParse(qtyStr);
        final unitRaw = match.group(2)!.toUpperCase();
        final unit = unitMap[unitRaw] ?? unitRaw.toLowerCase();

        if (qty != null && qty > 0) {
          return (qty, unit);
        }
      }
    }

    return null;
  }

  /// Check if a unit is a piece/count unit (not weight/volume)
  static bool _isPieceUnit(String unit) {
    return [
      'piece',
      'pieces',
      'pc',
      'pcs',
      'stk',
      'stück',
      'stuck',
      'ea',
      'each',
      'unit',
      'units',
      '',
    ].contains(unit.toLowerCase().trim());
  }

  /// Check if unit is weight
  static bool _isWeightUnit(String unit) {
    return [
      'g',
      'gram',
      'grams',
      'gr',
      'kg',
      'kilogram',
      'kilograms',
      'kilo',
      'mg',
      'milligram',
      'lb',
      'lbs',
      'oz',
      'ounce',
    ].contains(unit.toLowerCase().trim());
  }

  /// Check if unit is volume
  static bool _isVolumeUnit(String unit) {
    return [
      'l',
      'liter',
      'liters',
      'litre',
      'ml',
      'milliliter',
      'cl',
      'centiliter',
      'dl',
      'deciliter',
    ].contains(unit.toLowerCase().trim());
  }

  /// Calculate quantity to add to material with unit conversion
  /// COMPLETELY REWRITTEN for robustness
  double _calculateQtyToAdd(ParsedItem item) {
    if (item.baseUnit == null) {
      return item.quantity * (item.conversionRatio ?? 1.0);
    }

    final receiptUnit = item.unit.toLowerCase().trim();
    final materialUnit = item.baseUnit!.toLowerCase().trim();

    // SPECIAL CASE: Material unit is "piece" - just return the quantity directly
    // No conversions needed! If you buy 24 bottles, you add 24 pieces.
    if (_isPieceUnit(materialUnit)) {
      return item.quantity * (item.conversionRatio ?? 1.0);
    }

    // CASE 1: Receipt unit is a weight/volume unit (not pieces)
    // e.g., "1 KG", "12 G", "500 ML" - use directly
    if (_isWeightUnit(receiptUnit) || _isVolumeUnit(receiptUnit)) {
      final factor = _getUnitConversionFactor(receiptUnit, materialUnit);
      return item.quantity * factor * (item.conversionRatio ?? 1.0);
    }

    // CASE 2: Receipt unit is pieces - need to find size per piece
    if (_isPieceUnit(receiptUnit)) {
      // Use user-edited values if available
      if (item.extractedPerPieceQty != null &&
          item.extractedPerPieceUnit != null &&
          item.extractedPerPieceQty! > 0) {
        final perPieceQty = item.extractedPerPieceQty!;
        final perPieceUnit = item.extractedPerPieceUnit!;

        // If per-piece unit is also "piece", just return quantity
        if (_isPieceUnit(perPieceUnit)) {
          return item.quantity * perPieceQty * (item.conversionRatio ?? 1.0);
        }

        // Convert per-piece quantity to material unit
        final factor = _getUnitConversionFactor(perPieceUnit, materialUnit);
        return item.quantity *
            perPieceQty *
            factor *
            (item.conversionRatio ?? 1.0);
      }

      // Fall back to extracting from name
      final extracted = _extractQtyFromName(item.rawName);
      if (extracted != null) {
        final (perPieceQty, perPieceUnit) = extracted;

        // If extracted unit is piece, just multiply
        if (_isPieceUnit(perPieceUnit)) {
          return item.quantity * perPieceQty * (item.conversionRatio ?? 1.0);
        }

        final factor = _getUnitConversionFactor(perPieceUnit, materialUnit);
        return item.quantity *
            perPieceQty *
            factor *
            (item.conversionRatio ?? 1.0);
      }

      // No size found - just return quantity as pieces
      return item.quantity * (item.conversionRatio ?? 1.0);
    }

    // CASE 3: Unknown unit type - just return quantity
    return item.quantity * (item.conversionRatio ?? 1.0);
  }

  /// Initialize extracted per-piece values for an item (called when material is mapped)
  void _initExtractedValues(ParsedItem item) {
    // Only initialize for piece units
    if (!_isPieceUnit(item.unit)) return;

    if (item.extractedPerPieceQty == null) {
      final extracted = _extractQtyFromName(item.rawName);
      if (extracted != null) {
        item.extractedPerPieceQty = extracted.$1;
        item.extractedPerPieceUnit = extracted.$2;
      } else if (item.baseUnit != null) {
        // Set default unit based on material base unit
        if (_isVolumeUnit(item.baseUnit!)) {
          item.extractedPerPieceUnit = 'ml';
        } else if (_isWeightUnit(item.baseUnit!)) {
          item.extractedPerPieceUnit = 'g';
        }
      }
    }
  }

  /// Format quantity nicely (e.g., 25000 -> "25,000")
  String _formatQty(double qty) {
    if (qty >= 1000) {
      return NumberFormat('#,##0.##').format(qty);
    } else if (qty == qty.roundToDouble()) {
      return qty.toStringAsFixed(0);
    } else {
      return qty.toStringAsFixed(2);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.bytes == null) return;

    final fileName = result.files.single.name.toLowerCase();
    final isPdf = fileName.endsWith('.pdf');

    setState(() {
      _imageBytes = result.files.single.bytes;
      _fileName = result.files.single.name;
      _currentStep = TrainingStep.analyzingReceipt;
    });

    _addMessage(
      '📄 Uploaded: $_fileName ${isPdf ? "(PDF)" : "(Image)"}',
      isAi: false,
    );
    await _analyzeReceipt();
  }

  /// Get mime type from filename
  String _getMimeType(String? fileName) {
    if (fileName == null) return 'image/jpeg';
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// Call Gemini API directly via REST
  Future<Map<String, dynamic>?> _callGeminiApi(
    String prompt, {
    Uint8List? imageBytes,
  }) async {
    // Use the same model as scan-receipt: gemini-2.5-flash
    final strategies = [
      {'model': 'gemini-2.5-flash', 'version': 'v1beta'},
      {'model': 'gemini-1.5-flash', 'version': 'v1beta'},
    ];

    String? lastError;

    for (final strategy in strategies) {
      final model = strategy['model']!;
      final version = strategy['version']!;

      try {
        final url =
            'https://generativelanguage.googleapis.com/$version/models/$model:generateContent?key=$_geminiApiKey';

        debugPrint('Calling Gemini: $url');

        // Get mime type from filename (supports images and PDFs)
        final mimeType = _getMimeType(_fileName);
        debugPrint('File: $_fileName, MimeType: $mimeType');

        List<Map<String, dynamic>> parts = [];
        // Gemini 1.5/2.5 Flash supports both images and PDFs
        parts.add({'text': prompt});

        if (imageBytes != null) {
          parts.add({
            'inline_data': {
              'mime_type': mimeType,
              'data': base64Encode(imageBytes),
            },
          });
        }

        final body = {
          'contents': [
            {'parts': parts},
          ],
          'safetySettings': [
            {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
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
        };

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          debugPrint('Gemini Raw Response ($model): ${response.body}');
          final result = jsonDecode(response.body);

          if (result['promptFeedback']?['blockReason'] != null) {
            throw Exception(
              'Blocked: ${result['promptFeedback']['blockReason']}',
            );
          }

          final candidates = result['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            throw Exception('No candidates returned');
          }

          final text = candidates[0]['content']?['parts']?[0]?['text'];

          if (text != null && text.isNotEmpty) {
            String cleaned = text
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();
            final start = cleaned.indexOf('{');
            final end = cleaned.lastIndexOf('}');
            if (start != -1 && end != -1 && end > start) {
              cleaned = cleaned.substring(start, end + 1);
            }
            try {
              return jsonDecode(cleaned) as Map<String, dynamic>;
            } catch (e) {
              debugPrint('JSON Parse Error ($model): $e');
              throw Exception('Invalid JSON received from AI');
            }
          }
        } else {
          final errBody = response.body;
          debugPrint(
            'Gemini HTTP Error ($model): ${response.statusCode} - $errBody',
          );
          lastError = 'HTTP ${response.statusCode}: $errBody';

          // If 404, try next model
          if (response.statusCode == 404) continue;
        }
      } catch (e) {
        debugPrint('Error with model $model: $e');
        lastError = e.toString();
      }
    }

    throw Exception(lastError ?? 'Unknown error connecting to AI');
  }

  Future<void> _analyzeReceipt() async {
    _addMessage('🔍 Analyzing your receipt... Please wait.', isAi: true);

    try {
      final prompt =
          '''Analyze this purchase receipt from a supplier (like Metro, Spar, etc.).

CRITICAL - ITEM NUMBERS:
- Every item on a receipt has an ITEM NUMBER / ARTICLE NUMBER / SKU
- It's usually a 5-8 digit number at the START of each line (e.g., "123456", "12345678")
- Sometimes it's labeled as "Art.Nr.", "Art-Nr", "Artikel", "SKU", "Item#", "Nr."
- LOOK CAREFULLY for these numbers - they are ALWAYS present on supplier receipts
- If you see a number near the item name that's NOT a price or quantity, it's likely the item number

RULES FOR QUANTITY:
- "quantity" = the COUNT of items/packs purchased (how many I bought)
- "unit" = should be "piece" if I bought individual items or packs
- The size/weight per item (like 1KG, 500ML) should stay in the raw_name

EXAMPLES:
- Line: "123456 KNOBLAUCH SAUCE 1,1L 3 ST 8,79 26,37" → item_number: "123456", raw_name: "KNOBLAUCH SAUCE 1,1L", quantity: 3, unit_price: 8.79, total_price: 26.37
- Line: "234567 MAYO TRUEFFEL 1000ML 6 6,49 38,94" → item_number: "234567", raw_name: "MAYO TRUEFFEL 1000ML", quantity: 6
- Line: "Art.Nr. 345678 CHICKEN NUGGETS 1KG 3 5,98" → item_number: "345678", raw_name: "CHICKEN NUGGETS 1KG", quantity: 3

Return JSON:
{
  "supplier_name": "string",
  "receipt_date": "YYYY-MM-DD",
  "total_amount": number,
  "items": [
    {
      "item_number": "string (the article/item number - LOOK FOR IT!)",
      "raw_name": "FULL NAME INCLUDING SIZE",
      "quantity": number (COUNT of items),
      "unit": "piece",
      "unit_price": number,
      "total_price": number
    }
  ]
}
If you can't find the item_number, set it to null but TRY HARD to find it. Do not include any markdown formatting. Just the JSON.
''';

      final parsed = await _callGeminiApi(prompt, imageBytes: _imageBytes);

      if (parsed == null) throw Exception('Failed to parse receipt');

      _detectedSupplier = parsed['supplier_name'] as String?;
      _totalReceiptAmount = (parsed['total_amount'] as num?)?.toDouble();

      // Parse items
      final items =
          (parsed['items'] as List?)
              ?.map(
                (item) => ParsedItem(
                  rawName: item['raw_name'] as String? ?? 'Unknown Item',
                  brandName: item['brand_name'] as String?,
                  itemNumber: item['item_number'] as String?,
                  quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
                  unit: item['unit'] as String? ?? 'piece',
                  unitPrice: (item['unit_price'] as num?)?.toDouble(),
                  totalPrice: (item['total_price'] as num?)?.toDouble(),
                ),
              )
              .toList() ??
          [];

      _parsedItems = items;

      setState(() => _currentStep = TrainingStep.confirmingSupplier);
      await _askSupplierConfirmation();
    } catch (e) {
      _addMessage('❌ Error analyzing receipt: $e', isAi: true);
      setState(() => _currentStep = TrainingStep.idle);
    }
  }

  Future<void> _askSupplierConfirmation() async {
    // Try to match with existing supplier
    String? matchedSupplierId;
    String? matchedSupplierName;

    if (_detectedSupplier != null) {
      for (final supplier in _availableSuppliers) {
        final name = (supplier['name'] as String).toLowerCase();
        if (_detectedSupplier!.toLowerCase().contains(name) ||
            name.contains(_detectedSupplier!.toLowerCase())) {
          matchedSupplierId = supplier['id'] as String;
          matchedSupplierName = supplier['name'] as String;
          break;
        }
      }
    }

    // Build total amount string
    final totalStr = _totalReceiptAmount != null
        ? '\n\n💰 **Total: €${_totalReceiptAmount!.toStringAsFixed(2)}**'
        : '';

    final message = matchedSupplierName != null
        ? '🏪 I detected this receipt is from **$_detectedSupplier**.\n\nI found a matching supplier in your database: **$matchedSupplierName**$totalStr\n\nIs this correct?'
        : '🏪 I detected this receipt is from **$_detectedSupplier**.$totalStr\n\nI couldn\'t find an exact match in your suppliers. Would you like to:\n• Confirm this name\n• Select a different supplier\n• Create a new supplier';

    _addMessage(
      message,
      isAi: true,
      actionWidget: _buildSupplierActions(
        matchedSupplierId,
        matchedSupplierName,
      ),
    );
  }

  Widget _buildSupplierActions(String? matchedId, String? matchedName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (matchedName != null) ...[
          ElevatedButton.icon(
            onPressed: () => _confirmSupplier(matchedId!, matchedName),
            icon: const Icon(Icons.check),
            label: Text('Yes, it\'s $matchedName'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _showSupplierPicker,
          icon: const Icon(Icons.search),
          label: const Text('Select Different Supplier'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showCreateSupplierDialog,
          icon: const Icon(Icons.add),
          label: Text('Create New Supplier "${_detectedSupplier ?? ""}"'),
        ),
      ],
    );
  }

  void _confirmSupplier(String id, String name) {
    _confirmedSupplierId = id;
    _confirmedSupplierName = name;
    _addMessage('✅ Confirmed supplier: **$name**', isAi: false);
    setState(() => _currentStep = TrainingStep.confirmingItems);
    _showItemsForConfirmation();
  }

  Future<void> _showSupplierPicker() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _SupplierPickerDialog(suppliers: _availableSuppliers),
    );
    if (result != null) {
      _confirmSupplier(result['id'] as String, result['name'] as String);
    }
  }

  Future<void> _showCreateSupplierDialog() async {
    final nameController = TextEditingController(text: _detectedSupplier);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Supplier'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Supplier Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                final resp = await _supabase
                    .from('suppliers')
                    .insert({'name': name})
                    .select('id, name')
                    .single();
                _availableSuppliers.add(resp);
                if (mounted) Navigator.pop(ctx, resp);
              } catch (e) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null) {
      _confirmSupplier(result['id'] as String, result['name'] as String);
    }
  }

  void _showItemsForConfirmation() {
    if (_parsedItems.isEmpty) {
      _addMessage(
        '❓ I couldn\'t find any items on this receipt. Would you like to try again with a different image?',
        isAi: true,
      );
      return;
    }

    // Check how many items are missing item numbers
    final itemsWithoutNumber = _parsedItems
        .where((i) => i.itemNumber == null || i.itemNumber!.isEmpty)
        .toList();
    final itemsWithNumber = _parsedItems
        .where((i) => i.itemNumber != null && i.itemNumber!.isNotEmpty)
        .toList();

    final itemsList = _parsedItems
        .map((item) {
          final itemNum = item.itemNumber != null && item.itemNumber!.isNotEmpty
              ? '[#${item.itemNumber}] '
              : '⚠️ '; // Warning icon for missing item number
          return '• $itemNum**${item.rawName}** - ${item.quantity} ${item.unit}${item.unitPrice != null ? ' @ €${item.unitPrice!.toStringAsFixed(2)}' : ''}${item.totalPrice != null ? ' = €${item.totalPrice!.toStringAsFixed(2)}' : ''}';
        })
        .join('\n');

    // Build message based on whether item numbers were found
    String message;
    if (itemsWithoutNumber.isEmpty) {
      // All items have item numbers
      message =
          '''📋 I found **${_parsedItems.length} items** on this receipt:

$itemsList

✅ All items have item numbers! Please review and approve.''';
    } else if (itemsWithNumber.isEmpty) {
      // NO items have item numbers
      message =
          '''📋 I found **${_parsedItems.length} items** on this receipt:

$itemsList

⚠️ **I couldn't find any item numbers on this receipt.**

Could you help me? On your receipt, item numbers are usually:
- 5-8 digit codes at the start of each line
- Labeled as "Art.Nr.", "SKU", or "Item#"

👉 **Click the ✏️ edit button** on each item to add its item number, or approve without them.''';
    } else {
      // Some items have numbers, some don't
      message =
          '''📋 I found **${_parsedItems.length} items** on this receipt:

$itemsList

⚠️ **${itemsWithoutNumber.length} items are missing item numbers** (marked with ⚠️)

Could you help add the missing item numbers?
👉 Click the ✏️ edit button on items marked with ⚠️''';
    }

    _addMessage(message, isAi: true, actionWidget: _buildItemsEditor());
  }

  Widget _buildItemsEditor() {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._parsedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isPiece = _isPieceUnit(item.unit);
              final hasItemNumber =
                  item.itemNumber != null && item.itemNumber!.isNotEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                // Highlight cards missing item numbers
                color: hasItemNumber ? null : Colors.amber[50],
                child: Container(
                  decoration: !hasItemNumber
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber[400]!,
                            width: 1.5,
                          ),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Item info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item number badge or missing warning
                              Row(
                                children: [
                                  if (hasItemNumber)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(
                                        bottom: 4,
                                        right: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.green[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        '#${item.itemNumber}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(
                                        bottom: 4,
                                        right: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.amber[400]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber,
                                            size: 12,
                                            color: Colors.amber[800],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'No item #',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber[900],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                item.rawName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Quantity display - always show as count
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      isPiece
                                          ? 'Qty: ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)}'
                                          : '${item.quantity} ${item.unit}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ),
                                  if (item.unitPrice != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '× €${item.unitPrice!.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Right: Total price + actions
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (item.totalPrice != null)
                              Text(
                                '€${item.totalPrice!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green[700],
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button - highlighted if missing item number
                                InkWell(
                                  onTap: () => _editItem(index, setLocalState),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: !hasItemNumber
                                        ? BoxDecoration(
                                            color: Colors.amber[200],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          )
                                        : null,
                                    child: Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: hasItemNumber
                                          ? Colors.grey[600]
                                          : Colors.amber[900],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setLocalState(
                                      () => _parsedItems.removeAt(index),
                                    );
                                    setState(() {});
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addNewItem(setLocalState),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    _addMessage(
                      '✅ Approved ${_parsedItems.length} items',
                      isAi: false,
                    );
                    setState(
                      () => _currentStep = TrainingStep.confirmingMappings,
                    );
                    _suggestMaterialMappings();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Approve Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _editItem(int index, StateSetter setLocalState) async {
    final item = _parsedItems[index];
    final itemNumCtrl = TextEditingController(text: item.itemNumber ?? '');
    final nameCtrl = TextEditingController(text: item.rawName);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final unitCtrl = TextEditingController(text: item.unit);
    final priceCtrl = TextEditingController(
      text: item.unitPrice?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemNumCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Number',
                  border: OutlineInputBorder(),
                  prefixText: '# ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit Price (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setLocalState(() {
                item.itemNumber = itemNumCtrl.text.isNotEmpty
                    ? itemNumCtrl.text
                    : null;
                item.rawName = nameCtrl.text;
                item.quantity = double.tryParse(qtyCtrl.text) ?? item.quantity;
                item.unit = unitCtrl.text;
                item.unitPrice = double.tryParse(priceCtrl.text);
              });
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addNewItem(StateSetter setLocalState) {
    setLocalState(() {
      _parsedItems.add(
        ParsedItem(rawName: 'New Item', quantity: 1, unit: 'piece'),
      );
    });
    setState(() {});
  }

  Future<void> _suggestMaterialMappings() async {
    _addMessage(
      '🔗 Now let\'s map these items to your inventory materials...',
      isAi: true,
    );

    // Common translations for fuzzy matching (German -> English, etc.)
    const translations = {
      'huehner': 'chicken',
      'hühner': 'chicken',
      'poulet': 'chicken',
      'hähnchen': 'chicken',
      'rind': 'beef',
      'rindfleisch': 'beef',
      'schwein': 'pork',
      'schweinefleisch': 'pork',
      'kartoffel': 'potato',
      'kartoffeln': 'potatoes',
      'pommes': 'fries',
      'salat': 'salad',
      'eisberg': 'iceberg',
      'zwiebel': 'onion',
      'zwiebeln': 'onions',
      'tomate': 'tomato',
      'tomaten': 'tomatoes',
      'käse': 'cheese',
      'kaese': 'cheese',
      'milch': 'milk',
      'ei': 'egg',
      'eier': 'eggs',
      'brot': 'bread',
      'brötchen': 'rolls',
      'gurke': 'cucumber',
      'gurken': 'cucumbers',
      'paprika': 'pepper',
      'pepperoni': 'pepperoni',
      'pilz': 'mushroom',
      'pilze': 'mushrooms',
      'champignon': 'mushroom',
      'mais': 'corn',
      'karotte': 'carrot',
      'karotten': 'carrots',
      'möhren': 'carrots',
      'nuggets': 'nuggets',
      'nugget': 'nugget',
      'sauce': 'sauce',
      'soße': 'sauce',
      'sosse': 'sauce',
      'mayo': 'mayonnaise',
      'mayonaise': 'mayonnaise',
      'ketchup': 'ketchup',
      'ketschup': 'ketchup',
      'senf': 'mustard',
      'öl': 'oil',
      'oel': 'oil',
      'essig': 'vinegar',
      'zucker': 'sugar',
      'salz': 'salt',
      'meersalz': 'sea salt',
      'pfeffer': 'pepper',
      'wasser': 'water',
      'cola': 'cola',
      'kola': 'cola',
      'saft': 'juice',
      'bier': 'beer',
      'wein': 'wine',
      'fisch': 'fish',
      'lachs': 'salmon',
      'thunfisch': 'tuna',
      'garnelen': 'shrimp',
      'shrimps': 'shrimp',
    };

    // For mapping suggestions, we'll try to find exact matches first from previous training
    // Then use fuzzy matching with translations

    try {
      for (final item in _parsedItems) {
        // 1. Check aliases first (exact match)
        final aliasResp = await _supabase
            .from('purchase_item_aliases')
            .select('material_id, conversion_ratio, unit')
            .eq('supplier_id', _confirmedSupplierId!)
            .eq('raw_name', item.rawName.toLowerCase())
            .maybeSingle();

        if (aliasResp != null) {
          final materialId = aliasResp['material_id'] as String?;
          if (materialId != null) {
            final material = _availableMaterials.firstWhere(
              (m) => m['id'] == materialId,
              orElse: () => {},
            );

            if (material.isNotEmpty) {
              item.materialId = materialId;
              item.materialName = material['name'];
              item.baseUnit = material['unit_of_measure'];
              item.conversionRatio =
                  (aliasResp['conversion_ratio'] as num?)?.toDouble() ?? 1.0;
              _initExtractedValues(item);
              continue;
            }
          }
        }

        // 2. Enhanced fuzzy matching with translations
        final rawName = item.rawName.toLowerCase();
        final rawWords = rawName.split(RegExp(r'[\s.,]+'));

        // Translate raw words
        final translatedWords = rawWords
            .map((w) => translations[w] ?? w)
            .toList();
        final translatedName = translatedWords.join(' ');

        double bestScore = 0;
        Map<String, dynamic>? bestMatch;

        for (final mat in _availableMaterials) {
          final matName = (mat['name'] as String).toLowerCase();
          final matWords = matName.split(RegExp(r'[\s.,]+'));

          // Also translate material name words
          final matTranslated = matWords
              .map((w) => translations[w] ?? w)
              .toList();

          double score = 0;

          // Direct contains check
          if (rawName.contains(matName) || matName.contains(rawName)) {
            score = 0.8;
          }

          // Translated contains check
          if (translatedName.contains(matName) ||
              matName.contains(translatedName)) {
            score = max(score, 0.7);
          }

          // Word matching (original and translated)
          int wordMatches = 0;
          for (final word in translatedWords) {
            if (word.length < 3) continue; // Skip short words
            for (final matWord in matTranslated) {
              if (matWord.length < 3) continue;
              if (word.contains(matWord) || matWord.contains(word)) {
                wordMatches++;
                break;
              }
            }
          }

          if (wordMatches > 0) {
            final wordScore =
                wordMatches / max(translatedWords.length, matTranslated.length);
            score = max(score, wordScore * 0.6);
          }

          if (score > bestScore && score >= 0.3) {
            bestScore = score;
            bestMatch = mat;
          }
        }

        if (bestMatch != null) {
          item.materialId = bestMatch['id'];
          item.materialName = bestMatch['name'];
          item.baseUnit = bestMatch['unit_of_measure'];
          item.conversionRatio = 1.0;
        }

        // Initialize extracted per-piece values for all items
        _initExtractedValues(item);
      }

      setState(() {});
      _showMappingsForConfirmation();
    } catch (e) {
      debugPrint('Error suggesting mappings: $e');
      _showMappingsForConfirmation();
    }
  }

  void _showMappingsForConfirmation() {
    final mapped = _parsedItems.where((i) => i.materialId != null).length;
    final unmapped = _parsedItems.length - mapped;

    _addMessage(
      '''🎯 I've suggested material mappings:
• **$mapped** items matched to materials
• **$unmapped** items need manual mapping

Review and adjust the mappings below:''',
      isAi: true,
      actionWidget: _buildMappingsEditor(),
    );
  }

  Widget _buildMappingsEditor() {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._parsedItems.map((item) {
              final hasMapping = item.materialId != null;
              final qtyToAdd = hasMapping ? _calculateQtyToAdd(item) : 0.0;
              final isPieceUnit = _isPieceUnit(item.unit);
              final hasExtracted =
                  item.extractedPerPieceQty != null &&
                  item.extractedPerPieceUnit != null;

              // Get material image if mapped
              String? materialImageUrl;
              if (hasMapping) {
                final material = _availableMaterials.firstWhere(
                  (m) => m['id'] == item.materialId,
                  orElse: () => {},
                );
                materialImageUrl = material['item_image_url'] as String?;
              }

              // Determine default unit for per-piece dropdown based on material base unit
              String defaultUnit = 'g';
              if (hasMapping && item.baseUnit != null) {
                if (_isVolumeUnit(item.baseUnit!)) {
                  defaultUnit = 'ml';
                } else if (_isWeightUnit(item.baseUnit!)) {
                  defaultUnit = 'g';
                }
              }

              // Calculate price per base unit
              String? pricePerBaseUnit;
              if (hasMapping && item.totalPrice != null && qtyToAdd > 0) {
                final pricePerUnit = item.totalPrice! / qtyToAdd;
                final baseUnit = item.baseUnit ?? item.unit;
                // Always show per 1000 for small units
                if (_isWeightUnit(baseUnit) && baseUnit.toLowerCase() != 'kg') {
                  pricePerBaseUnit =
                      '€${(pricePerUnit * 1000).toStringAsFixed(2)}/kg';
                } else if (_isVolumeUnit(baseUnit) &&
                    baseUnit.toLowerCase() != 'l') {
                  pricePerBaseUnit =
                      '€${(pricePerUnit * 1000).toStringAsFixed(2)}/L';
                } else {
                  pricePerBaseUnit =
                      '€${pricePerUnit.toStringAsFixed(3)}/$baseUnit';
                }
              }

              // Get extracted info for display
              double? perPieceQty = item.extractedPerPieceQty;
              String? perPieceUnit = item.extractedPerPieceUnit;
              if (perPieceQty == null || perPieceUnit == null) {
                final extracted = _extractQtyFromName(item.rawName);
                if (extracted != null) {
                  perPieceQty = extracted.$1;
                  perPieceUnit = extracted.$2;
                }
              }

              // Build calculation string
              String calculationStr = '';
              final isMaterialPieceUnit =
                  hasMapping && _isPieceUnit(item.baseUnit ?? '');

              if (hasMapping && isMaterialPieceUnit) {
                // Piece to piece - simple
                calculationStr =
                    '${item.quantity.toStringAsFixed(0)} ${item.unit} → ${_formatQty(qtyToAdd)} ${item.baseUnit}';
              } else if (hasMapping &&
                  perPieceQty != null &&
                  perPieceUnit != null &&
                  isPieceUnit) {
                calculationStr =
                    '${item.quantity.toStringAsFixed(0)} × ${_formatEditQty(perPieceQty)}$perPieceUnit = ${_formatQty(qtyToAdd)} ${item.baseUnit ?? 'units'}';
              } else if (hasMapping) {
                calculationStr =
                    '${item.quantity} ${item.unit} → ${_formatQty(qtyToAdd)} ${item.baseUnit ?? item.unit}';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasMapping
                          ? Colors.green[300]!
                          : Colors.orange[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Item name + Total Price
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: hasMapping
                              ? Colors.green[50]
                              : Colors.orange[50],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.rawName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Quantity badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      'Qty: ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${isPieceUnit ? 'pcs' : item.unit}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Total price on the right
                            if (item.totalPrice != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '€${item.totalPrice!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  if (item.unitPrice != null)
                                    Text(
                                      '€${item.unitPrice!.toStringAsFixed(2)}/pc',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (pricePerBaseUnit != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        pricePerBaseUnit,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple[800],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      // Material selection with image
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: InkWell(
                          onTap: () => _pickMaterial(item, setLocalState),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                // Material image or icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: hasMapping
                                        ? Colors.green[50]
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      hasMapping &&
                                          materialImageUrl != null &&
                                          materialImageUrl.isNotEmpty
                                      ? Image.network(
                                          materialImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.inventory_2,
                                            color: Colors.green[600],
                                            size: 22,
                                          ),
                                        )
                                      : Icon(
                                          hasMapping
                                              ? Icons.inventory_2
                                              : Icons.add_link,
                                          color: hasMapping
                                              ? Colors.green[600]
                                              : Colors.grey[400],
                                          size: 22,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasMapping
                                            ? item.materialName!
                                            : 'Tap to link material...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: hasMapping
                                              ? Colors.green[800]
                                              : Colors.grey[500],
                                        ),
                                      ),
                                      if (hasMapping && item.baseUnit != null)
                                        Text(
                                          'Unit: ${item.baseUnit}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Editable per-piece quantity (ONLY when receipt unit is "piece" AND material needs conversion)
                      // Don't show if material unit is also "piece" - no conversion needed!
                      if (hasMapping &&
                          isPieceUnit &&
                          !_isPieceUnit(item.baseUnit ?? '')) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.straighten,
                                      size: 14,
                                      color: Colors.amber[800],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Size per piece (edit if wrong):',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber[900],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        initialValue: hasExtracted
                                            ? _formatEditQty(
                                                item.extractedPerPieceQty!,
                                              )
                                            : '',
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 1.1',
                                          isDense: true,
                                          border: const OutlineInputBorder(),
                                          fillColor: Colors.white,
                                          filled: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 10,
                                              ),
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (v) {
                                          item.extractedPerPieceQty =
                                              double.tryParse(
                                                v.replaceAll(',', '.'),
                                              );
                                          setLocalState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          fillColor: Colors.white,
                                          filled: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                        ),
                                        value:
                                            item.extractedPerPieceUnit ??
                                            defaultUnit,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        isExpanded: true,
                                        items:
                                            [
                                                  'g',
                                                  'kg',
                                                  'ml',
                                                  'L',
                                                  'cl',
                                                  'piece',
                                                ]
                                                .map(
                                                  (u) => DropdownMenuItem(
                                                    value: u,
                                                    child: Text(u),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (v) {
                                          item.extractedPerPieceUnit = v;
                                          setLocalState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Calculation and result
                      if (hasMapping) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Calculation row
                              if (calculationStr.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calculate,
                                      size: 14,
                                      color: Colors.blue[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        calculationStr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 6),
                              // Will add row
                              Row(
                                children: [
                                  Icon(
                                    Icons.add_circle,
                                    size: 18,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Will add: ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  Text(
                                    '${_formatQty(qtyToAdd)} ${item.baseUnit ?? item.unit}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() => _currentStep = TrainingStep.idle);
                    _addMessage(
                      '❌ Training cancelled. Upload a new receipt to try again.',
                      isAi: true,
                    );
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saveTrainingData,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Training'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Format quantity for editing (no thousands separator)
  String _formatEditQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toStringAsFixed(0);
    } else {
      return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    }
  }

  Future<void> _pickMaterial(ParsedItem item, StateSetter setLocalState) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _MaterialPickerDialog(
        materials: _availableMaterials,
        initialQuery: item.rawName,
        supplierName:
            _confirmedSupplierName, // Pass supplier name for auto-fill
      ),
    );
    if (result != null) {
      // If this is a newly created material, add it to available materials for other items
      if (!_availableMaterials.any((m) => m['id'] == result['id'])) {
        _availableMaterials.add(result);
      }

      setLocalState(() {
        item.materialId = result['id'] as String;
        item.materialName = result['name'] as String;
        item.baseUnit = result['unit_of_measure'] as String?;
        item.conversionRatio ??= 1.0;

        // Initialize extracted per-piece values
        _initExtractedValues(item);
      });
      setState(() {});
    }
  }

  Future<void> _saveTrainingData() async {
    setState(() => _currentStep = TrainingStep.saving);
    _addMessage('💾 Saving training data...', isAi: true);

    try {
      // Build detailed item data for retrieval later (stored in parsed_items)
      final itemsData = _parsedItems
          .map(
            (i) => {
              'raw_name': i.rawName,
              'item_number': i.itemNumber,
              'quantity': i.quantity,
              'unit': i.unit,
              'unit_price': i.unitPrice,
              'total_price': i.totalPrice,
              'material_id': i.materialId,
              'material_name': i.materialName,
              'conversion_ratio': i.conversionRatio,
            },
          )
          .toList();

      // Save to ai_training_samples table
      final trainingData = {
        'supplier_id': _confirmedSupplierId,
        'supplier_name': _confirmedSupplierName,
        'receipt_image_hash': _imageBytes.hashCode.toString(),
        'parsed_items': itemsData, // Full item data with prices
        'item_mappings': _parsedItems
            .where((i) => i.materialId != null)
            .map(
              (i) => {
                'raw_name': i.rawName,
                'material_id': i.materialId,
                'conversion_ratio': i.conversionRatio,
              },
            )
            .toList(),
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('ai_training_samples').insert(trainingData);

      // Also save item aliases for future matching
      for (final item in _parsedItems.where((i) => i.materialId != null)) {
        try {
          await _supabase.from('purchase_item_aliases').upsert({
            'supplier_id': _confirmedSupplierId,
            'raw_name': item.rawName.toLowerCase(),
            'material_id': item.materialId,
            'conversion_ratio': item.conversionRatio ?? 1.0,
            'unit': item.unit,
          }, onConflict: 'supplier_id, raw_name');
        } catch (e) {
          debugPrint('Error saving alias: $e');
        }

        // Also save/update purchase_catalog_items for linking in material details
        try {
          // Calculate qty to add to get proper conversion ratio
          final qtyToAdd = _calculateQtyToAdd(item);
          final effectiveConversion = item.quantity > 0
              ? qtyToAdd / item.quantity
              : 1.0;

          // First, check if this catalog item already exists
          final existing = await _supabase
              .from('purchase_catalog_items')
              .select('id')
              .eq('supplier_id', _confirmedSupplierId!)
              .eq('name', item.rawName)
              .maybeSingle();

          if (existing != null) {
            // Update existing record (without item_number as it doesn't exist in table)
            await _supabase
                .from('purchase_catalog_items')
                .update({
                  'material_id': item.materialId,
                  'base_unit': item.baseUnit ?? item.unit,
                  'conversion_ratio': effectiveConversion,
                })
                .eq('id', existing['id']);
            debugPrint(
              'Updated purchase_catalog_item: ${item.rawName} -> material ${item.materialId}',
            );
          } else {
            // Insert new record (without item_number as it doesn't exist in table)
            await _supabase.from('purchase_catalog_items').insert({
              'name': item.rawName,
              'supplier_id': _confirmedSupplierId,
              'material_id': item.materialId,
              'base_unit': item.baseUnit ?? item.unit,
              'conversion_ratio': effectiveConversion,
            });
            debugPrint(
              'Inserted purchase_catalog_item: ${item.rawName} -> material ${item.materialId}',
            );
          }
        } catch (e) {
          debugPrint('Error saving purchase_catalog_item: $e');
          // Show error in chat for debugging
          _addMessage(
            '⚠️ Note: Could not link "${item.rawName}" to catalog: $e',
            isAi: true,
          );
        }
      }

      // Count how many were actually linked and collect unique materials
      int linkedCount = 0;
      final Map<String, Map<String, dynamic>> linkedMaterials =
          {}; // materialId -> material data

      for (final item in _parsedItems.where((i) => i.materialId != null)) {
        // Verify it was saved
        try {
          final check = await _supabase
              .from('purchase_catalog_items')
              .select('id')
              .eq('material_id', item.materialId!)
              .eq('name', item.rawName)
              .maybeSingle();
          if (check != null) {
            linkedCount++;
            // Store material info for buttons
            if (!linkedMaterials.containsKey(item.materialId)) {
              final materialData = _availableMaterials.firstWhere(
                (m) => m['id'] == item.materialId,
                orElse: () => {
                  'id': item.materialId,
                  'name': item.materialName ?? 'Unknown',
                },
              );
              linkedMaterials[item.materialId!] = materialData;
            }
          }
        } catch (_) {}
      }

      _trainingCount++;

      setState(() => _currentStep = TrainingStep.complete);

      // Build success message
      String successMsg =
          '''✅ **Training data saved successfully!**

📊 Total training samples: $_trainingCount
🔗 **$linkedCount items linked** to **${linkedMaterials.length} materials**

${_trainingCount < 50 ? '💡 Keep training! ${50 - _trainingCount} more samples recommended.' : '🎉 Great job! You have enough training data.'}

Upload another receipt to continue training!''';

      // Create navigation buttons for linked materials
      Widget? actionWidget;
      if (linkedMaterials.isNotEmpty) {
        actionWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '👉 View linked items for each material:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: linkedMaterials.entries.map((entry) {
                final materialData = entry.value;
                final materialName =
                    materialData['name'] as String? ?? 'Unknown';
                return ElevatedButton.icon(
                  onPressed: () => _navigateToMaterialLinkedItems(materialData),
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(
                    materialName.length > 20
                        ? '${materialName.substring(0, 20)}...'
                        : materialName,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }

      _addMessage(successMsg, isAi: true, actionWidget: actionWidget);

      // Reset for next receipt
      _imageBytes = null;
      _fileName = null;
      _parsedItems = [];
      _detectedSupplier = null;
      _confirmedSupplierId = null;
      _confirmedSupplierName = null;
      _totalReceiptAmount = null;
      setState(() => _currentStep = TrainingStep.idle);
    } catch (e) {
      _addMessage('❌ Error saving training data: $e', isAi: true);
      setState(() => _currentStep = TrainingStep.confirmingMappings);
    }
  }

  /// Navigate to the Material History Screen with Linked Items tab open
  void _navigateToMaterialLinkedItems(Map<String, dynamic> materialData) {
    // Create a MaterialItem from the data
    final materialItem = MaterialItem(
      id: materialData['id'] as String,
      name: materialData['name'] as String? ?? 'Unknown',
      createdAt:
          DateTime.tryParse(materialData['created_at'] as String? ?? '') ??
          DateTime.now(),
      category: materialData['category'] as String? ?? 'UNKNOWN',
      unitOfMeasure: materialData['unit_of_measure'] as String? ?? 'piece',
      currentQuantity:
          (materialData['current_quantity'] as num?)?.toDouble() ?? 0,
      notifyWhenQuantity: (materialData['notify_when_quantity'] as num?)
          ?.toDouble(),
      itemImageUrl: materialData['item_image_url'] as String?,
      weightedAverageCost: (materialData['average_unit_cost'] as num?)
          ?.toDouble(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaterialHistoryScreen(
          materialItem: materialItem,
          initialTab: 1, // Open Linked Items tab
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase AI Trainer'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        actions: [
          // Restart button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart Chat',
            onPressed: _restartChat,
          ),
          // Copy chat button
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy chat to clipboard',
            onPressed: _exportChat,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology, size: 16),
                const SizedBox(width: 6),
                Text('$_trainingCount samples'),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) =>
                    _buildChatMessage(_messages[index]),
              ),
            ),
          ),

          // Input area with text field
          _buildInputArea(),
        ],
      ),
    );
  }

  final TextEditingController _chatInputController = TextEditingController();
  bool _isSendingMessage = false;

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show uploaded image/PDF preview
          if (_imageBytes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                      color: Colors.grey[100],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _fileName?.toLowerCase().endsWith('.pdf') == true
                          ? Center(
                              child: Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red[400],
                                size: 24,
                              ),
                            )
                          : Image.memory(_imageBytes!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fileName ?? 'Receipt uploaded',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _imageBytes = null;
                        _fileName = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Text input row
          Row(
            children: [
              // Restart button
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.grey[600]),
                tooltip: 'Restart Chat',
                onPressed: _restartChat,
              ),
              // Upload button
              IconButton(
                icon: Icon(Icons.attach_file, color: Colors.purple[600]),
                tooltip: 'Upload Receipt',
                onPressed:
                    _currentStep == TrainingStep.idle ||
                        _currentStep == TrainingStep.complete
                    ? _pickImage
                    : null,
              ),
              // Text field
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  decoration: InputDecoration(
                    hintText: _currentStep == TrainingStep.idle
                        ? 'Upload a receipt or type a message...'
                        : 'Type a message or correction...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Colors.purple[400]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              Container(
                decoration: BoxDecoration(
                  color: Colors.purple[600],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isSendingMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isSendingMessage ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _restartChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Chat?'),
        content: const Text(
          'This will clear all messages and start fresh. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _imageBytes = null;
                _fileName = null;
                _parsedItems = [];
                _detectedSupplier = null;
                _confirmedSupplierId = null;
                _confirmedSupplierName = null;
                _totalReceiptAmount = null;
                _currentStep = TrainingStep.idle;
                _chatInputController.clear();
              });
              _addWelcomeMessage();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty && _imageBytes == null) return;

    _chatInputController.clear();

    // Add user message
    if (text.isNotEmpty) {
      _addMessage(text, isAi: false);
    }

    // If we have an image and are idle, start analysis
    if (_imageBytes != null && _currentStep == TrainingStep.idle) {
      setState(() => _currentStep = TrainingStep.analyzingReceipt);
      await _analyzeReceipt();
      return;
    }

    // Handle corrections or questions during the flow
    if (text.isNotEmpty) {
      setState(() => _isSendingMessage = true);

      // Try to interpret the user message based on current step
      if (_currentStep == TrainingStep.confirmingSupplier) {
        // User might be correcting the total or supplier
        if (text.toLowerCase().contains('total') ||
            text.contains('€') ||
            text.contains('euro')) {
          // Try to extract a number
          final numMatch = RegExp(
            r'[\d,.]+',
          ).firstMatch(text.replaceAll(' ', ''));
          if (numMatch != null) {
            final correctedTotal = double.tryParse(
              numMatch.group(0)!.replaceAll(',', '.'),
            );
            if (correctedTotal != null) {
              _totalReceiptAmount = correctedTotal;
              _addMessage(
                '✅ Got it! I\'ve updated the total to **€${correctedTotal.toStringAsFixed(2)}**',
                isAi: true,
              );
            }
          }
        } else {
          _addMessage(
            '👍 Thanks for the info! Please use the buttons above to confirm or select the supplier.',
            isAi: true,
          );
        }
      } else if (_currentStep == TrainingStep.confirmingItems) {
        _addMessage(
          '💡 Use the edit buttons on each item card to make corrections, then click "Approve Items" when done.',
          isAi: true,
        );
      } else if (_currentStep == TrainingStep.confirmingMappings) {
        _addMessage(
          '💡 Click on items to change their material mapping, or edit the size per piece if wrong. Then click "Save Training" when ready.',
          isAi: true,
        );
      } else {
        // Default response
        _addMessage(
          '👋 Upload a receipt image or PDF to get started! I\'ll help you analyze it and map items to your inventory.',
          isAi: true,
        );
      }

      setState(() => _isSendingMessage = false);
    }
  }

  Widget _buildChatMessage(ChatMessage message) {
    return Align(
      alignment: message.isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: message.isAi ? Colors.white : Colors.purple[100],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.isAi ? Icons.psychology : Icons.person,
                  size: 16,
                  color: message.isAi ? Colors.purple[600] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  message.isAi ? 'AI Assistant' : 'You',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat.Hm().format(message.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildFormattedText(message.text),
            if (message.actionWidget != null) ...[
              const SizedBox(height: 12),
              message.actionWidget!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(String text) {
    // Simple markdown-like formatting
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('• ')) {
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: _buildRichText(line.substring(2))),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _buildRichText(line),
        );
      }).toList(),
    );
  }

  Widget _buildRichText(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          height: 1.4,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

// Supplier Picker Dialog
class _SupplierPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> suppliers;
  const _SupplierPickerDialog({required this.suppliers});

  @override
  State<_SupplierPickerDialog> createState() => _SupplierPickerDialogState();
}

class _SupplierPickerDialogState extends State<_SupplierPickerDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.suppliers;
  }

  void _filter(String query) {
    setState(() {
      _filtered = widget.suppliers
          .where(
            (s) => (s['name'] as String).toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400,
        height: 500,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Supplier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search suppliers...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _filter,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final supplier = _filtered[i];
                    return ListTile(
                      title: Text(supplier['name'] as String),
                      onTap: () => Navigator.pop(context, supplier),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Material Picker Dialog with Create New option
class _MaterialPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  final String initialQuery;
  final String? supplierName; // Auto-fill in create dialog
  const _MaterialPickerDialog({
    required this.materials,
    required this.initialQuery,
    this.supplierName,
  });

  @override
  State<_MaterialPickerDialog> createState() => _MaterialPickerDialogState();
}

class _MaterialPickerDialogState extends State<_MaterialPickerDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  // Categories list (same as inventory_screen.dart)
  final List<String> _categories = [
    'DRINKS',
    'MEAT',
    'BREAD',
    'FRUITS AND VEGETABLES',
    'SAUCES',
    'PACKAGING',
    'FINGERFOOD',
    'DESSERTS',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _filter(widget.initialQuery);
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.materials.take(50).toList();
      } else {
        _filtered = widget.materials
            .where(
              (m) => (m['name'] as String).toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .take(50)
            .toList();
      }
    });
  }

  Future<void> _showCreateMaterialDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CreateMaterialDialog(
        initialName: _searchController.text,
        categories: _categories,
        supplierName: widget.supplierName,
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 500,
        height: 650,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Material',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search materials...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _filter,
              ),
              const SizedBox(height: 12),

              // Create New Material Button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: _showCreateMaterialDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(
                    _searchController.text.isNotEmpty
                        ? 'Create New Material "${_searchController.text}"'
                        : 'Create New Material',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // Results count
              if (_filtered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_filtered.length} materials found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),

              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No materials found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a new material using the button above',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final material = _filtered[i];
                          final imageUrl =
                              material['item_image_url'] as String?;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.inventory_2,
                                          color: Colors.green[600],
                                          size: 24,
                                        ),
                                      )
                                    : Icon(
                                        Icons.inventory_2,
                                        color: Colors.green[600],
                                        size: 24,
                                      ),
                              ),
                              title: Text(
                                material['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${material['unit_of_measure'] ?? 'N/A'} • ${material['category'] ?? 'No category'}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                              onTap: () => Navigator.pop(context, material),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Create Material Dialog
class _CreateMaterialDialog extends StatefulWidget {
  final String initialName;
  final List<String> categories;
  final String? supplierName; // Auto-fill seller name

  const _CreateMaterialDialog({
    required this.initialName,
    required this.categories,
    this.supplierName,
  });

  @override
  State<_CreateMaterialDialog> createState() => _CreateMaterialDialogState();
}

class _CreateMaterialDialogState extends State<_CreateMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _sellerController;
  late TextEditingController _itemNumberController;

  String? _selectedCategory;
  String _selectedUnit = 'gram';
  bool _isLoading = false;

  final List<String> _units = [
    'piece',
    'gram',
    'kg',
    'ml',
    'liter',
    'bottle',
    'can',
    'pack',
    'box',
    'carton',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _quantityController = TextEditingController(text: '0');
    _sellerController = TextEditingController(text: widget.supplierName ?? '');
    _itemNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _sellerController.dispose();
    _itemNumberController.dispose();
    super.dispose();
  }

  Future<void> _createMaterial() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('material')
          .insert({
            'name': _nameController.text.trim(),
            'current_quantity': double.tryParse(_quantityController.text) ?? 0,
            'unit_of_measure': _selectedUnit,
            'category': _selectedCategory,
            'seller_name': _sellerController.text.isNotEmpty
                ? _sellerController.text
                : null,
            'item_number': _itemNumberController.text.isNotEmpty
                ? _itemNumberController.text
                : null,
          })
          .select('id, name, unit_of_measure, category, item_image_url')
          .single();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Material "${_nameController.text}" created successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, response);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.add_box,
                          color: Colors.green[600],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create New Material',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Add a new inventory item',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Material Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Category
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: widget.categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                    validator: (v) => v == null ? 'Category is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Quantity and Unit row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Initial Quantity',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit *',
                            border: OutlineInputBorder(),
                          ),
                          items: _units
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedUnit = v ?? 'piece'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Seller (auto-filled from supplier)
                  TextFormField(
                    controller: _sellerController,
                    decoration: InputDecoration(
                      labelText: 'Seller/Supplier Name',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.store_outlined),
                      helperText: widget.supplierName != null
                          ? 'Auto-filled from receipt'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Item Number (optional)
                  TextFormField(
                    controller: _itemNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Item Number (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createMaterial,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _isLoading ? 'Creating...' : 'Create Material',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
