import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Saves the receipt image to the Downloads directory (used on macOS, iOS, Android).
Future<void> openReceiptDownload(String url, {String? suggestedFilename}) async {
  Directory? dir = await getDownloadsDirectory();
  dir ??= await getApplicationDocumentsDirectory();
  final name = suggestedFilename ?? 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final file = File('${dir.path}/$name');
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    await file.writeAsBytes(response.bodyBytes);
  }
}
