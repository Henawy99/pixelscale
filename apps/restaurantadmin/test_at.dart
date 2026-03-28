import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'd63e529d55cad9d34ee13cf56d487aa6';
  
  final deliveryUrl = 'https://www.lieferando.at/speisekarte/devels-smash-burger-5023';

  // Test with country_code=at
  final scraperApiUrl = "https://api.scraperapi.com?api_key=$apiKey&url=${Uri.encodeComponent(deliveryUrl)}&country_code=at";
  print('Fetching Lieferando with country_code=at...');
  try {
    final response = await http.get(Uri.parse(scraperApiUrl)).timeout(Duration(seconds: 45));
    final html = response.body;
    
    final RegExp ratingValueRegex = RegExp(r'"ratingValue"\s*:\s*"?(\d+\.?\d*)"?', caseSensitive: false);
    final match = ratingValueRegex.firstMatch(html);
    if (match != null) {
      print('Match Found (at): ${match.group(1)}');
    } else {
      print('Still no match for Lieferando even with country_code=at');
    }
  } catch(e) {
    print('Error: $e');
  }
}
