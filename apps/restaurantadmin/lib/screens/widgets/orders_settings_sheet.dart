import 'package:flutter/material.dart';
import 'package:restaurantadmin/services/settings_service.dart';
import 'package:restaurantadmin/screens/scan_settings_screen.dart';

class OrdersSettingsSheet extends StatefulWidget {
  const OrdersSettingsSheet({super.key});

  @override
  State<OrdersSettingsSheet> createState() => _OrdersSettingsSheetState();
}

class _OrdersSettingsSheetState extends State<OrdersSettingsSheet> {
  final settings = SettingsService();
  final TextEditingController _orderPromptCtrl = TextEditingController();
  final TextEditingController _purchasePromptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orderPromptCtrl.text = settings.orderScanPrompt.value;
    _purchasePromptCtrl.text = settings.purchaseScanPrompt.value;
  }

  @override
  void dispose() {
    _orderPromptCtrl.dispose();
    _purchasePromptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: Colors.white,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.settings_outlined, color: Colors.blueGrey),
                const SizedBox(width: 8),
                const Text(
                  'Orders Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: settings.autoConfirmEnabled,
              builder: (context, enabled, _) => SwitchListTile(
                title: const Text('Auto-confirm new scanned orders'),
                subtitle: const Text(
                  'Opens review and confirms automatically after countdown',
                ),
                value: enabled,
                onChanged: (v) => settings.autoConfirmEnabled.value = v,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: settings.autoConfirmSeconds,
              builder: (context, secs, _) => Row(
                children: [
                  const Text('Countdown seconds:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: secs,
                    items: const [3, 5, 7, 10, 15]
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text('$e')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) settings.autoConfirmSeconds.value = v;
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Toggle: Show AI parse in order review dialog
            ValueListenableBuilder<bool>(
              valueListenable: settings.showAiDebugInDialog,
              builder: (context, v, _) => SwitchListTile(
                title: const Text('Show AI parse in Order Review dialog'),
                subtitle: const Text('Displays what the AI extracted and normalized for debugging'),
                value: v,
                onChanged: (nv) => settings.showAiDebugInDialog.value = nv,
              ),
            ),
            const Divider(height: 24),
            // Toggle: Always open Review dialog for any new order
            ValueListenableBuilder<bool>(
              valueListenable: settings.showReviewForAllNewOrders,
              builder: (context, v, _) => SwitchListTile(
                title: const Text('Always show Review for new orders'),
                subtitle: const Text('Show review dialog for new orders'),
                value: v,
                onChanged: (nv) => settings.showReviewForAllNewOrders.value = nv,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Gemini AI Prompts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tip: Improve prompts when scanning errors occur',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Edit these prompts to improve AI accuracy for delivery fees, customer info, and item recognition.',
                    style: TextStyle(color: Colors.blue[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Orders scan prompt section
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Order Receipts Prompt',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ScanSettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_suggest, size: 16),
                  label: const Text(
                    'Server Prompt',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    // Optionally open unmatched items / aliases manager for a selected brand
                    // If you have a current brand context, pass it here. For demo, we require a brandId.
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => UnmatchedItemsScreen(brandId: CURRENT_BRAND_ID)));
                  },
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Aliases', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    _orderPromptCtrl.text =
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
- Ensure totalPrice includes all fees and items''';
                    settings.orderScanPrompt.value = _orderPromptCtrl.text;
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _orderPromptCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter Gemini prompt for order receipts...',
                helperText:
                    'This prompt processes scanned order receipts to extract delivery info, fees, and items',
                helperMaxLines: 2,
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              onChanged: (v) => settings.orderScanPrompt.value = v,
            ),
            const SizedBox(height: 20),

            // Purchases scan prompt section
            Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Purchase Receipts Prompt',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _purchasePromptCtrl.text =
                        'Extract purchased materials, quantities, and costs from the receipt. Return structured JSON suitable for inventory updates.';
                    settings.purchaseScanPrompt.value =
                        _purchasePromptCtrl.text;
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _purchasePromptCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter Gemini prompt for purchase receipts...',
                helperText:
                    'This prompt processes purchase receipts for inventory management',
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              onChanged: (v) => settings.purchaseScanPrompt.value = v,
            ),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
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
                        Icons.lightbulb_outline,
                        color: Colors.amber[700],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pro Tips for Better AI Recognition',
                        style: TextStyle(
                          color: Colors.amber[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Be specific about required fields (delivery fees, customer info)\n'
                    '• Use exact JSON structure examples\n'
                    '• Mention common platform names (Lieferando, Foodora, etc.)\n'
                    '• Specify date formats and null handling\n'
                    '• Test changes with problematic receipts',
                    style: TextStyle(color: Colors.amber[600], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
