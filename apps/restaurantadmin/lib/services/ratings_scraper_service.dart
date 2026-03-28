import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class RatingsScraperService {
  static final RatingsScraperService _instance = RatingsScraperService._internal();
  factory RatingsScraperService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  RatingsScraperService._internal();

  Future<void> initNotifications() async {
    if (_initialized) return;
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // For iOS, might need DarwinInitializationSettings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
    _initialized = true;
  }

  Future<void> showLowRatingNotification(String brandName, String platform, double rating) async {
    await initNotifications();
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'ratings_alerts', 'Rating Alerts',
      channelDescription: 'Notifications for low restaurant ratings',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: 'Low Rating Alert!',
      body: '$brandName has a rating of $rating on $platform.',
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<double?> fetchRating(String url, String platform) async {
    if (url.isEmpty || !Uri.parse(url).isAbsolute) return null;

    try {
      // Use render=true for ALL sites to bypass Cloudflare/bot protection and SPAs
      final String scraperApiUrl = "https://api.scraperapi.com?api_key=d63e529d55cad9d34ee13cf56d487aa6&url=${Uri.encodeComponent(url)}&render=true&country_code=at";

      final response = await http.get(Uri.parse(scraperApiUrl)).timeout(const Duration(seconds: 50));

      if (response.statusCode != 200) {
        debugPrint('ScraperAPI error: ${response.statusCode}');
        return null;
      }

      final html = response.body;

      // 1. Try flexible JSON-LD / JSON Match for "ratingValue": 4.5
      // We exclude "0" specifically as it's often a bot-protection placeholder
      final RegExp ratingValueRegex = RegExp(r'"ratingValue"\s*:\s*"?([1-5]\.[0-9]|[1-5])"?', caseSensitive: false);
      final match = ratingValueRegex.firstMatch(html);
      if (match != null) {
        final val = double.tryParse(match.group(1) ?? '');
        if (val != null && val > 0) return val;
      }

      // 2. Try Next.js/React internal state match (score: 4.5)
      final RegExp scoreRegex = RegExp(r'"score"\s*:\s*([1-5]\.[0-9]|[1-5])', caseSensitive: false);
      final scoreMatch = scoreRegex.firstMatch(html);
      if (scoreMatch != null) {
        final val = double.tryParse(scoreMatch.group(1) ?? '');
        if (val != null && val > 0) return val;
      }

      // 3. Platform specific fallback selectors
      final document = parser.parse(html);
      
      if (platform.toLowerCase() == 'google') {
        // Google Maps / Search results
        final ratingElement = document.querySelector('span[aria-label*="stars"]') ?? 
                             document.querySelector('div[aria-label*="stars"]') ??
                             document.querySelector('.rating-score') ??
                             document.querySelector('span[class*="rating"]');
        if (ratingElement != null) {
          final text = ratingElement.attributes['aria-label'] ?? ratingElement.text;
          final RegExp reg = RegExp(r'([1-5]\.[0-9]|[1-5])');
          final m = reg.firstMatch(text);
          if (m != null) return double.tryParse(m.group(1) ?? '');
        }
      } else if (platform.toLowerCase() == 'foodora') {
        // Foodora specific
        final ratingElement = document.querySelector('[data-testid="restaurant-rating-score"]') ??
                             document.querySelector('.ratings-component__score');
        if (ratingElement != null) {
          final RegExp numRegex = RegExp(r'(\d+\.?\d*)');
          final numMatch = numRegex.firstMatch(ratingElement.text);
          if (numMatch != null) return double.tryParse(numMatch.group(1) ?? '');
        }
      } else if (platform.toLowerCase() == 'lieferando') {
        final ratingElement = document.querySelector('[data-qa="restaurant-header-rating-score"]') ??
                             document.querySelector('.rating-score');
        if (ratingElement != null) {
          final RegExp numRegex = RegExp(r'(\d+\.?\d*)');
          final numMatch = numRegex.firstMatch(ratingElement.text);
          if (numMatch != null) return double.tryParse(numMatch.group(1) ?? '');
        }
      }

      // 4. Last resort: search for anything like "4.5" followed by "rating" or "stars" or "bewertung"
      final RegExp lastResortRegex = RegExp(r'([1-5]\.[0-9])\s*(star|rating|bewertung)', caseSensitive: false);
      final lrMatch = lastResortRegex.firstMatch(html);
      if (lrMatch != null) {
        return double.tryParse(lrMatch.group(1) ?? '');
      }

    } catch (e) {
      debugPrint('Error fetching rating from $url: $e');
    }
    return null;
  }
}
