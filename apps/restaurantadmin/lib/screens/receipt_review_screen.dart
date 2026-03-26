import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:restaurantadmin/models/material_item.dart'; // Removed unused import
import 'package:supabase_flutter/supabase_flutter.dart';

// Enhanced data structure for items being reviewed
class ReviewableReceiptItem {
  String ocrItemName; // Name as extracted by OCR/Gemini
  double ocrQuantity; // Quantity as extracted by OCR/Gemini
  String ocrUnit;     // Unit as extracted by OCR/Gemini
  // String ocrSuggestedCategory; // Removed: Category will be from DB match or user selection
  double ocrTotalItemPrice; // Added for price from receipt

  String? matchedMaterialId;
  String? matchedMaterialName; // Name of the matched material in DB
  String? dbMaterialUnit;
  String? dbMaterialCategory;
  double? dbCurrentQuantity;

  // For UI editing, these will initially be populated from OCR/match
  late TextEditingController nameController;
  late TextEditingController quantityController;
  late TextEditingController priceController; // Added price controller
  late String selectedUnit; // Marked as late
  late String selectedCategory; // Marked as late
  bool isMatched;

  ReviewableReceiptItem({
    required this.ocrItemName,
    required this.ocrQuantity,
    required this.ocrUnit,
    required this.ocrTotalItemPrice, // Added
    // required this.ocrSuggestedCategory, // Removed
    this.matchedMaterialId,
    this.matchedMaterialName,
    this.dbMaterialUnit,
    this.dbMaterialCategory,
    this.dbCurrentQuantity,
  }) : isMatched = matchedMaterialId != null {
    nameController = TextEditingController(text: matchedMaterialName ?? ocrItemName);
    quantityController = TextEditingController(text: ocrQuantity.toString());
    priceController = TextEditingController(text: ocrTotalItemPrice.toString()); // Initialize price controller
    selectedUnit = dbMaterialUnit ?? ocrUnit;
    // If matched, category comes from DB, otherwise default to 'Uncategorized' or first in list
    selectedCategory = dbMaterialCategory ?? 'Uncategorized'; 
  }

  // To dispose controllers
  void disposeControllers() {
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose(); // Dispose price controller
  }

  // Factory from Gemini's parsed item (initial step)
  factory ReviewableReceiptItem.fromParsedItemMap(Map<String, dynamic> map) {
    return ReviewableReceiptItem(
      ocrItemName: map['item_name'] as String? ?? 'Unknown Item',
      ocrQuantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      ocrUnit: map['unit'] as String? ?? 'unit',
      ocrTotalItemPrice: (map['total_item_price'] as num?)?.toDouble() ?? 0.0, // Parse total_item_price
      // ocrSuggestedCategory is no longer expected from Gemini per item
    );
  }
}

class ReceiptReviewScreen extends StatefulWidget {
  final String geminiResponseJson; // The raw JSON string from Gemini

  const ReceiptReviewScreen({super.key, required this.geminiResponseJson});

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  List<ReviewableReceiptItem> _reviewableItems = [];
  String? _sellerName;
  String? _receiptDate;
  bool _isLoading = true; // Start with loading true while matching
  String? _processingError; // To store parsing or matching error message

  // Predefined lists for dropdowns
  final List<String> _units = ['piece', 'kilo', 'ml', 'liter', 'gram', 'unit']; // Added 'unit' as a fallback
  final List<String> _categories = [
    'DRINKS', 'MEAT', 'BREAD', 'FRUITS AND VEGETABLES', 
    'SAUCES', 'PACKAGING', 'FINGERFOOD', 'Uncategorized' // Added FINGERFOOD
  ];

  @override
  void initState() {
    super.initState();
    // Call the new processing method
    _processReceiptAndMatchItems(); 
    // Error display is handled within _processReceiptAndMatchItems using addPostFrameCallback
  }

  @override
  void dispose() {
    for (var item in _reviewableItems) {
      item.disposeControllers();
    }
    super.dispose();
  }

  // Renamed and refactored method
  Future<void> _processReceiptAndMatchItems() async {
    setState(() {
      _isLoading = true;
      _processingError = null;
    });
    try {
      final jsonData = jsonDecode(widget.geminiResponseJson) as Map<String, dynamic>;
      _sellerName = jsonData['seller_name'] as String?;
      _receiptDate = jsonData['receipt_date'] as String?;
      
      final itemsList = jsonData['items'] as List<dynamic>? ?? [];
      List<ReviewableReceiptItem> tempReviewableItems = [];

      final supabase = Supabase.instance.client;

      for (var itemData in itemsList) {
        // Use the new factory constructor
        final parsedItem = ReviewableReceiptItem.fromParsedItemMap(itemData as Map<String, dynamic>);
        
        // Try to find an exact case-insensitive match in the database
        final List<dynamic> queryResponse = await supabase
            .from('material')
            .select('id, name, current_quantity, unit_of_measure, category')
            .ilike('name', parsedItem.ocrItemName)
            .limit(1); // Fetch as list with limit 1

        if (queryResponse.isNotEmpty) {
          final existingMaterialData = queryResponse.first as Map<String, dynamic>;
          parsedItem.isMatched = true;
          parsedItem.matchedMaterialId = existingMaterialData['id'] as String;
          parsedItem.matchedMaterialName = existingMaterialData['name'] as String;
          parsedItem.dbCurrentQuantity = (existingMaterialData['current_quantity'] as num?)?.toDouble() ?? 0.0;
          parsedItem.dbMaterialUnit = existingMaterialData['unit_of_measure'] as String?;
          parsedItem.dbMaterialCategory = existingMaterialData['category'] as String?;
          
          // Update controllers and selected values based on DB match
          parsedItem.nameController.text = parsedItem.matchedMaterialName!;
          parsedItem.selectedUnit = parsedItem.dbMaterialUnit ?? parsedItem.ocrUnit;
          parsedItem.selectedCategory = parsedItem.dbMaterialCategory ?? 'Uncategorized'; // Default if DB category is null
        } else {
          // Not matched, ensure selectedCategory has a default for the UI
          parsedItem.selectedCategory = 'Uncategorized'; // Or _categories.first if _categories is accessible here
        }
        tempReviewableItems.add(parsedItem);
      }
      _reviewableItems = tempReviewableItems; // Use the new list

    } catch (e) {
      print("Error processing receipt data or matching items: $e");
      _reviewableItems = []; 
      _processingError = e.toString(); // Use the consistent error variable
      if (mounted) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing receipt: $_processingError'), backgroundColor: Colors.red),
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _confirmAndAddToInventory() async {
    setState(() { _isLoading = true; });
    final supabase = Supabase.instance.client;

    try {
      int updatedCount = 0;
      int newCount = 0;

      // Use _reviewableItems
      for (var item in _reviewableItems) {
        // Check if material already exists (case-insensitive)
        // This check is now done in _processReceiptAndMatchItems, here we use item.isMatched
        
        final String itemName = item.nameController.text; // Get name from controller
        final double quantityToAdd = double.tryParse(item.quantityController.text) ?? 0.0;
        final double totalItemPrice = double.tryParse(item.priceController.text) ?? 0.0;

        if (quantityToAdd <= 0) continue; // Skip if quantity is invalid or zero

        double pricePaidPerUnit = 0.0;
        if (quantityToAdd > 0 && totalItemPrice > 0) {
          pricePaidPerUnit = totalItemPrice / quantityToAdd;
        }

        String materialId;
        double newTotalQuantity;
        
        if (item.isMatched && item.matchedMaterialId != null) {
          // Matched item - Update quantity
          materialId = item.matchedMaterialId!;
          final double currentDbQuantity = item.dbCurrentQuantity ?? 0.0;
          newTotalQuantity = currentDbQuantity + quantityToAdd;
          
          await supabase
              .from('material')
              .update({'current_quantity': newTotalQuantity})
              // average_cost_per_unit not updated here yet for existing items (Iteration 1)
              .eq('id', materialId);
          updatedCount++;
        } else {
          // New item - Insert
          final Map<String, dynamic> newMaterialData = {
            'name': itemName, 
            'current_quantity': quantityToAdd,
            'unit_of_measure': item.selectedUnit, 
            'category': _categories.contains(item.selectedCategory) ? item.selectedCategory : 'Uncategorized', 
            'seller_name': _sellerName,
            // 'item_number': null, 
            // 'gemini_info': null, 
          };
          // Set average_cost_per_unit only if pricePaidPerUnit is valid
          if (pricePaidPerUnit > 0) {
            newMaterialData['average_cost_per_unit'] = pricePaidPerUnit;
          }

          final List<dynamic> insertResponse = await supabase.from('material').insert(newMaterialData).select();

          if (insertResponse.isEmpty) {
            throw Exception("Failed to insert new material '$itemName' or get response back.");
          }
          final newMaterial = insertResponse.first as Map<String, dynamic>;
          materialId = newMaterial['id'] as String;
          newTotalQuantity = quantityToAdd;
          newCount++;
        }

        // Log the inventory change
        final Map<String, dynamic> logData = {
          'material_id': materialId,
          'material_name': itemName, 
          'change_type': 'ENTRY', 
          'quantity_change': quantityToAdd, 
          'new_quantity_after_change': newTotalQuantity, 
          'source_details': 'Receipt Scan - ${_sellerName ?? "Unknown Seller"} on ${_receiptDate ?? "Unknown Date"}',
        };
        if (pricePaidPerUnit > 0) {
          logData['price_paid_per_unit'] = pricePaidPerUnit;
        }
        await supabase.from('inventory_log').insert(logData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inventory updated: $updatedCount item(s) updated, $newCount item(s) added.'), backgroundColor: Colors.green),
      );
      Navigator.of(context).popUntil((route) => route.isFirst); // Go back to the main inventory screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update inventory: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Scanned Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _confirmAndAddToInventory,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          // Use _reviewableItems and _processingError
          : _reviewableItems.isEmpty && _processingError == null 
              ? const Center(child: Text('No items found in the receipt.'))
              : _processingError != null 
                  ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: $_processingError', style: const TextStyle(color: Colors.red))))
                  : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  // Use _reviewableItems
                  itemCount: _reviewableItems.length,
                  itemBuilder: (context, index) {
                    // Use _reviewableItems
                    final item = _reviewableItems[index];
                    return Card(
                      // Highlight matched items
                      color: item.isMatched ? Colors.green[50] : null,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Display matched material name if available
                            if (item.isMatched && item.matchedMaterialName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  "Matched: ${item.matchedMaterialName}",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                                ),
                              ),
                            TextFormField(
                              // Use controller
                              controller: item.nameController,
                              decoration: InputDecoration(
                                labelText: 'Item Name',
                                // Show original OCR name as hint if different from matched/edited name
                                hintText: item.ocrItemName != item.nameController.text ? item.ocrItemName : null,
                              ),
                              // If matched, name shouldn't be easily changed by user directly on review screen
                              // unless we add an "edit match" feature. For now, make it read-only if matched.
                              readOnly: item.isMatched, 
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    // Use controller
                                    controller: item.quantityController,
                                    decoration: InputDecoration(labelText: 'Quantity to Add (from receipt)'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    // Use selectedUnit
                                    value: _units.contains(item.selectedUnit) ? item.selectedUnit : _units.first,
                                    decoration: const InputDecoration(labelText: 'Unit'),
                                    items: _units.map((String unit) => DropdownMenuItem<String>(value: unit, child: Text(unit))).toList(),
                                    // Disable if matched and DB has a unit, otherwise allow change
                                    onChanged: item.isMatched && item.dbMaterialUnit != null ? null : (String? newValue) {
                                      if (newValue != null) {
                                        setState(() => item.selectedUnit = newValue);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: item.priceController,
                              decoration: const InputDecoration(labelText: 'Total Price Paid (for this line)'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                            const SizedBox(height: 8),
                             DropdownButtonFormField<String>(
                              // Use selectedCategory
                              value: _categories.contains(item.selectedCategory) ? item.selectedCategory : 'Uncategorized',
                              // If item is matched, category comes from DB and is read-only.
                              // If not matched, user must select a category.
                              decoration: InputDecoration(
                                labelText: 'Category',
                                errorText: !item.isMatched && item.selectedCategory == 'Uncategorized' && _categories.length > 1 
                                           ? 'Please select a category' // Basic validation for new items
                                           : null,
                              ),
                              items: _categories.map((String cat) => DropdownMenuItem<String>(value: cat, child: Text(cat))).toList(),
                              onChanged: item.isMatched ? null : (String? newValue) { // Read-only if matched
                                 if (newValue != null) {
                                   setState(() => item.selectedCategory = newValue);
                                 }
                              },
                            ),
                            // Display current stock if matched
                            if (item.isMatched && item.dbCurrentQuantity != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "Current in stock: ${item.dbCurrentQuantity} ${item.dbMaterialUnit ?? ''}",
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _isLoading ? null : FloatingActionButton.extended(
        onPressed: _confirmAndAddToInventory,
        // Update label
        label: const Text('Confirm & Save All'),
        icon: const Icon(Icons.check_circle_outline),
      ),
    );
  }
}
