import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Paymob Service - Simplified for Native SDK
/// 
/// The flutter_paymob SDK handles all payment flows internally:
/// - Authentication
/// - Order registration
/// - Payment key generation
/// - Card/Wallet payment UI
/// 
/// This service now only contains:
/// - Credentials reference (for dashboard access)
/// - HMAC verification for webhook callbacks
class PaymobService {
  // ═══════════════════════════════════════════════════════════════════════════
  // PAYMOB CREDENTIALS REFERENCE
  // These are initialized in main.dart via FlutterPaymob.instance.initialize()
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// API Key (from Dashboard → Settings → Account Info → API Key)
  static const String apiKey = 'ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2T1RVM05ETTVMQ0p1WVcxbElqb2lhVzVwZEdsaGJDSjkuenh4OGg5NHBBYU1HZjBQZWFnZnZVN3R1YmpKcWpfd1llWDNYTnFDLXp4bE1iLW1jRVo1UDVQT2VidHpVSFM4VzRwWDVhU2NYcDJ4Q3p2X2R0ZGh3Z0E=';
  
  /// Integration IDs (from Dashboard → Developers → Payment Integrations)
  static const int integrationIdCard = 4475754;         // Online Card
  static const int integrationIdMobileWallet = 5394679; // Mobile Wallet
  
  /// iFrame ID (from Dashboard → Developers → iframes)
  static const int iframeId = 821902;
  
  /// HMAC Secret (from Dashboard → Developers → Account Info → HMAC Secret)
  static const String hmacSecret = '459A518EAEBD5D829DCCE405A4AAEB6C';
  
  /// Callback URL for payment redirection (as per Paymob's recommendation)
  static const String callbackUrl = 'https://accept.paymob.com/api/acceptance/post_pay';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FUTURE: Apple Pay / Google Pay Integration IDs
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Apple Pay Integration ID (TODO: Add from Paymob Dashboard)
  static const String integrationIdApplePay = '';
  
  /// Google Pay Integration ID (TODO: Add from Paymob Dashboard)
  static const String integrationIdGooglePay = '';
  
  /// Check if Apple Pay is configured
  static bool get isApplePayEnabled => integrationIdApplePay.isNotEmpty;
  
  /// Check if Google Pay is configured
  static bool get isGooglePayEnabled => integrationIdGooglePay.isNotEmpty;

  // ═══════════════════════════════════════════════════════════════════════════
  // HMAC VERIFICATION - For Webhook Callbacks
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Verify transaction callback using HMAC
  /// 
  /// Use this to verify webhook callbacks from Paymob to ensure
  /// the transaction data hasn't been tampered with.
  /// 
  /// Reference: https://developers.paymob.com/egypt
  bool verifyTransactionCallback(Map<String, dynamic> callbackData) {
    try {
      final receivedHmac = callbackData['hmac'] as String?;
      if (receivedHmac == null) return false;

      // Concatenate the values in the specific order required by Paymob
      final concatenated = '${callbackData['amount_cents']}'
          '${callbackData['created_at']}'
          '${callbackData['currency']}'
          '${callbackData['error_occured']}'
          '${callbackData['has_parent_transaction']}'
          '${callbackData['id']}'
          '${callbackData['integration_id']}'
          '${callbackData['is_3d_secure']}'
          '${callbackData['is_auth']}'
          '${callbackData['is_capture']}'
          '${callbackData['is_refunded']}'
          '${callbackData['is_standalone_payment']}'
          '${callbackData['is_voided']}'
          '${callbackData['order']}'
          '${callbackData['owner']}'
          '${callbackData['pending']}'
          '${callbackData['source_data_pan']}'
          '${callbackData['source_data_sub_type']}'
          '${callbackData['source_data_type']}'
          '${callbackData['success']}';

      // Calculate HMAC
      final key = utf8.encode(hmacSecret);
      final bytes = utf8.encode(concatenated);
      final hmacSha512 = Hmac(sha512, key);
      final digest = hmacSha512.convert(bytes);
      final calculatedHmac = digest.toString();

      return calculatedHmac == receivedHmac;
    } catch (e) {
      print('HMAC verification error: $e');
      return false;
    }
  }
}
