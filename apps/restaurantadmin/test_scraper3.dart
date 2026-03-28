import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'd63e529d55cad9d34ee13cf56d487aa6';
  
  final urls = {
    'Foodora': 'https://www.foodora.at/restaurant/v6ul/mcdonalds-schwedenplatz', // guess link
    'Wolt': 'https://wolt.com/en/aut/vienna/restaurant/burger-king-wien-mariahilfer-strae', // guess link
    'Google': 'https://www.google.com/maps/place/Devils+Smash+Burger/', // guess link
  };

  for (var entry in urls.entries) {
    final scraperApiUrl = "http://api.scraperapi.com?api_key=$apiKey&url=${Uri.encodeComponent(entry.value)}";
    
    print('Fetching ${entry.key}...');
    try {
      final response = await http.get(Uri.parse(scraperApiUrl));
      print('${entry.key} Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final html = response.body;
        
        // Try jsonLd
        final RegExp jsonLdRatingRegex = RegExp(r'"ratingValue"\s*:\s*"?(\d+\.?\d*)"?');
        final match = jsonLdRatingRegex.firstMatch(html);
        if (match != null) {
          print('${entry.key} JSON-LD Rating: ${match.group(1)}');
        } else {
          print('${entry.key} JSON-LD rating not found.');
          // find anywhere holding format "X.X" around the word "rating"
          final matches = RegExp(r'.{0,20}rating.{0,20}(\d\.\d).{0,20}').allMatches(html);
          if (matches.isNotEmpty) {
             print('${entry.key} context: ${matches.first.group(0)}');
          }
        }
      }
    } catch(e) {
      print('${entry.key} error: $e');
    }
  }
}
