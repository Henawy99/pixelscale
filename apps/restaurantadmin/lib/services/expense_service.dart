import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:restaurantadmin/models/expense.dart';

/// Scanning, reviewing and booking supplier invoices into inventory.
class ExpenseService {
  ExpenseService([SupabaseClient? client]) : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;
  static const String bucket = 'scanned-receipts';

  static const List<String> materialUnits = ['gram', 'ml', 'piece'];
  static const List<String> materialCategories = [
    'DRINKS',
    'MEAT',
    'BREAD',
    'FRUITS AND VEGETABLES',
    'DAIRY',
    'SAUCES',
    'DRY GOODS',
    'FINGERFOOD',
    'DESSERTS',
    'PACKAGING',
    'SUPPLIES',
  ];

  // ---------------------------------------------------------------- reading

  Future<List<Expense>> fetchExpenses({int limit = 200}) async {
    final rows = await _db
        .from('purchases')
        .select('*, purchase_items(count)')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => Expense.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Expense> fetchExpense(String id) async {
    final row = await _db.from('purchases').select('*, purchase_items(count)').eq('id', id).single();
    return Expense.fromJson(row);
  }

  Future<List<ExpenseLine>> fetchLines(String expenseId) async {
    final rows = await _db
        .from('purchase_items')
        .select()
        .eq('purchase_id', expenseId)
        .order('position', ascending: true, nullsFirst: false)
        .order('created_at');
    return (rows as List).map((r) => ExpenseLine.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<StockMaterial>> fetchMaterials() async {
    final rows = await _db
        .from('material')
        .select('id, name, unit_of_measure, category, current_quantity')
        .order('name');
    return (rows as List).map((r) => StockMaterial.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<SupplierOption>> fetchSuppliers() async {
    final rows = await _db.from('suppliers').select('id, name, city').order('name');
    return (rows as List).map((r) => SupplierOption.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<String>> signedUrls(List<String> paths) async {
    if (paths.isEmpty) return const [];
    final signed = await _db.storage.from(bucket).createSignedUrls(paths, 3600);
    return signed.map((s) => s.signedUrl).toList();
  }

  /// Live updates of the expenses list (e.g. a scan on the kitchen phone finishing).
  RealtimeChannel watchExpenses(void Function() onChange) {
    return _db
        .channel('expenses-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchases',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  void stopWatching(RealtimeChannel channel) => _db.removeChannel(channel);

  // --------------------------------------------------------------- scanning

  /// Uploads the pages of one document and returns their storage paths.
  Future<List<String>> uploadPages(List<({Uint8List bytes, String extension})> pages) async {
    final folder =
        'expenses/${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(0x7fffffff).toRadixString(16)}';
    final paths = <String>[];
    for (var i = 0; i < pages.length; i++) {
      final ext = pages[i].extension.toLowerCase().replaceAll('.', '');
      final path = '$folder/page-${i + 1}.$ext';
      await _db.storage
          .from(bucket)
          .uploadBinary(path, pages[i].bytes, fileOptions: FileOptions(contentType: _contentType(ext), upsert: false));
      paths.add(path);
    }
    return paths;
  }

  /// Gemini reads the uploaded pages. Returns the new expense id (also on failure, so it can be retried).
  Future<String> analyze(List<String> paths) => _invokeScan({'paths': paths});

  /// Reads an existing expense again (after a failure or to refresh the match).
  Future<String> reanalyze(String expenseId) => _invokeScan({'purchase_id': expenseId});

  Future<String> _invokeScan(Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke('scan-expense', body: body);
      final data = res.data as Map<String, dynamic>?;
      final id = data?['purchase_id'] as String?;
      if (id == null) throw ExpenseException(data?['error'] as String? ?? 'The invoice could not be read.');
      return id;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      final id = details is Map ? details['purchase_id'] as String? : null;
      throw ExpenseException(message ?? 'The invoice could not be read.', expenseId: id);
    }
  }

  // ------------------------------------------------------------- reviewing

  Future<void> assignSupplier(String expenseId, String supplierId) async {
    await _db.rpc('assign_expense_supplier', params: {'p_purchase_id': expenseId, 'p_supplier_id': supplierId});
  }

  Future<SupplierOption> createSupplier({
    required String name,
    String? street,
    String? postcode,
    String? city,
    String? phone,
    String? email,
    String? vatId,
    String? website,
  }) async {
    final row = await _db
        .from('suppliers')
        .insert({
          'name': name.trim(),
          'street_address': _blank(street),
          'post_code': _blank(postcode),
          'city': _blank(city),
          'phone': _blank(phone),
          'email': _blank(email),
          'vat_id': _blank(vatId)?.replaceAll(RegExp(r'\s'), '').toUpperCase(),
          'website': _blank(website),
        })
        .select('id, name, city')
        .single();
    return SupplierOption.fromJson(row);
  }

  Future<StockMaterial> createMaterial({
    required String name,
    required String unit,
    required String category,
    double? alertBelow,
  }) async {
    final row = await _db
        .from('material')
        .insert({
          'name': name.trim(),
          'unit_of_measure': unit,
          'category': category,
          'current_quantity': 0,
          if (alertBelow != null) 'notify_when_quantity': alertBelow,
        })
        .select('id, name, unit_of_measure, category, current_quantity')
        .single();
    return StockMaterial.fromJson(row);
  }

  /// Books the reviewed lines into inventory. Returns the stock changes.
  Future<List<Map<String, dynamic>>> book(String expenseId, Map<String, LineDecision> decisions) async {
    final lines = decisions.entries
        .map(
          (e) => {
            'item_id': e.key,
            'material_id': e.value.materialId,
            'conversion_ratio': e.value.conversionRatio,
            'stock': e.value.isReady,
          },
        )
        .toList();
    final res = await _db.rpc('book_expense', params: {'p_purchase_id': expenseId, 'p_lines': lines});
    return (((res as Map?)?['changes'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// A recorded (history-only) expense becomes reviewable for stock again.
  Future<void> reopenForStock(String expenseId) async {
    await _db.from('purchases').update({'status': 'needs_review'}).eq('id', expenseId).eq('status', 'recorded');
  }

  Future<void> unbook(String expenseId) async {
    await _db.rpc('unbook_expense', params: {'p_purchase_id': expenseId});
  }

  /// Removes an expense that is not booked (e.g. a blurry scan), including its photos.
  Future<void> delete(Expense expense) async {
    if (expense.isBooked) throw ExpenseException('Undo the booking before deleting this expense.');
    await _db.from('purchases').delete().eq('id', expense.id);
    if (expense.documentPaths.isNotEmpty) {
      try {
        await _db.storage.from(bucket).remove(expense.documentPaths);
      } catch (_) {
        // The expense is gone; leftover files are harmless.
      }
    }
  }

  static String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  static String _contentType(String ext) => switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    _ => 'image/jpeg',
  };
}

class ExpenseException implements Exception {
  final String message;
  final String? expenseId;
  ExpenseException(this.message, {this.expenseId});
  @override
  String toString() => message;
}

/// Material units in one purchased unit, from the pack content read on the invoice.
double? conversionFromContent(double? content, String? contentUnit, String materialUnit) {
  if (content == null || content <= 0 || contentUnit == null) return null;
  switch (contentUnit) {
    case 'g':
      return materialUnit == 'gram' ? content : (materialUnit == 'kg' ? content / 1000 : null);
    case 'ml':
      return materialUnit == 'ml' ? content : (materialUnit == 'l' ? content / 1000 : null);
    case 'piece':
      return materialUnit == 'piece' ? content : null;
  }
  return null;
}
