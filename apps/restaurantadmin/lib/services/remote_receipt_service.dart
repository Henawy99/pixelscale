import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteReceiptService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> processReceiptImage({
    required String imagePath,
    String? brandId,
    String? brandName,
    String? platformOrderId,
    String? idempotencyKey,
  }) async {
    // Read image bytes; TODO: optionally compress to reduce payload size
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = {
      if (brandId != null) 'brandId': brandId,
      if (brandName != null) 'brandName': brandName,
      'receiptImageBase64': base64Image,
      if (platformOrderId != null) 'platformOrderId': platformOrderId,
      // Simple idempotency stub: prefer caller-provided; else derive from size+mtime (weak). TODO: use crypto hash
      'idempotencyKey': idempotencyKey ?? _deriveWeakIdempotencyKey(imagePath, bytes.length),
    };

    final response = await _supabase.functions.invoke('scan-receipt', body: body);

    // functions.invoke throws on 4xx/5xx, otherwise returns data
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    // Fallback: wrap raw response
    return {'ok': true, 'data': response.data};
  }

  String _deriveWeakIdempotencyKey(String path, int length) {
    final userId = _supabase.auth.currentUser?.id ?? 'anon';
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$userId:$length:$ts:$path';
  }
}

