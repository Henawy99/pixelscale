import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Paymob Native SDK Service
/// 
/// This service handles:
/// 1. Creating payment intentions via the Unified Intention API
/// 2. Communicating with native iOS/Android SDKs via MethodChannel
/// 
/// Based on official Paymob documentation and Flutter sample app:
/// https://github.com/PaymobAccept/paymob-flutter-sample-app
class PaymobNativeSdkService {
  static const MethodChannel _channel = MethodChannel('paymob_sdk_flutter');
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PAYMOB CREDENTIALS
  // Get these from your Paymob Dashboard → Settings
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Secret Key (from Dashboard → Settings → Account Info)
  /// Used for server-side API calls (Intention API)
  static const String _secretKey = 'YOUR_SECRET_KEY';
  
  /// Public Key (from Dashboard → Settings → Account Info)
  /// Used for client-side SDK initialization
  static const String _publicKey = 'egy_pk_test_IQxc5DkNsD7jsATDfBzywRGWsJ3HqTOJ';
  
  /// Integration IDs
  static const int cardIntegrationId = 4475754;
  static const int walletIntegrationId = 5394679;
  
  /// Callback URL (as per Paymob's recommendation)
  static const String callbackUrl = 'https://accept.paymob.com/api/acceptance/post_pay';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INTENTION API
  // Creates a payment intention and returns client_secret
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Maps payment method name strings to Paymob integration IDs (integers).
  /// The v1/intention API requires integration IDs, not name strings.
  List<int> _resolveIntegrationIds(List<String> methods) {
    final ids = <int>[];
    for (final method in methods) {
      switch (method) {
        case 'card':
          ids.add(cardIntegrationId);
          break;
        case 'wallet':
          ids.add(walletIntegrationId);
          break;
        case 'apple_pay':
          // Apple Pay uses a separate integration ID.
          // Skip for now if no Apple Pay integration is configured.
          // ids.add(applePayIntegrationId);
          break;
      }
    }
    // Fallback: if nothing resolved, use card
    if (ids.isEmpty) ids.add(cardIntegrationId);
    return ids;
  }
  
  /// Create a payment intention using the Unified Intention API
  /// Returns the client_secret needed for the native SDK
  Future<String?> createPaymentIntention({
    required int amountCents,
    required String currency,
    required List<String> paymentMethods, // e.g., ['card', 'wallet', 'apple_pay']
    required String customerFirstName,
    required String customerLastName,
    required String customerEmail,
    required String customerPhone,
    String? orderId,
  }) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('📋 CREATING PAYMENT INTENTION');
      print('Amount: ${amountCents / 100} $currency');
      print('Methods: $paymentMethods');
      print('═══════════════════════════════════════════════════════════');
      
      // Paymob v1/intention API requires payment_methods to be a list of
      // INTEGER integration IDs — NOT strings like 'card' or 'wallet'
      final List<int> integrationIds = _resolveIntegrationIds(paymentMethods);
      
      final response = await http.post(
        Uri.parse('https://accept.paymob.com/v1/intention/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_secretKey',
        },
        body: jsonEncode({
          'amount': amountCents,
          'currency': currency,
          'payment_methods': integrationIds,
          'items': [
            {
              'name': 'Football Field Booking',
              'amount': amountCents,
              'description': 'Playmaker Field Booking',
              'quantity': 1,
            }
          ],
          'billing_data': {
            'first_name': customerFirstName,
            'last_name': customerLastName,
            'email': customerEmail,
            'phone_number': customerPhone,
            'apartment': 'NA',
            'floor': 'NA',
            'street': 'NA',
            'building': 'NA',
            'shipping_method': 'NA',
            'postal_code': 'NA',
            'city': 'Cairo',
            'country': 'EG',
            'state': 'Cairo',
          },
          'customer': {
            'first_name': customerFirstName,
            'last_name': customerLastName,
            'email': customerEmail,
          },
          'extras': {
            'order_id': orderId ?? '',
          },
          'redirection_url': callbackUrl,
          'notification_url': callbackUrl,
        }),
      );

      print('📋 Intention API Response: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final clientSecret = data['client_secret'] as String?;
        print('✅ Payment intention created successfully');
        print('🔑 Client Secret obtained');
        return clientSecret;
      } else {
        print('❌ Intention API Error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Intention API Error: $e');
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // NATIVE SDK BRIDGE
  // Communicates with iOS/Android native SDKs via MethodChannel
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Pay using the native Paymob SDK (supports Apple Pay, Card, Wallet)
  /// 
  /// Returns: 'Successfull', 'Rejected', 'Pending', or error message
  Future<PaymentResult> payWithNativeSDK({
    required String clientSecret,
    SavedBankCard? savedCard,
    String? appName,
    int? buttonBackgroundColor,
    int? buttonTextColor,
    bool? saveCardDefault,
    bool? showSaveCard,
  }) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('💳 CALLING NATIVE PAYMOB SDK');
      print('═══════════════════════════════════════════════════════════');
      
      final String result = await _channel.invokeMethod('payWithPaymob', {
        'publicKey': _publicKey,
        'clientSecret': clientSecret,
        'savedBankCard': savedCard?.toMap(),
        'appName': appName ?? 'Playmaker',
        'buttonBackgroundColor': buttonBackgroundColor ?? 0xFF00BF63, // Green
        'buttonTextColor': buttonTextColor ?? 0xFFFFFFFF, // White
        'saveCardDefault': saveCardDefault ?? false,
        'showSaveCard': showSaveCard ?? true,
      });
      
      print('📱 Native SDK Result: $result');
      
      switch (result) {
        case 'Successfull':
          return PaymentResult.success;
        case 'Rejected':
          return PaymentResult.rejected;
        case 'Pending':
          return PaymentResult.pending;
        default:
          return PaymentResult.error;
      }
    } on PlatformException catch (e) {
      print('❌ Native SDK Error: ${e.message}');
      return PaymentResult.error;
    } catch (e) {
      print('❌ Native SDK Error: $e');
      return PaymentResult.error;
    }
  }
  
  /// Complete payment flow:
  /// 1. Create intention to get client_secret
  /// 2. Call native SDK with client_secret
  Future<PaymentResult> processPayment({
    required int amountCents,
    required String currency,
    required String customerFirstName,
    required String customerLastName,
    required String customerEmail,
    required String customerPhone,
    List<String>? paymentMethods,
    String? orderId,
  }) async {
    // Step 1: Create payment intention
    final clientSecret = await createPaymentIntention(
      amountCents: amountCents,
      currency: currency,
      paymentMethods: paymentMethods ?? ['card', 'wallet'],
      customerFirstName: customerFirstName,
      customerLastName: customerLastName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      orderId: orderId,
    );
    
    if (clientSecret == null) {
      print('❌ Failed to create payment intention');
      return PaymentResult.error;
    }
    
    // Step 2: Call native SDK
    return await payWithNativeSDK(
      clientSecret: clientSecret,
      appName: 'Playmaker',
    );
  }
  
  /// Get public key for reference
  static String get publicKey => _publicKey;
}

/// Payment result enum
enum PaymentResult {
  success,
  rejected,
  pending,
  error,
}

/// Card type enum for saved cards
enum CardType {
  visa,
  masterCard,
  amex,
  meeza,
  omanNet,
  jcb,
  maestro,
  unknown,
}

/// Saved bank card model
class SavedBankCard {
  final String token;
  final String maskedPanNumber;
  final CardType cardType;

  SavedBankCard({
    required this.token,
    required this.maskedPanNumber,
    required this.cardType,
  });

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'maskedPanNumber': maskedPanNumber,
      'cardType': cardType.name,
    };
  }
}
