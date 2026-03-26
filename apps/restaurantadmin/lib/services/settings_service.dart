import 'package:flutter/foundation.dart';

class SettingsService {
  SettingsService._internal();
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;

  // In-memory settings (can be persisted later via shared_preferences)
  final ValueNotifier<bool> autoConfirmEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<int> autoConfirmSeconds = ValueNotifier<int>(7);
  // Show AI parse/debug info inside order review dialog
  final ValueNotifier<bool> showAiDebugInDialog = ValueNotifier<bool>(false);
  // Always open review dialog for any new order
  final ValueNotifier<bool> showReviewForAllNewOrders = ValueNotifier<bool>(true);

  // Gemini prompts
  final ValueNotifier<String> orderScanPrompt = ValueNotifier<String>(
    '''Extract order information from this receipt/order image. Return ONLY valid JSON with this exact structure:

{
  "brandName": "Restaurant/Brand name",
  "orderTypeName": "Platform name (e.g., Lieferando, Foodora, Wolt, Uber Eats)",
  "totalPrice": 15.50,
  "deliveryFee": 2.50,
  "serviceFee": 1.00,
  "paymentMethod": "online",
  "customerName": "Customer Name",
  "customerStreet": "Street Address",
  "customerPostcode": "12345",
  "customerCity": "City Name",
  "platformOrderId": "Platform-specific order ID",
  "createdAt": "2024-01-01T12:00:00Z",
  "requestedDeliveryTime": "2024-01-01T13:00:00Z",
  "orderItems": [
    {
      "menuItemName": "Exact item name from receipt",
      "quantity": 2,
      "priceAtPurchase": 8.50
    }
  ]
}

IMPORTANT:
- Extract ALL fees (delivery, service, tip, etc.) separately
- Use exact item names as they appear on the receipt
- Include customer delivery information if visible
- Parse dates in ISO format
- If information is missing, use null (not empty strings)
- Ensure totalPrice includes all fees and items''',
  );
  final ValueNotifier<String> purchaseScanPrompt = ValueNotifier<String>(
    'Extract purchased materials, quantities, and costs from the receipt. Return structured JSON suitable for inventory updates.',
  );
}
