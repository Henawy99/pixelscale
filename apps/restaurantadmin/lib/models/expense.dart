/// A scanned supplier invoice / receipt (table `purchases`) and its lines (`purchase_items`).
class Expense {
  final String id;
  final DateTime createdAt;
  final String status; // analyzing | needs_review | booked | failed (older rows: pending_review | approved)
  final String? supplierId;
  final String? supplierName;
  final String? invoiceNumber;
  final DateTime? receiptDate;
  final double? totalAmount;
  final double? netAmount;
  final double? vatAmount;
  final String currency;
  final List<String> documentPaths;
  final Map<String, dynamic>? analysis;
  final String? error;
  final DateTime? bookedAt;
  final int lineCount;

  const Expense({
    required this.id,
    required this.createdAt,
    required this.status,
    this.supplierId,
    this.supplierName,
    this.invoiceNumber,
    this.receiptDate,
    this.totalAmount,
    this.netAmount,
    this.vatAmount,
    this.currency = 'EUR',
    this.documentPaths = const [],
    this.analysis,
    this.error,
    this.bookedAt,
    this.lineCount = 0,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final items = json['purchase_items'];
    return Expense(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String? ?? 'needs_review',
      supplierId: json['supplier_id'] as String?,
      supplierName: json['supplier_name'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      receiptDate: DateTime.tryParse(json['receipt_date'] as String? ?? ''),
      totalAmount: _num(json['total_amount']),
      netAmount: _num(json['net_amount']),
      vatAmount: _num(json['vat_amount']),
      currency: json['currency'] as String? ?? 'EUR',
      documentPaths: ((json['document_paths'] as List?) ?? const []).cast<String>(),
      analysis: json['analysis'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      bookedAt: DateTime.tryParse(json['booked_at'] as String? ?? ''),
      lineCount: items is List && items.isNotEmpty ? ((items.first as Map)['count'] as int? ?? 0) : 0,
    );
  }

  bool get isAnalyzing => status == 'analyzing';
  bool get isFailed => status == 'failed';
  bool get isBooked => status == 'booked' || status == 'approved';
  bool get needsReview => status == 'needs_review';

  /// Made by the previous scanner (no supplier, no document). Shown, but not counted as work to do.
  bool get isLegacyScan => status == 'pending_review';

  /// Date shown for the expense: the invoice date, else when it was scanned.
  DateTime get date => receiptDate ?? createdAt;

  Map<String, dynamic>? get detectedSupplier {
    final document = analysis?['document'] as Map<String, dynamic>?;
    return document?['supplier'] as Map<String, dynamic>?;
  }

  Map<String, dynamic>? get _supplierMatch => analysis?['supplier_match'] as Map<String, dynamic>?;

  /// matched | suggested | unknown (null for expenses that were not scanned).
  String? get supplierMatchStatus => _supplierMatch?['status'] as String?;

  String? get suggestedSupplierId {
    if (supplierMatchStatus != 'suggested') return null;
    return _supplierMatch?['supplier_id'] as String?;
  }

  List<ExpenseWarning> get warnings => ((analysis?['warnings'] as List?) ?? const [])
      .map((w) => ExpenseWarning(code: (w as Map)['code'] as String? ?? '', message: w['message'] as String? ?? ''))
      .toList();
}

class ExpenseWarning {
  final String code;
  final String message;
  const ExpenseWarning({required this.code, required this.message});
}

/// One invoice line and how it goes into stock.
class ExpenseLine {
  final String id;
  final int? position;
  final String rawName;
  final String? articleNumber;
  final double? quantity;
  final String? unit;
  final double? unitPrice;
  final double? totalPrice;
  final double? vatRate;
  final String kind; // product | deposit | empties_return | fee | discount | other
  final double? contentPerUnit;
  final String? contentUnit; // g | ml | piece
  final String? materialId;
  final double? conversionRatio; // material units in ONE purchased unit
  final String? matchSource; // catalog | ai | manual
  final double? matchConfidence;
  final bool stock;
  final bool booked;
  final double? baseQuantity;
  final MaterialSuggestion? suggestion;

  const ExpenseLine({
    required this.id,
    this.position,
    required this.rawName,
    this.articleNumber,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.totalPrice,
    this.vatRate,
    this.kind = 'product',
    this.contentPerUnit,
    this.contentUnit,
    this.materialId,
    this.conversionRatio,
    this.matchSource,
    this.matchConfidence,
    this.stock = false,
    this.booked = false,
    this.baseQuantity,
    this.suggestion,
  });

  factory ExpenseLine.fromJson(Map<String, dynamic> json) {
    final s = json['suggestion'] as Map<String, dynamic>?;
    return ExpenseLine(
      id: json['id'] as String,
      position: json['position'] as int?,
      rawName: json['raw_name'] as String? ?? '',
      articleNumber: json['item_number'] as String?,
      quantity: _num(json['quantity']),
      unit: json['unit'] as String?,
      unitPrice: _num(json['unit_price']),
      totalPrice: _num(json['total_item_price']),
      vatRate: _num(json['vat_rate']),
      kind: json['kind'] as String? ?? 'product',
      contentPerUnit: _num(json['content_per_unit']),
      contentUnit: json['content_unit'] as String?,
      materialId: json['material_id'] as String?,
      conversionRatio: _num(json['conversion_ratio']),
      matchSource: json['match_source'] as String?,
      matchConfidence: _num(json['match_confidence']),
      stock: json['stock'] as bool? ?? false,
      booked: json['booked'] as bool? ?? false,
      baseQuantity: _num(json['base_quantity']),
      suggestion: s == null || s['name'] == null
          ? null
          : MaterialSuggestion(
              name: s['name'] as String,
              unit: s['unit'] as String?,
              category: s['category'] as String?,
            ),
    );
  }

  bool get isProduct => kind == 'product';

  String get kindLabel => switch (kind) {
    'deposit' => 'Deposit',
    'empties_return' => 'Empties returned',
    'fee' => 'Fee',
    'discount' => 'Discount',
    'other' => 'Other',
    _ => 'Product',
  };
}

class MaterialSuggestion {
  final String name;
  final String? unit; // gram | ml | piece
  final String? category;
  const MaterialSuggestion({required this.name, this.unit, this.category});
}

/// The reviewer's decision for one line before booking.
class LineDecision {
  String? materialId;
  double? conversionRatio;
  bool stock;
  LineDecision({this.materialId, this.conversionRatio, required this.stock});

  bool get isReady => stock && materialId != null && (conversionRatio ?? 0) > 0;
}

/// Minimal material info the expense screens need.
class StockMaterial {
  final String id;
  final String name;
  final String unit; // gram | ml | piece
  final String? category;
  final double currentQuantity;

  const StockMaterial({
    required this.id,
    required this.name,
    required this.unit,
    this.category,
    this.currentQuantity = 0,
  });

  factory StockMaterial.fromJson(Map<String, dynamic> json) => StockMaterial(
    id: json['id'] as String,
    name: (json['name'] as String? ?? '').trim(),
    unit: json['unit_of_measure'] as String? ?? 'piece',
    category: json['category'] as String?,
    currentQuantity: _num(json['current_quantity']) ?? 0,
  );
}

class SupplierOption {
  final String id;
  final String name;
  final String? city;
  const SupplierOption({required this.id, required this.name, this.city});

  factory SupplierOption.fromJson(Map<String, dynamic> json) =>
      SupplierOption(id: json['id'] as String, name: json['name'] as String? ?? '', city: json['city'] as String?);
}

double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
