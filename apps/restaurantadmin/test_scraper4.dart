import 'dart:io';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'd63e529d55cad9d34ee13cf56d487aa6';
  
  final urls = {
    'Lieferando': 'https://www.lieferando.at/speisekarte/devels-smash-burger-5023',
    'Foodora': 'https://www.foodora.at/restaurant/qpcb/devils-smash-burger-qpcb',
    'Google': 'https://maps.app.goo.gl/pRZkBY73GWcvMpET6',
  };

  for (var entry in urls.entries) {
    bool needsRender = entry.key == 'Google' || entry.key == 'Wolt';
    final String scraperApiUrl = "https://api.scraperapi.com?api_key=$apiKey&url=${Uri.encodeComponent(entry.value)}${needsRender ? '&render=true' : ''}";
    
    print('Testing ${entry.key}: ${entry.value}');
    try {
      final response = await http.get(Uri.parse(scraperApiUrl)).timeout(Duration(seconds: 40));
      print('Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final html = response.body;
        
        // 1. JSON-LD
        final RegExp ratingValueRegex = RegExp(r'"ratingValue"\s*:\s*"?(\d+\.?\d*)"?', caseSensitive: false);
        final match = ratingValueRegex.firstMatch(html);
        if (match != null) {
          print('Match Found: ${match.group(1)}');
        } else {
          print('No regex match in HTML.');
          // print snippet around "rating"
          final idx = html.toLowerCase().indexOf('rating');
          if (idx != -1) {
            print('Context around rating: ${html.substring(idx - 50, (idx + 100).clamp(0, html.length))}');
          }
        }
      }
    } catch (e) {
      print('Error: $e');
    }
    print('---');
  }
}
