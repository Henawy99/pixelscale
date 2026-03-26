import 'package:restaurantadmin/models/cart_item.dart';
import 'package:restaurantadmin/models/order.dart'
    as app_order; // Aliasing to avoid conflict
import 'package:restaurantadmin/models/order_item.dart';
import 'package:restaurantadmin/models/menu_item_material.dart'; // Assuming this model exists
import 'package:restaurantadmin/models/material_item.dart';
import 'package:restaurantadmin/services/order_id_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  static const String _employeeOrderTypeName =
      "Employee Meal"; // Define constant

  Future<List<MenuItemMaterial>> _fetchMenuItemMaterials(
    String menuItemId,
  ) async {
    try {
      final response = await _supabase
          .from('menu_item_materials')
          .select()
          .eq('menu_item_id', menuItemId);

      final List<MenuItemMaterial> materials = [];
      for (var itemData in response as List) {
        materials.add(
          MenuItemMaterial.fromJson(itemData as Map<String, dynamic>),
        );
      }
      print(
        "Fetched ${materials.length} materials for MenuItem ID: $menuItemId",
      );
      return materials;
    } catch (e) {
      print('Error fetching menu item materials for $menuItemId: $e');
      throw Exception(
        'Failed to fetch materials for menu item $menuItemId: $e',
      );
    }
  }

  Future<MaterialItem?> _fetchMaterialItem(String materialId) async {
    try {
      final response = await _supabase
          .from('material') // Corrected table name
          .select()
          .eq('id', materialId)
          .maybeSingle(); // Use maybeSingle to handle if item not found (returns null)

      if (response == null) {
        print("MaterialItem with ID $materialId not found.");
        return null;
      }

      print("Fetched MaterialItem ID: $materialId, Data: $response");
      return MaterialItem.fromJson(response);
    } catch (e) {
      print('Error fetching material item $materialId: $e');
      throw Exception('Failed to fetch material item $materialId: $e');
    }
  }

  Future<void> _updateMaterialQuantity(
    String materialId,
    double newQuantity,
  ) async {
    try {
      // Ensure your inventory table is 'material' and column is 'current_quantity'
      await _supabase
          .from('material') // Corrected table name
          .update({'current_quantity': newQuantity})
          .eq('id', materialId);
      print(
        "Successfully updated MaterialItem ID: $materialId to new quantity: $newQuantity",
      );
    } catch (e) {
      print('Error updating material quantity for $materialId: $e');
      throw Exception('Failed to update material quantity for $materialId: $e');
    }
  }

  Future<String> createOrderFromCart(
    // Changed to Future<String>
    List<CartItem> cartItems,
    String brandId, {
    String? orderTypeName,
    String? orderTypeId, // UUID
    double? percentageCut, // e.g., 0.15 for 15%
    double? serviceFee, // e.g., 0.50
    double? totalMaterialCost,
    double? overrideTotalPrice,
    required String paymentMethod, // e.g., 'cash', 'online', 'card_terminal'
    String? initialStatus, // Optional: allow overriding default status logic
    String? fulfillmentType, // Added: e.g., 'pickup', 'delivery'
    // New delivery-specific fields
    String? customerName,
    String? customerStreet,
    String? customerPostcode,
    String? customerCity,
    DateTime? requestedDeliveryTime,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('Cart is empty.');
    }

    // --- 1. Calculate total material requirements, costs, and check inventory ---
    Map<String, double> totalMaterialsRequired =
        {}; // materialId -> totalQuantityNeeded
    Map<String, MaterialItem> fetchedMaterialItems =
        {}; // Store fetched items to avoid re-fetching
    double totalMaterialCostForOrder = 0.0;

    print('[OrderService] Starting createOrderFromCart for brandId: $brandId');
    print('[OrderService] Number of cart items: ${cartItems.length}');

    for (var cartItem in cartItems) {
      final menuItem =
          cartItem.menuItemWithRecipe.menuItem; // Get the base MenuItem
      final List<MenuItemMaterial> materialsForMenuItem =
          await _fetchMenuItemMaterials(menuItem.id);
      double materialCostForOneMenuItem = 0.0;

      if (materialsForMenuItem.isEmpty) {
        print(
          "WARNING: No materials defined for menu item ${menuItem.name} (ID: ${menuItem.id}). Skipping inventory check and cost calculation for this item's materials.",
        );
      }

      for (var materialLink in materialsForMenuItem) {
        final requiredQtyForOne = materialLink.quantityUsed;
        final totalRequiredForCartItem = requiredQtyForOne * cartItem.quantity;

        totalMaterialsRequired.update(
          materialLink.materialId,
          (existingTotal) => existingTotal + totalRequiredForCartItem,
          ifAbsent: () => totalRequiredForCartItem,
        );

        MaterialItem? materialItem =
            fetchedMaterialItems[materialLink.materialId];
        if (materialItem == null) {
          materialItem = await _fetchMaterialItem(materialLink.materialId);
          if (materialItem == null) {
            throw Exception(
              'Material ${materialLink.materialId} not found in inventory.',
            );
          }
          fetchedMaterialItems[materialLink.materialId] = materialItem;
        }

        // Check for unit mismatch before proceeding
        if (materialLink.unitOfMeasureUsed.toLowerCase().trim() !=
            materialItem.unitOfMeasure.toLowerCase().trim()) {
          print(
            "Unit mismatch detected for material ${materialItem.name} (ID: ${materialItem.id}). "
            "Recipe unit: '${materialLink.unitOfMeasureUsed}', Stock unit: '${materialItem.unitOfMeasure}'.",
          );
          throw Exception(
            'Unit mismatch for material "${materialItem.name}". '
            'Recipe requires unit "${materialLink.unitOfMeasureUsed}" but stock is in unit "${materialItem.unitOfMeasure}". '
            'Unit conversion is required to proceed.',
          );
        }

        // Calculate cost for this material in one menu item
        if (materialItem.weightedAverageCost != null) {
          materialCostForOneMenuItem +=
              requiredQtyForOne * materialItem.weightedAverageCost!;
        } else {
          print(
            "Warning: Material ${materialItem.name} (ID: ${materialItem.id}) has no weightedAverageCost (average_unit_cost from DB). Cost for this material will be 0 in profit calculation.",
          );
        }
      }
      totalMaterialCostForOrder +=
          materialCostForOneMenuItem * cartItem.quantity;
    }

    // Check stock for each required material (soft check: allow order even if insufficient)
    for (var entry in totalMaterialsRequired.entries) {
      final materialId = entry.key;
      final quantityNeeded = entry.value;
      final materialItem = fetchedMaterialItems[materialId]!;

      if (materialItem.currentQuantity < quantityNeeded) {
        // Soft warning only; proceed with order creation. Stock may go negative after deduction.
        print(
          '[OrderService] WARNING: Insufficient stock for ${materialItem.name}. Required: $quantityNeeded ${materialItem.unitOfMeasure}, Available: ${materialItem.currentQuantity} ${materialItem.unitOfMeasure}. Proceeding anyway.',
        );
      }
    }

    // --- 2. Create Order and OrderItems in a transaction (simulated) ---
    print('[OrderService] Proceeding to create order object.');
    final orderId = _uuid.v4();

    // Generate custom order number
    final orderIdService = OrderIdService(_supabase);
    final orderIdData = await orderIdService.generateOrderId();
    final String customOrderNumber = orderIdData['orderId'];
    final int dailyOrderNumber = orderIdData['dailyOrderNumber'];

    print(
      '[OrderService] Generated order number: $customOrderNumber (Daily: $dailyOrderNumber)',
    );

    double actualSalePrice =
        0; // This is the sum of item prices, used for display
    for (var cartItemView in cartItems) {
      // Renamed to avoid conflict with loop var
      actualSalePrice += cartItemView.subtotal;
    }

    // Determine the final total price for the order record. Use override if provided.
    final double finalOrderTotalPrice = overrideTotalPrice ?? actualSalePrice;

    // For profit calculation, if it's an employee meal, revenue is 0.
    // Otherwise, it's the finalOrderTotalPrice (which might be the overridden one).
    double revenueForProfitCalc = (orderTypeName == "Employee Meal")
        ? 0.0
        : finalOrderTotalPrice;

    // Use the passed totalMaterialCost if available, otherwise fallback to the internally calculated one.
    final double costOfGoodsSold =
        totalMaterialCost ?? totalMaterialCostForOrder;

    double commissionAmountValue = 0;
    if (percentageCut != null && percentageCut > 0) {
      // Commission should be based on the finalOrderTotalPrice (potentially overridden price)
      commissionAmountValue = finalOrderTotalPrice * percentageCut;
    }
    double actualServiceFee = serviceFee ?? 0.0;

    // Profit = RevenueForProfitCalc - COGS - Commission - Fixed Fees
    final double calculatedProfit =
        revenueForProfitCalc -
        costOfGoodsSold -
        commissionAmountValue -
        actualServiceFee;

    // Determine initial status
    String currentStatus;
    if (initialStatus != null) {
      currentStatus = initialStatus;
    } else if (orderTypeName == _employeeOrderTypeName) {
      currentStatus = 'completed_employee_meal';
    } else if (paymentMethod == 'online') {
      currentStatus = 'pending_online_payment';
    } else if (paymentMethod == 'card_terminal') {
      currentStatus =
          'pending_terminal_init'; // New initial status before calling Edge Function
    } else {
      currentStatus = 'pending_payment'; // Default for cash or other methods
    }

    final newOrder = app_order.Order(
      id: orderId,
      orderNumber: customOrderNumber,
      dailyOrderNumber: dailyOrderNumber,
      brandId: brandId,
      orderItems: [], // Items are saved separately
      totalPrice:
          finalOrderTotalPrice, // Use the final (potentially overridden) total price
      status: currentStatus,
      createdAt: DateTime.now(),
      profit: calculatedProfit,
      orderTypeName: orderTypeName,
      orderTypeId: orderTypeId,
      commissionAmount: commissionAmountValue > 0
          ? commissionAmountValue
          : null,
      fixedServiceFee: actualServiceFee > 0 ? actualServiceFee : null,
      totalMaterialCost: costOfGoodsSold,
      paymentMethod: paymentMethod,
      fulfillmentType: fulfillmentType,
      // Add new delivery fields to the Order object
      customerName: customerName,
      customerStreet: customerStreet,
      customerPostcode: customerPostcode,
      customerCity: customerCity,
      requestedDeliveryTime: requestedDeliveryTime,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );

    print(
      '[OrderService] Attempting to insert order: ${newOrder.toJson()} with profit: $calculatedProfit, totalMaterialCost: $costOfGoodsSold, finalOrderTotalPrice: $finalOrderTotalPrice, paymentMethod: $paymentMethod, type: $orderTypeName, fulfillment: $fulfillmentType',
    );
    try {
      await _supabase.from('orders').insert(newOrder.toJson());
      print('[OrderService] Order inserted successfully. Order ID: $orderId');
    } catch (e) {
      print(
        '[OrderService] ERROR inserting order: $e. Order data: ${newOrder.toJson()}',
      );
      rethrow; // Re-throw the exception to be caught by CartScreen
    }

    for (var cartItem in cartItems) {
      final menuItem =
          cartItem.menuItemWithRecipe.menuItem; // Get the base MenuItem
      final orderItem = OrderItem(
        orderId: orderId,
        menuItemId: menuItem.id,
        menuItemName: menuItem.name,
        quantity: cartItem.quantity,
        priceAtPurchase: menuItem.price,
        brandId: brandId,
      );
      print(
        '[OrderService] Attempting to insert order item: ${orderItem.toJson()}',
      );
      try {
        await _supabase.from('order_items').insert(orderItem.toJson());
        print(
          '[OrderService] Order item for ${menuItem.name} inserted successfully.',
        ); // Use menuItem.name
      } catch (e) {
        print(
          '[OrderService] ERROR inserting order item: $e. OrderItem data: ${orderItem.toJson()}',
        );
        // Consider how to handle partial failure (e.g., order created but item failed)
        // For now, rethrow. A transaction would handle rollback.
        rethrow;
      }
    }

    // --- 3. Deduct materials from inventory ---
    // This should also be part of the atomic transaction
    print('[OrderService] Proceeding to deduct materials from inventory.');
    for (var entry in totalMaterialsRequired.entries) {
      final materialId = entry.key;
      final quantityToDeduct = entry.value;
      final materialItem = fetchedMaterialItems[materialId]!;
      double newStockLevel = materialItem.currentQuantity - quantityToDeduct;
      if (newStockLevel < 0) {
        print(
          '[OrderService] WARNING: Stock would go negative for ${materialItem.name} by ${newStockLevel.abs()}. Capping at 0.',
        );
        newStockLevel = 0;
      }

      print(
        '[OrderService] Attempting to update material quantity for Material ID: $materialId. New quantity: $newStockLevel',
      );
      try {
        await _updateMaterialQuantity(materialId, newStockLevel);
        print(
          "[OrderService] Deducted $quantityToDeduct ${materialItem.unitOfMeasure} from ${materialItem.name}. New stock: $newStockLevel",
        );
      } catch (e) {
        print(
          '[OrderService] ERROR updating material quantity for Material ID: $materialId: $e',
        );
        // Consider rollback or compensation logic here if a transaction isn't used.
        rethrow;
      }
    }

    print(
      "[OrderService] Order $orderId created successfully and materials deducted.",
    );
    return orderId; // Return the orderId
  }

  // New method for Stripe Terminal flow
  Future<Map<String, dynamic>?> initiateCardTerminalPayment(
    String orderId,
    double totalAmount, // This should be the final amount to charge
    String currency, // e.g., "eur"
  ) async {
    print(
      '[OrderService] Initiating Card Terminal Payment for Order ID: $orderId, Amount: $totalAmount $currency',
    );
    try {
      final response = await _supabase.functions.invoke(
        'create-terminal-payment-intent',
        body: {
          'orderId': orderId,
          'amount': (totalAmount * 100)
              .toInt(), // Stripe expects amount in cents
          'currency': currency.toLowerCase(),
        },
      );

      // Check if the function invocation itself failed (e.g., network issue, function not found)
      // Supabase Functions on Flutter: response.data will contain the body, status for HTTP status.
      // If status is not 2xx, it's an error.
      if (response.status < 200 || response.status >= 300) {
        String errorMessage =
            'Error calling create-terminal-payment-intent Edge Function.';
        if (response.data != null && response.data['error'] != null) {
          errorMessage = response.data['error'].toString();
        } else if (response.data != null) {
          errorMessage = response.data.toString();
        }
        print('[OrderService] $errorMessage');

        await _supabase
            .from('orders')
            .update({'status': 'terminal_init_failed'})
            .eq('id', orderId);
        return {'error': errorMessage};
      }

      // If the function executed but returned an error in its JSON response
      final responseData = response.data as Map<String, dynamic>?;
      if (responseData != null && responseData.containsKey('error')) {
        print(
          '[OrderService] Edge Function returned an error: ${responseData['error']}',
        );
        await _supabase
            .from('orders')
            .update({
              'status': 'terminal_init_failed',
            }) // Or a more specific error status
            .eq('id', orderId);
        return {'error': responseData['error']};
      }

      print(
        '[OrderService] create-terminal-payment-intent call successful. Response data: $responseData',
      );
      return responseData;
    } catch (e) {
      print('[OrderService] Exception during initiateCardTerminalPayment: $e');
      await _supabase
          .from('orders')
          .update({'status': 'terminal_init_failed'})
          .eq('id', orderId);
      return {'error': 'Exception: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>?> cancelTerminalPayment(
    String orderId,
    String paymentIntentId,
  ) async {
    print(
      '[OrderService] Attempting to cancel terminal payment for Order ID: $orderId, PI: $paymentIntentId',
    );
    try {
      final response = await _supabase.functions.invoke(
        'cancel-terminal-payment',
        body: {'orderId': orderId, 'paymentIntentId': paymentIntentId},
      );

      if (response.status < 200 || response.status >= 300) {
        String errorMessage =
            'Error calling cancel-terminal-payment Edge Function.';
        if (response.data != null && response.data['error'] != null) {
          errorMessage = response.data['error'].toString();
        } else if (response.data != null) {
          errorMessage = response.data.toString();
        }
        print('[OrderService] $errorMessage');
        // Optionally update order status here if the function call itself failed before Stripe interaction
        // await _supabase.from('orders').update({'status': 'terminal_cancel_invoke_failed'}).eq('id', orderId);
        return {'error': errorMessage};
      }

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData != null && responseData.containsKey('error')) {
        print(
          '[OrderService] cancel-terminal-payment Edge Function returned an error: ${responseData['error']}',
        );
        // Status should be updated by the Edge function or webhook in this case
        return {
          'error': responseData['error'],
          'details': responseData['details'],
        };
      }

      print(
        '[OrderService] cancel-terminal-payment call successful. Response data: $responseData',
      );
      // The Edge Function updates the order status to 'cancelled_terminal' or 'terminal_cancel_failed_stripe'
      // Realtime listener in UI should pick this up.
      return responseData;
    } catch (e) {
      print('[OrderService] Exception during cancelTerminalPayment: $e');
      // Optionally update order status here
      // await _supabase.from('orders').update({'status': 'terminal_cancel_exception'}).eq('id', orderId);
      return {'error': 'Exception: ${e.toString()}'};
    }
  }

  Future<void> cancelOrder(String orderId, bool returnStock) async {
    print(
      '[OrderService] Attempting to cancel order ID: $orderId, Return stock: $returnStock',
    );

    // 1. Fetch all order items for this order
    final List<dynamic> orderItemsResponse;
    try {
      orderItemsResponse = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId);
    } catch (e) {
      print('[OrderService] ERROR fetching order items for order $orderId: $e');
      throw Exception('Failed to fetch order items for cancellation: $e');
    }

    final List<OrderItem> orderItems = orderItemsResponse
        .map((data) => OrderItem.fromJson(data as Map<String, dynamic>))
        .toList();

    if (orderItems.isEmpty && returnStock) {
      print(
        '[OrderService] No order items found for order $orderId to return stock from, but proceeding to cancel status.',
      );
    }

    // 2. If returning stock, process material returns
    if (returnStock) {
      for (var orderItem in orderItems) {
        // Skip items without a menu item ID (e.g., scanned orders without menu item matching)
        if (orderItem.menuItemId == null || orderItem.menuItemId!.isEmpty) {
          print(
            '[OrderService] Skipping stock return for item "${orderItem.menuItemName}" - no menuItemId',
          );
          continue;
        }

        final List<MenuItemMaterial> materialsForMenuItem =
            await _fetchMenuItemMaterials(orderItem.menuItemId!);

        for (var mim in materialsForMenuItem) {
          final double quantityToReturn = mim.quantityUsed * orderItem.quantity;

          MaterialItem? materialItem;
          try {
            materialItem = await _fetchMaterialItem(mim.materialId);
          } catch (e) {
            print(
              '[OrderService] WARNING: Error fetching Material ID ${mim.materialId} while trying to return stock: $e. Skipping this material.',
            );
            continue;
          }

          if (materialItem == null) {
            print(
              '[OrderService] WARNING: Material ID ${mim.materialId} not found in "material" table while trying to return stock. Skipping this material.',
            );
            continue;
          }

          final currentMaterialStock = materialItem.currentQuantity;
          final materialName = materialItem.name;
          final materialUnit = materialItem.unitOfMeasure;

          final newStockLevel = currentMaterialStock + quantityToReturn;

          try {
            await _updateMaterialQuantity(mim.materialId, newStockLevel);
            print(
              '[OrderService] Returned $quantityToReturn $materialUnit of $materialName (ID: ${mim.materialId}) to stock. New stock: $newStockLevel',
            );

            // Log the stock return
            await _supabase.from('inventory_log').insert({
              'material_id': mim.materialId,
              'material_name': materialName,
              'change_type': 'STOCK_RETURNED_CANCEL',
              'quantity_change': quantityToReturn,
              'new_quantity_after_change': newStockLevel,
              'source_details': 'Order Cancelled: $orderId',
            });
          } catch (e) {
            print(
              '[OrderService] ERROR returning stock for material ID ${mim.materialId}: $e. Order cancellation will proceed, but this item stock might be incorrect.',
            );
            // Continue to cancel order even if one material stock update fails
          }
        }
      }
    }

    // 3. Update order status to 'cancelled'
    try {
      final newStatus = returnStock
          ? 'cancelled_stock_returned'
          : 'cancelled_discarded';
      await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);
      print('[OrderService] Order ID: $orderId status updated to $newStatus.');
    } catch (e) {
      print('[OrderService] ERROR updating order status for ID $orderId: $e');
      throw Exception('Failed to update order status: $e');
    }
  }

  Future<app_order.Order?> createOrderFromScannedData(
    Map<String, dynamic> scannedData, {
    String? fulfillmentType, // Added parameter
  }) async {
    final supabase = Supabase.instance.client;
    final uuid = const Uuid();

    try {
      print('[OrderService] Creating order from scanned data: $scannedData');

      // --- 1. Extract and Validate Basic Order Info ---
      String? brandNameFromScan = scannedData['brandName'] as String?;
      String? customerName = scannedData['customerName'] as String?;
      String? customerStreet = scannedData['customerStreet'] as String?;
      String? customerPostcode = scannedData['customerPostcode'] as String?;
      String? customerCity = scannedData['customerCity'] as String?;
      String? orderTypeName = scannedData['orderTypeName'] as String?;
      String? paymentMethod = scannedData['paymentMethod'] as String?;

      double? totalPriceFromScan = (scannedData['totalPrice'] as num?)
          ?.toDouble();
      if (totalPriceFromScan == null) {
        print(
          '[OrderService] Warning: Total price from scan is null. Will fallback to calculated subtotal.',
        );
      }

      DateTime createdAt;
      if (scannedData['createdAt'] != null) {
        createdAt =
            DateTime.tryParse(scannedData['createdAt'] as String) ??
            DateTime.now();
      } else {
        print(
          '[OrderService] Warning: createdAt from scan is null. Using current time.',
        );
        createdAt = DateTime.now();
      }

      DateTime? requestedDeliveryTime;
      if (scannedData['requestedDeliveryTime'] != null) {
        requestedDeliveryTime = DateTime.tryParse(
          scannedData['requestedDeliveryTime'] as String,
        );
      }

      // --- 2. Determine Brand ID ---
      // Try multiple strategies in order: explicit brandId in scan, case-insensitive name mapping,
      // DB lookup by name, then infer from first item.
      String? brandId = scannedData['brandId'] as String?;
      if (brandId == null && brandNameFromScan != null) {
        final normalized = brandNameFromScan.trim().toUpperCase();
        if (normalized == 'DEVILS SMASH BURGER') {
          brandId = '4446a388-aaa7-402f-be4d-b82b23797415';
        } else if (normalized == 'CRISPY CHICKEN LAB') {
          brandId = '8ec82a94-89f5-4603-bb35-c47c78d66d2a';
        } else if (normalized == 'THE BOWL SPOT') {
          brandId = '59bf0f09-ab58-48a0-9b3f-13c7709c8600';
        } else if (normalized == 'TACOTASTIC') {
          // If present in DB, the next step will also find it; this is a fast path if known.
        }
      }
      if (brandId == null && brandNameFromScan != null) {
        final exact = await supabase
            .from('brands')
            .select('id')
            .eq('name', brandNameFromScan)
            .maybeSingle();
        if (exact != null && exact['id'] is String) {
          brandId = exact['id'] as String;
        } else {
          try {
            final ilike = await supabase
                .from('brands')
                .select('id,name')
                .ilike('name', brandNameFromScan);
            if (ilike.isNotEmpty && ilike.first['id'] is String) {
              brandId = ilike.first['id'] as String;
            }
          } catch (_) {
            // ignore if ilike unsupported
          }
        }
      }
      // Fallback: infer brand from first order item menuItemId
      if (brandId == null &&
          scannedData['orderItems'] is List &&
          (scannedData['orderItems'] as List).isNotEmpty) {
        final first = (scannedData['orderItems'] as List).first;
        String? firstMenuItemId;
        if (first is Map<String, dynamic>) {
          firstMenuItemId = first['menuItemId'] as String?;
        }
        if (firstMenuItemId != null) {
          final mi = await supabase
              .from('menu_items')
              .select('brand_id')
              .eq('id', firstMenuItemId)
              .maybeSingle();
          if (mi != null && mi['brand_id'] is String) {
            brandId = mi['brand_id'] as String;
          }
        }
      }
      if (brandId == null) {
        print(
          '[OrderService] Error: Could not determine brandId for brand: $brandNameFromScan',
        );
        throw Exception(
          'Brand ID could not be determined for $brandNameFromScan.',
        );
      }

      // --- 3. Process Order Items ---
      // Normalize Gemini variants: some responses use 'items' with keys 'item_id', 'item_name'
      if (scannedData['orderItems'] is! List && scannedData['items'] is List) {
        final List normalized = [];
        for (final it in (scannedData['items'] as List)) {
          if (it is Map<String, dynamic>) {
            normalized.add({
              'menuItemId': it['menu_item_id'] ?? it['item_id'],
              'menuItemName':
                  it['menu_item_name'] ?? it['item_name'] ?? it['name'],
              'quantity': it['quantity'],
            });
          }
        }
        scannedData['orderItems'] = normalized;
      }

      List<OrderItem> orderItems = [];
      double calculatedSubtotal =
          0.0; // Recalculate based on DB prices for accuracy

      if (scannedData['orderItems'] is List) {
        for (var itemData in (scannedData['orderItems'] as List)) {
          if (itemData is Map<String, dynamic>) {
            String? menuItemId = itemData['menuItemId'] as String?;
            String? menuItemNameOnReceipt =
                itemData['menuItemName'] as String?; // Name from receipt
            int? quantity = (itemData['quantity'] as num?)?.toInt();

            if (quantity == null || quantity <= 0) {
              print(
                '[OrderService] Warning: Skipping invalid order item data (bad quantity): $itemData',
              );
              continue;
            }

            // Try to fetch/resolve menu item details from DB to get the current price
            Map<String, dynamic>? menuItemResponse;
            if (menuItemId != null) {
              menuItemResponse = await supabase
                  .from('menu_items')
                  .select('id, price, name')
                  .eq('id', menuItemId)
                  .maybeSingle();
            }

            if (menuItemResponse == null &&
                (menuItemNameOnReceipt?.trim().isNotEmpty ?? false)) {
              // Exact name match within brand
              final exactByName = await supabase
                  .from('menu_items')
                  .select('id, price, name')
                  .eq('brand_id', brandId)
                  .eq('name', menuItemNameOnReceipt ?? '')
                  .maybeSingle();
              if (exactByName != null) {
                menuItemResponse = exactByName;
              } else {
                try {
                  final ilikeByName = await supabase
                      .from('menu_items')
                      .select('id, price, name')
                      .eq('brand_id', brandId)
                      .ilike('name', '%$menuItemNameOnReceipt%');
                  if (ilikeByName.isNotEmpty) {
                    final first = ilikeByName.first;
                    menuItemResponse = first;
                  }
                } catch (_) {
                  // ilike may not be supported depending on config
                }
              }
            }

            if (menuItemResponse == null) {
              print(
                '[OrderService] Warning: MenuItem not resolved for item: $itemData. Skipping.',
              );
              continue;
            }
            menuItemId = (menuItemResponse['id'] as String?) ?? menuItemId;

            double priceAtPurchase = (menuItemResponse['price'] as num)
                .toDouble();
            String dbMenuItemName = menuItemResponse['name'] as String;

            orderItems.add(
              OrderItem(
                orderId: '', // Will be set after order is created
                menuItemId: menuItemId!,
                menuItemName:
                    menuItemNameOnReceipt ??
                    dbMenuItemName, // Prefer name from receipt if available
                quantity: quantity,
                priceAtPurchase: priceAtPurchase,
                brandId: brandId, // Associate item with the order's brand
              ),
            );
            calculatedSubtotal += priceAtPurchase * quantity;
          }
        }
      }

      if (orderItems.isEmpty) {
        print(
          '[OrderService] Error: No valid order items found in scanned data.',
        );
        throw Exception('No valid order items to create order.');
      }

      // --- 4. Create Order Object ---
      // Decide if totalPriceFromScan or calculatedSubtotal is more authoritative.
      // For now, using totalPriceFromScan as it's what the customer saw.
      // Profit calculation would need COGS, which is complex from just a scan.
      final newOrderId = uuid.v4();

      // Generate custom order number
      final orderIdService = OrderIdService(_supabase);
      final orderIdData = await orderIdService.generateOrderId();
      final String customOrderNumber = orderIdData['orderId'];
      final int dailyOrderNumber = orderIdData['dailyOrderNumber'];

      print(
        '[OrderService] Generated order number for scanned order: $customOrderNumber (Daily: $dailyOrderNumber)',
      );

      final String? platformOrderId = scannedData['platformOrderId'] as String?;

      // --- Geocode Address ---
      double? deliveryLatitude;
      double? deliveryLongitude;

      if (customerStreet != null &&
          customerStreet.isNotEmpty &&
          customerCity != null &&
          customerCity.isNotEmpty) {
        String fullAddress = customerStreet;
        if (customerPostcode != null && customerPostcode.isNotEmpty) {
          fullAddress += ', $customerPostcode';
        }
        fullAddress += ', $customerCity';

        print('[OrderService] Attempting to geocode address: $fullAddress');
        try {
          // Construct the body according to the geocode-address function's expected interface
          final geocodeRequestBody = {
            'street': customerStreet,
            'city': customerCity,
            'postcode': customerPostcode,
            'country':
                'AT', // Assuming Austria. This might need to be configurable.
          };
          print('[OrderService] Geocoding request body: $geocodeRequestBody');

          final geocodeResponse = await supabase.functions.invoke(
            'geocode-address',
            body: geocodeRequestBody,
          );
          if (geocodeResponse.data != null &&
              geocodeResponse.data['latitude'] != null &&
              geocodeResponse.data['longitude'] != null) {
            deliveryLatitude = (geocodeResponse.data['latitude'] as num)
                .toDouble();
            deliveryLongitude = (geocodeResponse.data['longitude'] as num)
                .toDouble();
            print(
              '[OrderService] Geocoding successful: Lat: $deliveryLatitude, Lng: $deliveryLongitude',
            );
          } else {
            print(
              '[OrderService] Warning: Geocoding failed or returned no coordinates for address "$fullAddress". Response: ${geocodeResponse.data}',
            );
          }
        } catch (e) {
          print(
            '[OrderService] Error during geocoding for address "$fullAddress": $e',
          );
        }
      } else {
        print(
          '[OrderService] Warning: Insufficient address details for geocoding (Street: $customerStreet, City: $customerCity).',
        );
      }

      final newOrder = app_order.Order(
        id: newOrderId,
        orderNumber: customOrderNumber,
        dailyOrderNumber: dailyOrderNumber,
        brandId: brandId,
        brandName: brandNameFromScan, // Store the name as identified from scan
        orderItems: [], // Items will be inserted separately
        totalPrice:
            totalPriceFromScan ??
            calculatedSubtotal, // Fallback to calculated subtotal if scan total missing
        status: 'confirmed', // Orders are auto-confirmed
        createdAt: createdAt,
        paymentMethod: paymentMethod ?? 'unknown', // Default if not found
        orderTypeName: orderTypeName,
        fulfillmentType: fulfillmentType, // Set the fulfillment type
        customerName: customerName,
        customerStreet: customerStreet,
        customerPostcode: customerPostcode,
        customerCity: customerCity,
        requestedDeliveryTime: requestedDeliveryTime,
        platformOrderId: platformOrderId, // Store platform-specific ID
        deliveryLatitude: deliveryLatitude, // Set geocoded latitude
        deliveryLongitude: deliveryLongitude, // Set geocoded longitude
        // Profit, commission, service_fee, total_material_cost would be harder to get from scan
        // and might be calculated later or set to null/0 initially.
      );

      // --- 5. Insert Order and OrderItems into Supabase (Transaction recommended) ---
      // For simplicity, doing sequential inserts. Wrap in a transaction in production.
      await supabase.from('orders').insert(newOrder.toJson());

      for (var item in orderItems) {
        // Update orderId for each item
        final itemToInsert = OrderItem(
          id: uuid.v4(), // Generate ID for order_item
          orderId: newOrderId,
          menuItemId: item.menuItemId,
          menuItemName: item.menuItemName,
          quantity: item.quantity,
          priceAtPurchase: item.priceAtPurchase,
          brandId: item.brandId,
        );
        await supabase.from('order_items').insert(itemToInsert.toJson());
      }

      print(
        '[OrderService] Order $newOrderId created successfully from scanned data.',
      );
      // Return the full order object by fetching it again, or construct it with the items
      // For now, returning the initially constructed one (without items populated in the list itself)
      return newOrder;
    } catch (e) {
      print('[OrderService] Error creating order from scanned data: $e');
      // Consider re-throwing or returning null/error object
      return null;
    }
  }
}
