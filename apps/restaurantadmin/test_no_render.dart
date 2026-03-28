import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'd63e529d55cad9d34ee13cf56d487aa6';
  final url = 'https://www.lieferando.at/speisekarte/devels-smash-burger-5023';

  // Test WITHOUT render=true (it worked before)
  final scraperApiUrl = "https://api.scraperapi.com?api_key=$apiKey&url=${Uri.encodeComponent(url)}";
  print('Fetching Lieferando WITHOUT render...');
  try {
    final response = await http.get(Uri.parse(scraperApiUrl)).timeout(Duration(seconds: 45));
    final html = response.body;
    
    final RegExp ratingValueRegex = RegExp(r'"ratingValue"\s*:\s*"?(\d+\.?\d*)"?', caseSensitive: false);
    final match = ratingValueRegex.firstMatch(html);
    if (match != null) {
      print('Match Found: ${match.group(1)}');
      // show context
      final start = match.start;
      print('Context: ${html.substring((start - 50).clamp(0, html.length), (start + 100).clamp(0, html.length))}');
    } else {
      print('No match found.');
    }
  } catch(e) {
    print('Error: $e');
  }
}
