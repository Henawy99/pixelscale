import 'dart:io';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'd63e529d55cad9d34ee13cf56d487aa6';
  
  final urls = {
    'Lieferando': 'https://www.lieferando.at/speisekarte/devels-smash-burger-5023',
    'Foodora': 'https://www.foodora.at/', // User didn't give full url, but just checking
    'Wolt': 'https://wolt.com/en/aut', // User didn't give full url
    'Google': 'https://maps.google.com/', // Google maps link
  };

  for (var entry in urls.entries) {
    if (entry.key == 'Lieferando') {
      final scraperApiUrl = "http://api.scraperapi.com?api_key=$apiKey&url=${Uri.encodeComponent(entry.value)}";
      
      print('Fetching ${entry.key}...');
      final response = await http.get(Uri.parse(scraperApiUrl));
      
      print('${entry.key} Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final html = response.body;
        
        final RegExp jsonLdRatingRegex = RegExp(r'"ratingValue"\s*:\s*"?(\d+\.?\d*)"?');
        final match = jsonLdRatingRegex.firstMatch(html);
        if (match != null) print('JSON-LD: ${match.group(1)}');
        
        // Let's print out lines containing "rating"
        final lines = html.split('\n');
        int count = 0;
        for (var line in lines) {
          if (line.toLowerCase().contains('rating')) {
            print(line.trim());
            count++;
            if (count > 5) break;
          }
        }
      }
    }
  }
}
