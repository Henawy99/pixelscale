import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurantadmin/models/cart_item.dart';
import 'package:restaurantadmin/models/menu_item_material.dart';
import 'dart:async'; // For StreamSubscription
import 'package:restaurantadmin/providers/cart_provider.dart';
import 'package:restaurantadmin/services/order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/screens/order_type_settings_screen.dart'; // For OrderTypeConfig model
import 'package:restaurantadmin/utils/web_printing_service.dart'; // Import the printing service
import 'package:restaurantadmin/screens/orders_screen.dart'; // Import OrdersScreen for navigation

// This widget will be the main content of the cart, reusable in CartScreen and OrderableBrandMenuScreen (web)
class CartViewWidget extends StatefulWidget {
  final List<OrderTypeConfig>?
  orderTypeConfigs; // Make nullable for CartScreen usage
  final String?
  brandId; // Make nullable, will be provided by OrderableBrandMenuScreen

  const CartViewWidget({super.key, this.orderTypeConfigs, this.brandId});

  @override
  State<CartViewWidget> createState() => _CartViewWidgetState();
}

class _CartViewWidgetState extends State<CartViewWidget> {
  final OrderService _orderService = OrderService();
  bool _isCreatingOrder = false;
  OrderTypeConfig? _selectedOrderTypeConfig;
  static const String _employeeOrderTypeName = "Employee Meal";

  double? _overriddenTotalPrice;
  bool _isEditingTotalPrice = false;
  final TextEditingController _totalPriceController = TextEditingController();

  String? _selectedPaymentMethod;
  String? _selectedFulfillmentType; // Added for Delivery/Pickup

  // Delivery specific fields
  final GlobalKey<FormState> _deliveryFormKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerStreetController =
      TextEditingController();
  final TextEditingController _customerPostcodeController =
      TextEditingController();
  final TextEditingController _customerCityController = TextEditingController();
  DateTime? _requestedDeliveryTime;

  bool _isProcessingTerminalPayment = false;
  String? _terminalPaymentMessage;
  String? _currentOrderIdForTerminalPayment;
  String? _currentStripePaymentIntentIdForCancellation;
  StreamSubscription<List<Map<String, dynamic>>>? _orderRealtimeSubscription;

  bool _terminalPaymentAttemptFailed = false;
  String? _failedOrderId;
  double? _failedOrderAmount;
  String? _failedOrderCurrency;

  @override
  void initState() {
    super.initState();
    // Potentially initialize _totalPriceController if needed based on cartProvider,
    // but typically done when editing starts.
  }

  @override
  void dispose() {
    _totalPriceController.dispose();
    _customerNameController.dispose();
    _customerStreetController.dispose();
    _customerPostcodeController.dispose();
    _customerCityController.dispose();
    _orderRealtimeSubscription?.cancel();
    super.dispose();
  }

  void _listenToOrderStatus(String orderId) {
    _orderRealtimeSubscription?.cancel();
    _currentOrderIdForTerminalPayment = orderId;
    _currentStripePaymentIntentIdForCancellation = null;
    _terminalPaymentAttemptFailed = false;
    print(
      "[CartViewWidget] Subscribing to Realtime updates for order ID: $orderId",
    );

    _orderRealtimeSubscription = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .listen(
          (List<Map<String, dynamic>> data) {
            print(
              "[CartViewWidget] DEBUG LISTENER: Data received at ${DateTime.now()} for order $orderId: $data",
            );
            if (!mounted || data.isEmpty) {
              print(
                "[CartViewWidget] DEBUG LISTENER: Not mounted or data empty. Returning.",
              );
              return;
            }

            final updatedOrderData = data.first;
            final newStatus = updatedOrderData['status'] as String?;
            final newStripePaymentIntentId =
                updatedOrderData['stripe_payment_intent_id'] as String?;

            print(
              "[CartViewWidget] DEBUG LISTENER: Processing newStatus = $newStatus for order $orderId",
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                print(
                  "[CartViewWidget] PostFrameCallback: Widget no longer mounted for order $orderId. Aborting UI update.",
                );
                return;
              }

              setState(() {
                if (newStripePaymentIntentId != null &&
                    newStripePaymentIntentId.isNotEmpty) {
                  _currentStripePaymentIntentIdForCancellation =
                      newStripePaymentIntentId;
                }

                print(
                  "[CartViewWidget] PostFrameCallback (setState): newStatus = $newStatus for order $orderId",
                );

                bool paymentProcessEnded = false;
                String finalMessage = '';
                Color snackbarColor = Colors.red;

                if (newStatus == 'paid') {
                  print(
                    "[CartViewWidget] PostFrameCallback (setState): 'paid' status detected. Payment successful state update.",
                  );
                  finalMessage =
                      'Payment Successful (Order ID: ${orderId.substring(0, 8)})!';
                  snackbarColor = Colors.green;
                  paymentProcessEnded = true;
                  // Navigation is now handled in _createOrder for immediate effect
                  _isProcessingTerminalPayment = false;
                  _terminalPaymentAttemptFailed = false;
                } else if (newStatus == 'failed' ||
                    newStatus == 'terminal_init_failed' ||
                    newStatus == 'terminal_comms_failed' ||
                    newStatus == 'terminal_action_failed' ||
                    newStatus == 'cancelled_terminal' ||
                    newStatus == 'terminal_cancel_failed_stripe') {
                  print(
                    "[CartViewWidget] PostFrameCallback (setState): Failure/ended status '$newStatus' detected.",
                  );
                  finalMessage = 'Payment process ended: $newStatus.';
                  if (newStatus == 'cancelled_terminal') {
                    finalMessage = 'Payment cancelled by POS.';
                    snackbarColor = Colors.orange;
                  }
                  paymentProcessEnded = true;
                  _terminalPaymentAttemptFailed = true;
                  _failedOrderId = orderId;
                } else if (newStatus == 'processing_terminal') {
                  _terminalPaymentMessage =
                      'Processing on terminal... Please ask customer to use card reader.';
                } else if (newStatus == 'terminal_awaiting_card') {
                  _terminalPaymentMessage =
                      'Terminal ready. Waiting for card...';
                } else if (newStatus != null) {
                  _terminalPaymentMessage = 'Order status: $newStatus';
                }

                if (paymentProcessEnded) {
                  _terminalPaymentMessage = finalMessage;
                  _isProcessingTerminalPayment = false;

                  if (newStatus != 'paid') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_terminalPaymentMessage!),
                        backgroundColor: snackbarColor,
                      ),
                    );
                  }
                  _orderRealtimeSubscription?.cancel();
                  if (newStatus == 'paid' ||
                      newStatus == 'cancelled_terminal') {
                    _currentOrderIdForTerminalPayment = null;
                    _currentStripePaymentIntentIdForCancellation = null;
                  }
                }
              });
            });
          },
          onError: (error) {
            print(
              '[CartViewWidget] DEBUG LISTENER: Realtime subscription error for order $orderId: $error',
            );
            if (mounted) {
              setState(() {
                _terminalPaymentMessage =
                    "Realtime connection error. Check order status manually.";
                _isProcessingTerminalPayment = false;
                _terminalPaymentAttemptFailed = true;
                _failedOrderId = orderId;
                _currentStripePaymentIntentIdForCancellation = null;
              });
            }
          },
        );
  }

  Future<void> _cancelCurrentTerminalPayment() async {
    if (_currentOrderIdForTerminalPayment != null &&
        _currentStripePaymentIntentIdForCancellation != null) {
      print(
        "[CartViewWidget] Attempting to cancel terminal payment for Order ID: $_currentOrderIdForTerminalPayment, PI: $_currentStripePaymentIntentIdForCancellation",
      );
      setState(() {
        _terminalPaymentMessage = "Attempting to cancel payment...";
      });

      final result = await _orderService.cancelTerminalPayment(
        _currentOrderIdForTerminalPayment!,
        _currentStripePaymentIntentIdForCancellation!,
      );

      if (!mounted) return;

      if (result != null && result.containsKey('error')) {
        setState(() {
          _terminalPaymentMessage = "Cancellation Error: ${result['error']}";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cancellation Error: ${result['error']}"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        setState(() {
          _terminalPaymentMessage =
              "Cancellation request sent. Waiting for confirmation...";
        });
      }
    } else {
      print(
        "[CartViewWidget] Cannot cancel: No current order ID or payment intent ID for terminal payment.",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active terminal payment to cancel.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _retryTerminalPayment() async {
    if (_failedOrderId == null ||
        _failedOrderAmount == null ||
        _failedOrderCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot retry: Missing order details for retry.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    print(
      "[CartViewWidget] Retrying terminal payment for Order ID: $_failedOrderId",
    );

    setState(() {
      _isProcessingTerminalPayment = true;
      _terminalPaymentAttemptFailed = false;
      _terminalPaymentMessage = 'Retrying terminal payment...';
      _currentOrderIdForTerminalPayment = _failedOrderId;
    });

    _listenToOrderStatus(_failedOrderId!);

    final terminalResponse = await _orderService.initiateCardTerminalPayment(
      _failedOrderId!,
      _failedOrderAmount!,
      _failedOrderCurrency!,
    );

    if (!mounted) return;

    if (terminalResponse != null && terminalResponse.containsKey('error')) {
      setState(() {
        _terminalPaymentMessage = 'Retry Error: ${terminalResponse['error']}';
        _isProcessingTerminalPayment = false;
        _terminalPaymentAttemptFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retry Error: ${terminalResponse['error']}'),
          backgroundColor: Colors.red,
        ),
      );
      _orderRealtimeSubscription?.cancel();
    } else if (terminalResponse == null) {
      setState(() {
        _terminalPaymentMessage = 'Retry Error: No response from server.';
        _isProcessingTerminalPayment = false;
        _terminalPaymentAttemptFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retry Error: No response from server.'),
          backgroundColor: Colors.red,
        ),
      );
      _orderRealtimeSubscription?.cancel();
    }
  }

  void _changePaymentMethodAfterFailure() {
    setState(() {
      _isProcessingTerminalPayment = false;
      _terminalPaymentAttemptFailed = false;
      _terminalPaymentMessage = null;
      _selectedPaymentMethod = null;
      _failedOrderId = null;
      _failedOrderAmount = null;
      _failedOrderCurrency = null;
      _currentOrderIdForTerminalPayment = null;
      _currentStripePaymentIntentIdForCancellation = null;
      _orderRealtimeSubscription?.cancel();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select a new payment method.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<double> _calculateTotalMaterialCostForCart(
    List<CartItem> cartItems,
  ) async {
    double totalMaterialCost = 0;
    final supabase = Supabase.instance.client;

    for (var cartItem in cartItems) {
      final menuItem = cartItem.menuItemWithRecipe.menuItem;
      double totalMaterialsCostForOneMenuItem = 0;
      try {
        if (cartItem.menuItemWithRecipe.recipe.isNotEmpty) {
          for (var resolvedMaterial in cartItem.menuItemWithRecipe.recipe) {
            totalMaterialsCostForOneMenuItem +=
                resolvedMaterial.totalCostForRecipe;
          }
        } else {
          final mimResponse = await supabase
              .from('menu_item_materials')
              .select(
                '*, material_id(id, name, item_image_url, average_unit_cost)',
              )
              .eq('menu_item_id', menuItem.id);

          if (mimResponse.isNotEmpty) {
            for (var mimJsonData in mimResponse as List) {
              final menuItemMaterial = MenuItemMaterial.fromJson(
                mimJsonData as Map<String, dynamic>,
              );
              double? materialWac;
              final materialData = mimJsonData['material_id'];
              if (materialData is Map<String, dynamic> &&
                  materialData['average_unit_cost'] != null) {
                materialWac = (materialData['average_unit_cost'] as num?)
                    ?.toDouble();
              } else {
                final matResponseData = await supabase
                    .from('material')
                    .select('average_unit_cost')
                    .eq('id', menuItemMaterial.materialId)
                    .maybeSingle();
                if (matResponseData != null) {
                  materialWac = (matResponseData['average_unit_cost'] as num?)
                      ?.toDouble();
                }
              }
              if (materialWac != null) {
                totalMaterialsCostForOneMenuItem +=
                    menuItemMaterial.quantityUsed * materialWac;
              }
            }
          }
        }
        totalMaterialCost +=
            totalMaterialsCostForOneMenuItem * cartItem.quantity;
      } catch (e) {
        print(
          "Error calculating material cost for cart item ${menuItem.name} in _calculateTotalMaterialCostForCart: $e",
        );
      }
    }
    return totalMaterialCost;
  }

  String _generateReceiptHtml(
    List<CartItem> items,
    double totalPrice,
    String brandName,
    String? orderTypeName,
    String? orderId,
    String? fulfillmentType,
  ) {
    final now = DateTime.now();
    final String formattedDate =
        "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    var receiptContent = StringBuffer();
    receiptContent.writeln('<html><head><title>Receipt</title>');
    receiptContent.writeln('<style>');
    receiptContent.writeln(
      'body { font-family: monospace; font-size: 10pt; margin: 0; padding: 5mm; width: 72mm; }',
    );
    receiptContent.writeln(
      '.header { text-align: center; margin-bottom: 10px; }',
    );
    receiptContent.writeln('.header h1 { margin: 0; font-size: 14pt; }');
    receiptContent.writeln(
      '.item-line { display: flex; justify-content: space-between; margin-bottom: 2px; }',
    );
    receiptContent.writeln('.item-name { flex-grow: 1; }');
    receiptContent.writeln(
      '.item-qty-price { text-align: right; min-width: 80px; }',
    );
    receiptContent.writeln(
      '.totals { margin-top: 10px; border-top: 1px dashed black; padding-top: 5px; }',
    );
    receiptContent.writeln(
      '.footer { text-align: center; margin-top: 15px; font-size: 8pt; }',
    );
    receiptContent.writeln('</style></head><body>');
    receiptContent.writeln('<div class="header">');
    receiptContent.writeln('<h1>${brandName.toUpperCase()}</h1>');
    if (orderTypeName != null) {
      receiptContent.writeln('<p>Order Type: $orderTypeName</p>');
    } else {
      receiptContent.writeln('<p>Standard Order</p>');
    }
    if (fulfillmentType != null) {
      receiptContent.writeln(
        '<p>Fulfillment: ${fulfillmentType[0].toUpperCase()}${fulfillmentType.substring(1)}</p>',
      );
    }
    if (orderId != null) {
      receiptContent.writeln('<p>Order ID: $orderId</p>');
    }
    receiptContent.writeln('<p>$formattedDate</p>');
    receiptContent.writeln('</div>');
    for (var item in items) {
      final menuItem = item.menuItemWithRecipe.menuItem;
      receiptContent.writeln('<div class="item-line">');
      receiptContent.writeln(
        '  <span class="item-name">${item.quantity}x ${menuItem.name}</span>',
      );
      receiptContent.writeln(
        '  <span class="item-qty-price">${(menuItem.price * item.quantity).toStringAsFixed(2)} EUR</span>',
      );
      receiptContent.writeln('</div>');
    }
    receiptContent.writeln('<div class="totals">');
    receiptContent.writeln(
      '  <div class="item-line"><strong>TOTAL:</strong> <strong>${totalPrice.toStringAsFixed(2)} EUR</strong></div>',
    );
    receiptContent.writeln('</div>');
    receiptContent.writeln('<div class="footer">Thank you!</div>');
    receiptContent.writeln('</body></html>');
    return receiptContent.toString();
  }

  Future<void> _createOrder(
    BuildContext context,
    CartProvider cartProvider, {
    OrderTypeConfig? orderTypeConfig,
  }) async {
    if (cartProvider.items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }

    final String? brandIdForOrder =
        widget.brandId ?? cartProvider.activeBrandId;
    if (brandIdForOrder == null || brandIdForOrder.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not determine brand for the order.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedFulfillmentType == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Delivery or Pickup.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_selectedPaymentMethod == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Validate delivery form if fulfillment type is delivery
    if (_selectedFulfillmentType == 'delivery') {
      if (!_deliveryFormKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required delivery details.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Stop order creation if delivery details are invalid
      }
    }

    setState(() {
      _isCreatingOrder = true;
      _terminalPaymentAttemptFailed = false;
      if (_selectedPaymentMethod == 'card_terminal') {
        _isProcessingTerminalPayment = true;
        _terminalPaymentMessage = 'Creating order and contacting terminal...';
        _currentStripePaymentIntentIdForCancellation = null;
      }
    });

    try {
      final List<CartItem> currentCartItemsForOrder = List.from(
        cartProvider.items.values,
      );
      final double totalMaterialCostForThisOrder =
          await _calculateTotalMaterialCostForCart(currentCartItemsForOrder);
      final double finalPriceForOrder =
          _overriddenTotalPrice ?? cartProvider.totalPrice;
      final String paymentMethodToSave = _selectedPaymentMethod!;
      final String fulfillmentTypeToSave = _selectedFulfillmentType!;

      String? customerName;
      String? customerStreet;
      String? customerPostcode;
      String? customerCity;
      DateTime? requestedDeliveryTime;
      double? deliveryLatitude; // Declare here
      double? deliveryLongitude; // Declare here

      if (fulfillmentTypeToSave == 'delivery') {
        customerName = _customerNameController.text;
        customerStreet = _customerStreetController.text;
        customerPostcode = _customerPostcodeController.text;
        customerCity = _customerCityController.text;
        requestedDeliveryTime = _requestedDeliveryTime;

        // Invoke geocode-address Edge Function
        try {
          final geocodeResponse = await Supabase.instance.client.functions
              .invoke(
                'geocode-address',
                body: {
                  'street': customerStreet,
                  'city': customerCity,
                  'postcode': customerPostcode,
                  'country':
                      'AT', // Assuming Austria, make this dynamic if needed
                },
              );

          if (geocodeResponse.data != null &&
              geocodeResponse.data['error'] == null) {
            deliveryLatitude = (geocodeResponse.data['latitude'] as num?)
                ?.toDouble();
            deliveryLongitude = (geocodeResponse.data['longitude'] as num?)
                ?.toDouble();
            print(
              '[CartViewWidget] Geocoding successful: Lat: $deliveryLatitude, Lng: $deliveryLongitude',
            );
            if (deliveryLatitude == null || deliveryLongitude == null) {
              print(
                '[CartViewWidget] Geocoding response did not contain valid lat/lng.',
              );
              // Optionally, still show an error to the user or proceed with nulls
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Address geocoded but coordinates are missing. Order created without map pin.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } else {
            print(
              '[CartViewWidget] Geocoding error: ${geocodeResponse.data?['error'] ?? 'Unknown error'}',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error geocoding address: ${geocodeResponse.data?['error'] ?? 'Please check address details.'}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              // Decide if order creation should stop or proceed with null lat/lng
              // For now, we'll let it proceed with nulls, but the marker won't show.
              // To stop: setState(() => _isCreatingOrder = false); return;
            }
          }
        } catch (e) {
          print('[CartViewWidget] Exception during geocoding: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Exception during geocoding: $e'),
                backgroundColor: Colors.red,
              ),
            );
            // Decide if order creation should stop or proceed with null lat/lng
            // setState(() => _isCreatingOrder = false); return;
          }
        }
      }

      if (paymentMethodToSave == 'card_terminal') {
        _failedOrderAmount = finalPriceForOrder;
        _failedOrderCurrency = 'eur';
      }

      final String createdOrderId = await _orderService.createOrderFromCart(
        currentCartItemsForOrder,
        brandIdForOrder,
        orderTypeName: orderTypeConfig?.name,
        orderTypeId: orderTypeConfig?.id,
        percentageCut: orderTypeConfig?.percentageCut,
        serviceFee: orderTypeConfig?.serviceFee,
        totalMaterialCost: totalMaterialCostForThisOrder,
        overrideTotalPrice: finalPriceForOrder,
        paymentMethod: paymentMethodToSave,
        fulfillmentType: fulfillmentTypeToSave,
        customerName: customerName,
        customerStreet: customerStreet,
        customerPostcode: customerPostcode,
        customerCity: customerCity,
        requestedDeliveryTime: requestedDeliveryTime,
        deliveryLatitude: deliveryLatitude, // Pass geocoded value
        deliveryLongitude: deliveryLongitude, // Pass geocoded value
      );

      if (!mounted) return;
      _failedOrderId = createdOrderId;

      if (paymentMethodToSave == 'card_terminal') {
        _listenToOrderStatus(createdOrderId);

        final terminalResponse = await _orderService
            .initiateCardTerminalPayment(
              createdOrderId,
              finalPriceForOrder,
              _failedOrderCurrency!,
            );

        if (!mounted) return;

        if (terminalResponse != null &&
            !terminalResponse.containsKey('error')) {
          print(
            "[CartViewWidget] Successfully initiated terminal payment for order $createdOrderId. Navigating to OrdersScreen NOW.",
          );
          Provider.of<CartProvider>(context, listen: false).clearCart();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              );
            }
          });
          if (mounted)
            setState(() {
              _isCreatingOrder = false;
            });
          return;
        } else {
          String errorMessage =
              terminalResponse?['error']?.toString() ??
              'Unknown error initiating terminal payment.';
          print("[CartViewWidget] Terminal initiation failed: $errorMessage");
          if (mounted) {
            setState(() {
              _terminalPaymentMessage = 'Terminal Error: $errorMessage';
              _isProcessingTerminalPayment = false;
              _terminalPaymentAttemptFailed = true;
              _isCreatingOrder = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Terminal Error: $errorMessage'),
                backgroundColor: Colors.red,
              ),
            );
          }
          _orderRealtimeSubscription?.cancel();
        }
      } else {
        final currentCartItems = List<CartItem>.from(cartProvider.items.values);
        final currentBrandName = cartProvider.activeBrandName ?? "Restaurant";

        Provider.of<CartProvider>(context, listen: false).clearCart();
        if (orderTypeConfig != null) {
          setState(() {
            _selectedOrderTypeConfig = null;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (orderTypeConfig == null ||
            orderTypeConfig.name != _employeeOrderTypeName) {
          final receiptHtml = _generateReceiptHtml(
            currentCartItems,
            finalPriceForOrder,
            currentBrandName,
            orderTypeConfig?.name,
            createdOrderId,
            fulfillmentTypeToSave,
          );
          final String documentName =
              'Receipt_Order_${createdOrderId.substring(0, 8)}';
          await printReceiptPlatformSpecific(
            receiptHtml,
            context,
            documentName,
          );

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              );
            }
          });
        }
        if (mounted)
          setState(() {
            _isCreatingOrder = false;
          });
      }
    } catch (e) {
      if (mounted) {
        print("[CartViewWidget] Error in _createOrder (catch block): $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isCreatingOrder = false;
          _isProcessingTerminalPayment = false;
          _terminalPaymentAttemptFailed =
              (_selectedPaymentMethod == 'card_terminal');
          _terminalPaymentMessage = 'Error: ${e.toString()}';
        });
        _orderRealtimeSubscription?.cancel();
        if (_selectedPaymentMethod == 'card_terminal' &&
            _failedOrderId == null) {
          _terminalPaymentAttemptFailed = false;
        }
      }
    }
  }

  Future<void> _createEmployeeOrder(
    BuildContext context,
    CartProvider cartProvider,
  ) async {
    if (cartProvider.items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }
    final String? brandIdForOrder =
        widget.brandId ?? cartProvider.activeBrandId;
    if (brandIdForOrder == null || brandIdForOrder.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not determine brand for the order.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // For employee orders, fulfillment type might be implicitly 'pickup' or not applicable
    // Forcing a selection or setting a default:
    if (_selectedFulfillmentType == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Delivery or Pickup for employee meal.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Validate delivery form if fulfillment type is delivery
    if (_selectedFulfillmentType == 'delivery') {
      if (!_deliveryFormKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please fill in all required delivery details for employee meal.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return; // Stop order creation if delivery details are invalid
      }
    }

    setState(() {
      _isCreatingOrder = true;
    });
    try {
      final List<CartItem> currentCartItemsForEmployeeOrder = cartProvider
          .items
          .values
          .toList();
      final double totalMaterialCostForEmployeeOrder =
          await _calculateTotalMaterialCostForCart(
            currentCartItemsForEmployeeOrder,
          );

      String? customerName;
      String? customerStreet;
      String? customerPostcode;
      String? customerCity;
      DateTime? requestedDeliveryTime;
      double? deliveryLatitude; // Declare here
      double? deliveryLongitude; // Declare here

      if (_selectedFulfillmentType == 'delivery') {
        customerName = _customerNameController.text;
        customerStreet = _customerStreetController.text;
        customerPostcode = _customerPostcodeController.text;
        customerCity = _customerCityController.text;
        requestedDeliveryTime = _requestedDeliveryTime;

        // Invoke geocode-address Edge Function for employee order
        try {
          final geocodeResponse = await Supabase.instance.client.functions
              .invoke(
                'geocode-address',
                body: {
                  'street': customerStreet,
                  'city': customerCity,
                  'postcode': customerPostcode,
                  'country': 'AT', // Assuming Austria
                },
              );
          if (geocodeResponse.data != null &&
              geocodeResponse.data['error'] == null) {
            deliveryLatitude = (geocodeResponse.data['latitude'] as num?)
                ?.toDouble();
            deliveryLongitude = (geocodeResponse.data['longitude'] as num?)
                ?.toDouble();
            print(
              '[CartViewWidget] Employee Order Geocoding successful: Lat: $deliveryLatitude, Lng: $deliveryLongitude',
            );
            if (deliveryLatitude == null || deliveryLongitude == null) {
              print(
                '[CartViewWidget] Employee Order Geocoding response did not contain valid lat/lng.',
              );
            }
          } else {
            print(
              '[CartViewWidget] Employee Order Geocoding error: ${geocodeResponse.data?['error'] ?? 'Unknown error'}',
            );
            // Decide if order creation should stop or proceed with null lat/lng
          }
        } catch (e) {
          print(
            '[CartViewWidget] Employee Order Exception during geocoding: $e',
          );
          // Decide if order creation should stop or proceed with null lat/lng
        }
      }

      final String createdOrderId = await _orderService.createOrderFromCart(
        currentCartItemsForEmployeeOrder,
        brandIdForOrder,
        orderTypeName: _employeeOrderTypeName,
        orderTypeId: null,
        percentageCut: 0,
        serviceFee: 0,
        totalMaterialCost: totalMaterialCostForEmployeeOrder,
        overrideTotalPrice: 0.0,
        paymentMethod: 'internal_costing',
        fulfillmentType: _selectedFulfillmentType,
        customerName: customerName,
        customerStreet: customerStreet,
        customerPostcode: customerPostcode,
        customerCity: customerCity,
        requestedDeliveryTime: requestedDeliveryTime,
        deliveryLatitude: deliveryLatitude, // Pass geocoded value
        deliveryLongitude: deliveryLongitude, // Pass geocoded value
      );
      if (!mounted) return;
      cartProvider.clearCart();
      // Clear delivery form fields after successful employee order
      if (_selectedFulfillmentType == 'delivery') {
        _customerNameController.clear();
        _customerStreetController.clear();
        _customerPostcodeController.clear();
        _customerCityController.clear();
        setState(() {
          _requestedDeliveryTime = null;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Employee order created (ID: ${createdOrderId.substring(0, 8)}...). Cost logged.',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating employee order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOrder = false;
        });
      }
    }
  }

  Future<double> _calculateEstimatedCartProfit(
    List<CartItem> cartItems,
    double currentTotalPrice,
    OrderTypeConfig? selectedConfig, {
    bool isEmployeeOrder = false,
  }) async {
    double totalMaterialCostForCart = await _calculateTotalMaterialCostForCart(
      cartItems,
    );
    double effectiveTotalPrice = _overriddenTotalPrice ?? currentTotalPrice;
    double grossRevenue = isEmployeeOrder ? 0 : effectiveTotalPrice;
    double commissionAmount = 0;
    double fixedServiceFee = 0;
    if (!isEmployeeOrder && selectedConfig != null) {
      if (selectedConfig.percentageCut > 0) {
        commissionAmount = grossRevenue * selectedConfig.percentageCut;
      }
      fixedServiceFee = selectedConfig.serviceFee;
    }
    double netRevenueAfterFees =
        grossRevenue - commissionAmount - fixedServiceFee;
    double estimatedProfit = netRevenueAfterFees - totalMaterialCostForCart;
    return estimatedProfit;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.items.values.toList();

    return Column(
      children: [
        Expanded(
          child: cartItems.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Your cart is empty. Add items from the menu.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final cartItem = cartItems[index];
                    return ExpandableCartItemTile(cartItem: cartItem);
                  },
                ),
        ),
        if (cartItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Revenue:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _isEditingTotalPrice
                        ? Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: _totalPriceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.right,
                                    decoration: InputDecoration(
                                      prefixText: '€ ',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                    autofocus: true,
                                    onSubmitted: (_) {
                                      setState(() {
                                        final newPrice = double.tryParse(
                                          _totalPriceController.text.replaceAll(
                                            ',',
                                            '.',
                                          ),
                                        );
                                        if (newPrice != null) {
                                          _overriddenTotalPrice = newPrice;
                                        }
                                        _isEditingTotalPrice = false;
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      final newPrice = double.tryParse(
                                        _totalPriceController.text.replaceAll(
                                          ',',
                                          '.',
                                        ),
                                      );
                                      if (newPrice != null) {
                                        _overriddenTotalPrice = newPrice;
                                      }
                                      _isEditingTotalPrice = false;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _isEditingTotalPrice = false;
                                      _totalPriceController.text =
                                          (_overriddenTotalPrice ??
                                                  cartProvider.totalPrice)
                                              .toStringAsFixed(2);
                                    });
                                  },
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              Text(
                                '${(_overriddenTotalPrice ?? cartProvider.totalPrice).toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: Colors.grey[700],
                                ),
                                padding: const EdgeInsets.only(left: 8.0),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _isEditingTotalPrice = true;
                                    _totalPriceController.text =
                                        (_overriddenTotalPrice ??
                                                cartProvider.totalPrice)
                                            .toStringAsFixed(2);
                                  });
                                },
                              ),
                            ],
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedOrderTypeConfig == null
                          ? 'Est. Profit (Standard):'
                          : 'Est. Profit (${_selectedOrderTypeConfig!.name}):',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    FutureBuilder<double>(
                      future: _calculateEstimatedCartProfit(
                        cartItems,
                        cartProvider.totalPrice,
                        _selectedOrderTypeConfig,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (snapshot.hasError) {
                          print(
                            "Error in FutureBuilder for profit: ${snapshot.error}",
                          );
                          return Text(
                            'N/A',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return Text(
                            'N/A',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          );
                        }
                        final estimatedProfit = snapshot.data!;
                        return Text(
                          '${estimatedProfit.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: estimatedProfit >= 0
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Fulfillment Type:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: const Text('Pickup'),
                          selected: _selectedFulfillmentType == 'pickup',
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          labelStyle: TextStyle(
                            color: _selectedFulfillmentType == 'pickup'
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          avatar: Icon(
                            Icons.storefront_outlined,
                            color: _selectedFulfillmentType == 'pickup'
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          onSelected:
                              _isProcessingTerminalPayment ||
                                  _terminalPaymentAttemptFailed
                              ? null
                              : (bool selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedFulfillmentType = 'pickup';
                                    });
                                  }
                                },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: const Text('Delivery'),
                          selected: _selectedFulfillmentType == 'delivery',
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          labelStyle: TextStyle(
                            color: _selectedFulfillmentType == 'delivery'
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          avatar: Icon(
                            Icons.delivery_dining_outlined,
                            color: _selectedFulfillmentType == 'delivery'
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          onSelected:
                              _isProcessingTerminalPayment ||
                                  _terminalPaymentAttemptFailed
                              ? null
                              : (bool selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedFulfillmentType = 'delivery';
                                    });
                                  }
                                },
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedFulfillmentType == 'delivery') ...[
                  const SizedBox(height: 16),
                  Form(
                    key: _deliveryFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Delivery Details:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter customer name'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customerStreetController,
                          decoration: const InputDecoration(
                            labelText: 'Street Address',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter street address'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _customerPostcodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Postcode',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Please enter postcode'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _customerCityController,
                                decoration: const InputDecoration(
                                  labelText: 'City',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Please enter city'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              // Wrap with Expanded to prevent overflow if text is long
                              child: Text(
                                _requestedDeliveryTime == null
                                    ? 'No requested delivery time'
                                    : 'Req. Time: ${TimeOfDay.fromDateTime(_requestedDeliveryTime!).format(context)} on ${MaterialLocalizations.of(context).formatShortDate(_requestedDeliveryTime!)}',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow
                                    .ellipsis, // Add ellipsis for long text
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: const Text(
                                'Set Time',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer, // Use theme color
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer, // Use theme color
                              ),
                              onPressed: () async {
                                final now = DateTime.now();
                                final DateTime?
                                pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _requestedDeliveryTime ?? now,
                                  firstDate: now,
                                  lastDate: now.add(
                                    const Duration(days: 7),
                                  ), // Allow selection up to 7 days in future
                                );
                                if (pickedDate != null) {
                                  final TimeOfDay? pickedTime =
                                      await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                          _requestedDeliveryTime ??
                                              now.add(
                                                const Duration(minutes: 30),
                                              ),
                                        ), // Default to 30 mins from now
                                      );
                                  if (pickedTime != null) {
                                    setState(() {
                                      _requestedDeliveryTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                    });
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  "Payment Method:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: const Text('Cash'),
                          selected: _selectedPaymentMethod == 'cash',
                          selectedColor: Theme.of(context).primaryColor,
                          labelStyle: TextStyle(
                            color: _selectedPaymentMethod == 'cash'
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          avatar: Icon(
                            Icons.money_outlined,
                            color: _selectedPaymentMethod == 'cash'
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          onSelected:
                              _isProcessingTerminalPayment ||
                                  _terminalPaymentAttemptFailed
                              ? null
                              : (bool selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedPaymentMethod = 'cash';
                                    });
                                  }
                                },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: const Text('Online'),
                          selected: _selectedPaymentMethod == 'online',
                          selectedColor: Theme.of(context).primaryColor,
                          labelStyle: TextStyle(
                            color: _selectedPaymentMethod == 'online'
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          avatar: Icon(
                            Icons.credit_card_outlined,
                            color: _selectedPaymentMethod == 'online'
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          onSelected:
                              _isProcessingTerminalPayment ||
                                  _terminalPaymentAttemptFailed
                              ? null
                              : (bool selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedPaymentMethod = 'online';
                                    });
                                  }
                                },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: const Text('Card Terminal'),
                          selected: _selectedPaymentMethod == 'card_terminal',
                          selectedColor: Theme.of(context).primaryColor,
                          labelStyle: TextStyle(
                            color: _selectedPaymentMethod == 'card_terminal'
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          avatar: Icon(
                            Icons.adf_scanner_outlined,
                            color: _selectedPaymentMethod == 'card_terminal'
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          onSelected:
                              _isProcessingTerminalPayment ||
                                  _terminalPaymentAttemptFailed
                              ? null
                              : (bool selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedPaymentMethod = 'card_terminal';
                                    });
                                  }
                                },
                        ),
                      ),
                    ),
                  ],
                ),

                if (_isProcessingTerminalPayment &&
                    _terminalPaymentMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _terminalPaymentMessage!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      if (_currentOrderIdForTerminalPayment != null &&
                          _currentStripePaymentIntentIdForCancellation != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: TextButton(
                            onPressed: _cancelCurrentTerminalPayment,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (_terminalPaymentAttemptFailed) ...[
                  const SizedBox(height: 12),
                  Text(
                    _terminalPaymentMessage ?? "Payment Failed.",
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry Card"),
                        onPressed: _retryTerminalPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text("Other Method"),
                        onPressed: _changePaymentMethodAfterFailure,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor:
                        _isCreatingOrder ||
                            _selectedPaymentMethod == null ||
                            _selectedFulfillmentType == null ||
                            _isProcessingTerminalPayment ||
                            _terminalPaymentAttemptFailed
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      _isCreatingOrder ||
                          cartProvider.items.isEmpty ||
                          _selectedPaymentMethod == null ||
                          _selectedFulfillmentType == null ||
                          _isProcessingTerminalPayment ||
                          _terminalPaymentAttemptFailed
                      ? null
                      : () => _createOrder(
                          context,
                          cartProvider,
                          orderTypeConfig: _selectedOrderTypeConfig,
                        ),
                  child:
                      (_isCreatingOrder &&
                              _selectedPaymentMethod != 'card_terminal') ||
                          (_isProcessingTerminalPayment &&
                              _selectedPaymentMethod == 'card_terminal')
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selectedOrderTypeConfig == null
                              ? 'Create Standard Order'
                              : 'Create ${_selectedOrderTypeConfig!.name} Order',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
                if (widget.orderTypeConfigs != null &&
                    widget.orderTypeConfigs!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "Or create as:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: widget.orderTypeConfigs!.map((config) {
                      bool isSelected =
                          _selectedOrderTypeConfig?.id == config.id;
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.green[700]
                              : Colors.blueGrey[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed:
                            _isCreatingOrder ||
                                _isProcessingTerminalPayment ||
                                _terminalPaymentAttemptFailed
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedOrderTypeConfig = null;
                                  } else {
                                    _selectedOrderTypeConfig = config;
                                  }
                                });
                              },
                        child: Text(
                          config.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    icon: Icon(
                      Icons.ramen_dining_outlined,
                      color: Colors.deepOrangeAccent[700],
                    ),
                    label: Text(
                      'Create Employee Order (Cost Only)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.deepOrangeAccent[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed:
                        _isCreatingOrder ||
                            cartProvider.items.isEmpty ||
                            _isProcessingTerminalPayment ||
                            _terminalPaymentAttemptFailed
                        ? null
                        : () => _createEmployeeOrder(context, cartProvider),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// Data class to hold combined material details for display
class _MaterialDetailDisplay {
  final String materialName;
  final double quantityUsed;
  final String unitUsed;
  final double inventoryQuantity;
  final String inventoryUnit;
  final double? materialWeightedAverageCost;
  final double? costForMenuItemQuantity;

  _MaterialDetailDisplay({
    required this.materialName,
    required this.quantityUsed,
    required this.unitUsed,
    required this.inventoryQuantity,
    required this.inventoryUnit,
    this.materialWeightedAverageCost,
    this.costForMenuItemQuantity,
  });
}

class ExpandableCartItemTile extends StatefulWidget {
  final CartItem cartItem;

  const ExpandableCartItemTile({super.key, required this.cartItem});

  @override
  State<ExpandableCartItemTile> createState() => _ExpandableCartItemTileState();
}

class _ExpandableCartItemTileState extends State<ExpandableCartItemTile> {
  Future<List<_MaterialDetailDisplay>> _fetchMaterialDetails(
    String menuItemId,
  ) async {
    final supabase = Supabase.instance.client;
    List<_MaterialDetailDisplay> details = [];

    try {
      final mimResponse = await supabase
          .from('menu_item_materials')
          .select()
          .eq('menu_item_id', menuItemId);

      if (mimResponse.isEmpty) {
        return [];
      }

      for (var mimJsonData in mimResponse as List) {
        final menuItemMaterial = MenuItemMaterial.fromJson(
          mimJsonData as Map<String, dynamic>,
        );

        final matResponseData = await supabase
            .from('material')
            .select(
              'name, current_quantity, unit_of_measure, average_unit_cost',
            )
            .eq('id', menuItemMaterial.materialId)
            .maybeSingle();

        if (matResponseData == null) {
          details.add(
            _MaterialDetailDisplay(
              materialName:
                  'Material Not Found (ID: ${menuItemMaterial.materialId.substring(0, 8)}...)',
              quantityUsed: menuItemMaterial.quantityUsed,
              unitUsed: menuItemMaterial.unitOfMeasureUsed,
              inventoryQuantity: 0.0,
              inventoryUnit: 'N/A',
              materialWeightedAverageCost: 0.0,
              costForMenuItemQuantity: 0.0,
            ),
          );
          continue;
        }

        final double? materialWac =
            (matResponseData['average_unit_cost'] as num?)?.toDouble();
        final double costForQty = materialWac != null
            ? menuItemMaterial.quantityUsed * materialWac
            : 0.0;

        details.add(
          _MaterialDetailDisplay(
            materialName: matResponseData['name'] as String? ?? 'N/A',
            quantityUsed: menuItemMaterial.quantityUsed,
            unitUsed: menuItemMaterial.unitOfMeasureUsed,
            inventoryQuantity:
                (matResponseData['current_quantity'] as num?)?.toDouble() ??
                0.0,
            inventoryUnit:
                matResponseData['unit_of_measure'] as String? ?? 'N/A',
            materialWeightedAverageCost: materialWac,
            costForMenuItemQuantity: costForQty,
          ),
        );
      }
    } catch (e) {
      print(
        '[CartViewWidget] Error fetching material details for $menuItemId: $e',
      );
      throw Exception('Failed to load material details for $menuItemId: $e');
    }
    return details;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final menuItem = widget.cartItem.menuItemWithRecipe.menuItem;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        key: PageStorageKey(menuItem.id),
        leading: menuItem.imageUrl != null && menuItem.imageUrl!.isNotEmpty
            ? Image.network(
                menuItem.imageUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.restaurant, size: 40),
              )
            : const Icon(Icons.restaurant, size: 40),
        title: Text(menuItem.name, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${menuItem.price.toStringAsFixed(2)} € x ${widget.cartItem.quantity}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => cartProvider.decrementItemQuantity(menuItem.id),
            ),
            Text(
              widget.cartItem.quantity.toString(),
              style: const TextStyle(fontSize: 14),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => cartProvider.incrementItemQuantity(menuItem.id),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade700),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                cartProvider.removeFromCart(menuItem.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${menuItem.name} removed from cart.'),
                  ),
                );
              },
            ),
          ],
        ),
        children: <Widget>[
          if (widget.cartItem.menuItemWithRecipe.recipe.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Materials (per item):',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...widget.cartItem.menuItemWithRecipe.recipe.map((
                    resolvedMaterial,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '${resolvedMaterial.materialName}: ${resolvedMaterial.quantityUsed.toStringAsFixed(2)} ${resolvedMaterial.unitOfMeasureUsed}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 1.0),
                            child: Text(
                              'Cost: €${resolvedMaterial.totalCostForRecipe.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).primaryColorDark,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total Materials Cost (per item): €${widget.cartItem.menuItemWithRecipe.totalMaterialCostForOneUnit.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Builder(
                    builder: (context) {
                      final double profitPerItem =
                          menuItem.price -
                          widget
                              .cartItem
                              .menuItemWithRecipe
                              .totalMaterialCostForOneUnit;
                      final double profitForThisCartItemLine =
                          profitPerItem * widget.cartItem.quantity;
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Profit for these ${widget.cartItem.quantity} item(s): €${profitForThisCartItemLine.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: profitForThisCartItemLine >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          else
            FutureBuilder<List<_MaterialDetailDisplay>>(
              future: _fetchMaterialDetails(menuItem.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'No materials defined.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  );
                }

                final materials = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Materials (per item):',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...materials.map((material) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${material.materialName}: ${material.quantityUsed.toStringAsFixed(2)} ${material.unitUsed}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '(Stock: ${material.inventoryQuantity.toStringAsFixed(2)} ${material.inventoryUnit})',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                  top: 1.0,
                                ),
                                child: Text(
                                  'Cost: €${(material.costForMenuItemQuantity ?? 0.0).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).primaryColorDark,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total Materials Cost (per item): €${(materials.fold<double>(0.0, (sum, m) => sum + (m.costForMenuItemQuantity ?? 0.0))).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Builder(
                        builder: (context) {
                          final double totalMaterialsCostForThisCartItemUnit =
                              materials.fold<double>(
                                0.0,
                                (sum, m) =>
                                    sum + (m.costForMenuItemQuantity ?? 0.0),
                              );
                          final double profitPerItem =
                              menuItem.price -
                              totalMaterialsCostForThisCartItemUnit;
                          final double profitForThisCartItemLine =
                              profitPerItem * widget.cartItem.quantity;
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Profit for these ${widget.cartItem.quantity} item(s): €${profitForThisCartItemLine.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: profitForThisCartItemLine >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
