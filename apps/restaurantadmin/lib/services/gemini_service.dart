import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  final GenerativeModel _model;
  final String _apiKey;

  static String _resolveApiKey() {
    // Prefer --dart-define, then .env, then fallback to existing hardcoded key
    const fromDefine = String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromDotenv = dotenv.maybeGet('GEMINI_API_KEY');
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    return 'AIzaSyAiYA0l0aUtD-NSxoCElkMNPX9IQy25DZU';
  }

  GeminiService()
    : _apiKey = _resolveApiKey(),
      _model = GenerativeModel(
        model: 'gemini-pro-vision',
        apiKey: _resolveApiKey(),
      );

  Future<Map<String, dynamic>?> processReceiptImageWithGemini({
    required Uint8List imageBytes,
    required String brandNameFromReceipt,
    required List<MenuItem> menuItemsForBrand,
  }) async {
    if (_apiKey.isEmpty) {
      print(
        'GEMINI API KEY NOT SET. Set GEMINI_API_KEY via --dart-define or .env',
      );
      return null;
    }

    final menuItemsPromptList = menuItemsForBrand
        .map((item) => "- ID: '${item.id}', Name: '${item.name}'")
        .join('\n');

    final prompt =
        """
You are an expert receipt processing AI for a restaurant order system called Playmaker.
Analyze the following receipt image for the brand "$brandNameFromReceipt" and extract the requested fields.
Return ONLY the JSON object described previously.
""";

    try {
      final content = [
        Content.multi([
          TextPart(
            "Available Menu Items for $brandNameFromReceipt:\n$menuItemsPromptList",
          ),
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];
      final response = await _model.generateContent(content);
      final raw = response.text ?? '';
      if (raw.isEmpty) {
        print('Gemini (image) response was empty.');
        return null;
      }
      String cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }
      print('Gemini (image) Raw Response: $raw');
      print('Gemini (image) Extracted JSON: $cleaned');
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      print(
        'Gemini (image) response was not a valid JSON object after extraction.',
      );
      return null;
    } catch (e) {
      print('Error calling Gemini (image) or parsing response: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> processReceiptTextWithGemini({
    required String ocrText,
    required String brandNameFromReceipt,
    required List<MenuItem> menuItemsForBrand,
  }) async {
    if (_apiKey.isEmpty) {
      print(
        'GEMINI API KEY NOT SET. Set GEMINI_API_KEY via --dart-define or .env',
      );
      return null;
    }

    // 1. Construct the detailed prompt for Gemini
    final menuItemsPromptList = menuItemsForBrand
        .map((item) => "- ID: '${item.id}', Name: '${item.name}'")
        .join('\n');

    final prompt =
        """
You are an expert receipt processing AI for a restaurant order system called Playmaker.
Analyze the following OCR text extracted from a customer's food order receipt.
The receipt is for the brand: "$brandNameFromReceipt".

Your task is to extract the specified information and return it as a VALID JSON object.
Ensure all keys are double-quoted. Ensure all string values are double-quoted.
The JSON object should conform to the following structure, only including fields you can confidently extract.
If a field cannot be found, omit it from the JSON or set its value to null.

JSON Structure to populate:
{
  "brandName": "string (must be one of: CRISPY CHICKEN LAB, DEVILS SMASH BURGER, THE BOWL SPOT, TACOTASTIC)",
  "orderTypeName": "string (e.g., 'Lieferando', 'Takeaway', 'Dine-in', or null if not identifiable)",
  "customerName": "string (from 'Kundendetails' or similar section, or null)",
  "customerStreet": "string (full street address including number, from 'Kundendetails', or null)",
  "customerPostcode": "string (from 'Kundendetails', or null)",
  "customerCity": "string (from 'Kundendetails', or null)",
  "totalPrice": "number (extracted from 'Gesamtbetrag' or similar total field)",
  "createdAt": "string (ISO 8601 format, e.g., 'YYYY-MM-DDTHH:mm:ss', from 'Bestellung aufgegeben um' or similar order placement time)",
  "requestedDeliveryTime": "string (ISO 8601 format, e.g., 'YYYY-MM-DDTHH:mm:ss', for Lieferando, this is after 'fällig'. For others, look for similar terms like 'Lieferzeit', 'Gewünschte Zeit', or null if not specified)",
  "paymentMethod": "string ('cash' if 'BESTELLUNG NICHT BEZAHLT' is present; 'online' if 'BESTELLUNG WURDE BEZAHLT' is present; or null)",
  "platformOrderId": "string (any unique order number or code printed on the receipt, e.g., from Lieferando, Takeaway.com like # WVR FX7, or null if not found)",
  "brandId": "string (the exact brand id from Supabase 'brands' table if you can infer it from the receipt brand name)",
  "orderItems": [
    { "menuItemId": "string (ID of the matched menu item from the provided list)", "menuItemName": "string (Name of the item as it appears on the receipt)", "quantity": "integer" }
  ]
}

Specific Instructions:
- If the receipt mentions "Lieferando", set "orderTypeName" to "Lieferando".
- For Lieferando receipts, "requestedDeliveryTime" is usually found after the word "fällig". Parse this time.
- "totalPrice" is typically labeled as "Gesamtbetrag".
- "createdAt" should be the time from "Bestellung aufgegeben um".
- "customerName", "customerStreet", "customerPostcode", "customerCity" are usually under a section like "Kundendetails".
- "paymentMethod": If the receipt says "BESTELLUNG NICHT BEZAHLT", set to "cash". If it says "BESTELLUNG WURDE BEZAHLT", set to "online".
- "brandName": Confirm this from the top of the receipt. It must be one of "CRISPY CHICKEN LAB", "DEVILS SMASH BURGER", or "THE BOWL SPOT".
- "platformOrderId": Extract any distinct order number or code found on the receipt (examples: # WVR FX7, Order #12345). If none is obvious, set to null.
- "orderItems":
    - List all items found on the receipt.
    - For each item, try to match its name to an item in the 'Available Menu Items' list below.
    - If a match is found, use the corresponding 'ID' for "menuItemId".
    - "menuItemName" should be the name as it appears on the receipt.
    - Extract the quantity for each item.

Available Menu Items for $brandNameFromReceipt:
$menuItemsPromptList

OCR Text from Receipt:
---
$ocrText
---

Return ONLY the JSON object. Do not include any other text or explanations.
""";

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      final raw = response.text ?? '';
      if (raw.isEmpty) {
        print('Gemini response was empty.');
        return null;
      }

      // Clean potential code fences
      String cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      // Extract the first JSON object block to be robust against extra text
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }

      print('Gemini Raw Response: $raw');
      print('Gemini Extracted JSON: $cleaned');

      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      print('Gemini response was not a valid JSON object after extraction.');
      return null;
    } catch (e) {
      print('Error calling Gemini API or parsing response: $e');
      return null;
    }
  }
}
