// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Opens the receipt image in a new tab so the user can save it (web).
Future<void> openReceiptDownload(String url, {String? suggestedFilename}) async {
  html.window.open(url, '_blank');
}
