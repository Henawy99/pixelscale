import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'purchase_review_dialog.dart';
import '_supplier_dialogs.dart';

class PurchaseScannerScreen extends StatefulWidget {
  const PurchaseScannerScreen({super.key});
  @override
  State<PurchaseScannerScreen> createState() => _PurchaseScannerScreenState();
}

class _PurchaseScannerScreenState extends State<PurchaseScannerScreen> {
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;
  String? _message;
  String? _wholesalerHint;

  Uint8List? _imageBytes;
  String? _fileName;

  Map<String, dynamic>? _toMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try { return jsonDecode(data) as Map<String, dynamic>; } catch (_) {}
    }
    return null;
  }



  Future<String?> _confirmOrCreateSupplier(String? detectedName) async {
    final supa = _supabase;
    String? finalName = detectedName?.trim();
    // Check if exists when we have a name
    if (finalName != null && finalName.isNotEmpty) {
      try {
        final existing = await supa
            .from('suppliers')
            .select('id, name, ai_rules')
            .ilike('name', finalName)
            .maybeSingle();
        if (existing != null) return existing['name'] as String? ?? finalName;
      } catch (_) {}
    }
    // Ask user to create supplier (or enter a name if none detected)
    if (!mounted) return null;
    final result = await showDialog<SupplierResult?>(
      context: context,
      builder: (ctx) => SupplierCreateDialog(initialName: finalName),
    );
    if (result == null) return null;
    // Insert supplier
    try {
      final payload = {
        'name': result.name,
        if (result.aiRules != null && result.aiRules!.trim().isNotEmpty) 'ai_rules': result.aiRules,
      };
      final inserted = await supa.from('suppliers').insert(payload).select('id, name').single();
      return inserted['name'] as String? ?? result.name;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create supplier: $e'), backgroundColor: Colors.red));
      return null;
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.single.bytes == null) return;
    setState(() {
      _imageBytes = result.files.single.bytes;
      _fileName = result.files.single.name;
    });
  }

  Future<void> _process() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a receipt image.')));
      return;
    }
    setState(() { _isProcessing = true; _message = 'Scanning receipt...'; });
    try {
      // First lightweight scan to detect supplier
      final prePayload = {
        'receiptImageBase64': base64Encode(_imageBytes!),
      };
      final pre = await _supabase.functions.invoke('scan-purchase', body: prePayload);
      final preBody = pre.data as Map<String, dynamic>?;
      if (preBody == null || preBody['ok'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan failed.')));
        return;
      }

      // Capture any pre-normalized items we can use as fallback later
      List<PurchaseLine> preLines = [];
      String? preWholesalerName;
      DateTime? preReceiptDate;
      double? preTotalAmount;
      final preNormalized = (preBody['data'] ?? preBody['result']) as Map<String, dynamic>?;
      if (preNormalized != null && preNormalized['items'] is List) {
        preWholesalerName = preNormalized['wholesalerName'] as String?;
        preReceiptDate = preNormalized['receiptDate'] != null ? DateTime.tryParse(preNormalized['receiptDate'] as String) : null;
        preTotalAmount = (preNormalized['totalAmount'] as num?)?.toDouble();
        preLines = (preNormalized['items'] as List).map((e) {
          final map = e as Map<String, dynamic>;
          return PurchaseLine(
            rawName: (map['raw_name'] as String?) ?? (map['item_name'] as String? ?? ''),
            brandName: map['brand_name'] as String? ?? map['brand'] as String?,
            itemNumber: map['item_number'] as String?,
            quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
            unit: (map['unit'] as String?) ?? '',
            unitPrice: (map['unit_price'] as num?)?.toDouble(),
            totalItemPrice: (map['total_item_price'] as num?)?.toDouble(),
            materialId: map['material_id'] as String?,
            materialName: map['material_name'] as String?,
            baseUnit: map['base_unit'] as String?,
            conversionRatio: (map['conversion_ratio'] as num?)?.toDouble() ?? 1,
          );
        }).toList();
      }

      // If the function already created a purchase (id + type), fetch and open review immediately
      if (preBody['id'] != null && preBody['type'] == 'purchase') {
        final purchaseId = preBody['id'] as String;
        final supa = _supabase;
        final header = await supa
            .from('purchases')
            .select('supplier_name, receipt_date, total_amount')
            .eq('id', purchaseId)
            .maybeSingle();
        final items = await supa
            .from('purchase_items')
            .select('id, raw_name, brand_name, item_number, quantity, unit, unit_price, total_item_price, purchase_catalog_item_id(name, material_id, material_id(name, unit_of_measure), base_unit, conversion_ratio)')
            .eq('purchase_id', purchaseId);

        final wholesalerName = header?['supplier_name'] as String?;
        final dateStr = header?['receipt_date'] as String?;
        final totalAmount = (header?['total_amount'] is num) ? (header!['total_amount'] as num).toDouble() : null;
        final receiptDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

        final List<PurchaseLine> lines = [];
        for (final row in (items as List)) {
          final pci = row['purchase_catalog_item_id'] as Map<String, dynamic>?;
          final mat = pci != null ? pci['material_id'] as Map<String, dynamic>? : null;
          lines.add(PurchaseLine(
            purchaseItemId: row['id'] as String?,
            rawName: (row['raw_name'] ?? '') as String,
            brandName: row['brand_name'] as String?,
            itemNumber: row['item_number'] as String?,
            quantity: (row['quantity'] is num) ? (row['quantity'] as num).toDouble() : 0.0,
            unit: (row['unit'] ?? '') as String,
            unitPrice: (row['unit_price'] is num) ? (row['unit_price'] as num).toDouble() : null,
            totalItemPrice: (row['total_item_price'] is num) ? (row['total_item_price'] as num).toDouble() : null,
            materialId: (mat != null) ? mat['id'] as String? : null,
            materialName: (mat != null) ? mat['name'] as String? : null,
            baseUnit: (pci != null) ? (pci['base_unit'] as String?) ?? (mat != null ? mat['unit_of_measure'] as String? : null) : null,
            conversionRatio: (pci != null && pci['conversion_ratio'] is num) ? (pci['conversion_ratio'] as num).toDouble() : 1.0,
          ));
        }

        if (!mounted) return;
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (ctx) => PurchaseReviewDialog(
              wholesalerName: wholesalerName,
              receiptDate: receiptDate,
              totalAmount: totalAmount,
              lines: lines,
              receiptImageBytes: _imageBytes,
            ),
          ),
        );
        if (result == true && mounted) Navigator.of(context).pop(true);
        return; // done
      }

      String? detectedSupplier;
      if (preBody['data'] != null || preBody['result'] != null) {
        final m = (preBody['data'] ?? preBody['result']) as Map<String, dynamic>;
        detectedSupplier = m['wholesalerName'] as String?;
      }

      // Confirm or create supplier (with AI rules). If cancelled, proceed with fallback.
      String? supplierName = await _confirmOrCreateSupplier(_wholesalerHint?.isNotEmpty == true ? _wholesalerHint : detectedSupplier);
      supplierName = supplierName ?? detectedSupplier ?? _wholesalerHint ?? 'Unknown Supplier';

      setState(() { _message = 'Scanning with supplier rules...'; });
      final payload = {
        'receiptImageBase64': base64Encode(_imageBytes!),
        'wholesalerHint': supplierName,
      };
      final resp = await _supabase.functions.invoke('scan-purchase', body: payload);
      final body = resp.data as Map<String, dynamic>?;
      if (body == null || body['ok'] != true) {
        throw Exception(body?['error'] ?? 'Scan failed');
      }

      String? wholesalerName;
      DateTime? receiptDate;
      double? totalAmount;
      List<PurchaseLine> lines = [];

      if (body['data'] != null) {
        final normalized = body['data'] as Map<String, dynamic>;
        wholesalerName = normalized['wholesalerName'] as String? ?? supplierName;
        receiptDate = normalized['receiptDate'] != null ? DateTime.tryParse(normalized['receiptDate'] as String) : null;
        totalAmount = (normalized['totalAmount'] as num?)?.toDouble();
        lines = (normalized['items'] as List).map((e) {
          final map = e as Map<String, dynamic>;
          return PurchaseLine(
            rawName: (map['raw_name'] as String?) ?? (map['item_name'] as String? ?? ''),
            brandName: map['brand_name'] as String? ?? map['brand'] as String?,
            itemNumber: map['item_number'] as String?,
            quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
            unit: (map['unit'] as String?) ?? '',
            unitPrice: (map['unit_price'] as num?)?.toDouble(),
            totalItemPrice: (map['total_item_price'] as num?)?.toDouble(),
            materialId: map['material_id'] as String?,
            materialName: map['material_name'] as String?,
            baseUnit: map['base_unit'] as String?,
            conversionRatio: (map['conversion_ratio'] as num?)?.toDouble() ?? 1,
          );
        }).toList();
      } else if (body['id'] != null && body['type'] == 'purchase') {
        final purchaseId = body['id'] as String;
        final supa = _supabase;
        final header = await supa
            .from('purchases')
            .select('supplier_name, receipt_date, total_amount')
            .eq('id', purchaseId)
            .maybeSingle();
        final items = await supa
            .from('purchase_items')
            .select('id, raw_name, brand_name, item_number, quantity, unit, unit_price, total_item_price, purchase_catalog_item_id(name, material_id, material_id(name, unit_of_measure), base_unit, conversion_ratio)')
            .eq('purchase_id', purchaseId);

        wholesalerName = header?['supplier_name'] as String? ?? supplierName;
        final dateStr = header?['receipt_date'] as String?;
        totalAmount = (header?['total_amount'] is num) ? (header!['total_amount'] as num).toDouble() : null;
        receiptDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

        for (final row in (items as List)) {
          final pci = row['purchase_catalog_item_id'] as Map<String, dynamic>?;
          final mat = pci != null ? pci['material_id'] as Map<String, dynamic>? : null;
          lines.add(PurchaseLine(
            purchaseItemId: row['id'] as String?,
            rawName: (row['raw_name'] ?? '') as String,
            brandName: row['brand_name'] as String?,
            itemNumber: row['item_number'] as String?,
            quantity: (row['quantity'] is num) ? (row['quantity'] as num).toDouble() : 0.0,
            unit: (row['unit'] ?? '') as String,
            unitPrice: (row['unit_price'] is num) ? (row['unit_price'] as num).toDouble() : null,
            totalItemPrice: (row['total_item_price'] is num) ? (row['total_item_price'] as num).toDouble() : null,
            materialId: (mat != null) ? mat['id'] as String? : null,
            materialName: (mat != null) ? mat['name'] as String? : null,
            baseUnit: (pci != null) ? (pci['base_unit'] as String?) ?? (mat != null ? mat['unit_of_measure'] as String? : null) : null,
            conversionRatio: (pci != null && pci['conversion_ratio'] is num) ? (pci['conversion_ratio'] as num).toDouble() : 1.0,
          ));
        }
      } else if (body['items'] != null && body['items'] is List) {
        // Some versions may return normalized data at the root
        wholesalerName = body['wholesalerName'] as String? ?? supplierName;
        receiptDate = body['receiptDate'] != null ? DateTime.tryParse(body['receiptDate'] as String) : null;
        totalAmount = (body['totalAmount'] as num?)?.toDouble();
        lines = (body['items'] as List).map((e) {
          final map = e as Map<String, dynamic>;
          return PurchaseLine(
            rawName: (map['raw_name'] as String?) ?? (map['item_name'] as String? ?? ''),
            brandName: map['brand_name'] as String? ?? map['brand'] as String?,
            itemNumber: map['item_number'] as String?,
            quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
            unit: (map['unit'] as String?) ?? '',
            unitPrice: (map['unit_price'] as num?)?.toDouble(),
            totalItemPrice: (map['total_item_price'] as num?)?.toDouble(),
            materialId: map['material_id'] as String?,
            materialName: map['material_name'] as String?,
            baseUnit: map['base_unit'] as String?,
            conversionRatio: (map['conversion_ratio'] as num?)?.toDouble() ?? 1,
          );
        }).toList();
      } else {
        // Fallback: ok:true but unknown shape. Try to fetch the most recent purchase.
        Map<String, dynamic>? header;
        List<dynamic>? items;
        try {
          final supa = _supabase;
          header = await supa
              .from('purchases')
              .select('id, supplier_name, receipt_date, total_amount, created_at')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (header != null) {
            final pid = header['id'] as String;
            items = await supa
                .from('purchase_items')
                .select('id, raw_name, brand_name, item_number, quantity, unit, unit_price, total_item_price, purchase_catalog_item_id(name, material_id, material_id(name, unit_of_measure), base_unit, conversion_ratio)')
                .eq('purchase_id', pid);
            wholesalerName = header['supplier_name'] as String? ?? supplierName;
            final dateStr = header['receipt_date'] as String?;
            totalAmount = (header['total_amount'] is num) ? (header['total_amount'] as num).toDouble() : null;
            receiptDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
            for (final row in items) {
                final pci = row['purchase_catalog_item_id'] as Map<String, dynamic>?;
                final mat = pci != null ? pci['material_id'] as Map<String, dynamic>? : null;
                lines.add(PurchaseLine(
                  purchaseItemId: row['id'] as String?,
                  rawName: (row['raw_name'] ?? '') as String,
                  brandName: row['brand_name'] as String?,
                  itemNumber: row['item_number'] as String?,
                  quantity: (row['quantity'] is num) ? (row['quantity'] as num).toDouble() : 0.0,
                  unit: (row['unit'] ?? '') as String,
                  unitPrice: (row['unit_price'] is num) ? (row['unit_price'] as num).toDouble() : null,
                  totalItemPrice: (row['total_item_price'] is num) ? (row['total_item_price'] as num).toDouble() : null,
                  materialId: (mat != null) ? mat['id'] as String? : null,
                  materialName: (mat != null) ? mat['name'] as String? : null,
                  baseUnit: (pci != null) ? (pci['base_unit'] as String?) ?? (mat != null ? mat['unit_of_measure'] as String? : null) : null,
                  conversionRatio: (pci != null && pci['conversion_ratio'] is num) ? (pci['conversion_ratio'] as num).toDouble() : 1.0,
                ));
              }
            }
          }
        catch (_) {}
      }

      // If we still have no lines, but the pre-scan had lines, use them to open the dialog
      if (lines.isEmpty && preLines.isNotEmpty) {
        lines = preLines;
        wholesalerName = wholesalerName ?? preWholesalerName;
        receiptDate = receiptDate ?? preReceiptDate;
        totalAmount = totalAmount ?? preTotalAmount;
      }

      if (!mounted) return;
      // Ensure we always open the dialog even if lines are empty
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (ctx) => PurchaseReviewDialog(
            wholesalerName: wholesalerName,
            receiptDate: receiptDate,
            totalAmount: totalAmount,
            lines: lines,
            receiptImageBytes: _imageBytes,
          ),
        ),
      );
      if (result == true) {
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Purchase Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Wholesaler hint (optional)', border: OutlineInputBorder()),
              onChanged: (v) => _wholesalerHint = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image_search_outlined), label: const Text('Select Image')),
                const SizedBox(width: 12),
                if (_fileName != null) Expanded(child: Text(_fileName!, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: _imageBytes == null
                    ? const Text('No image selected')
                    : Image.memory(_imageBytes!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _process,
                icon: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_motion_outlined),
                label: const Text('Process with AI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

