import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'd63e529d55cad9d34ee13cf56d487aa6';
  final url = 'https://www.lieferando.at/speisekarte/devels-smash-burger-5023';

  final scraperApiUrl = "https://api.scraperapi.com?api_key=$apiKey&url=${Uri.encodeComponent(url)}";
  print('Fetching Lieferando...');
  try {
    final response = await http.get(Uri.parse(scraperApiUrl)).timeout(Duration(seconds: 45));
    final html = response.body;
    
    // Try "score": 3.6
    final RegExp scoreRegex = RegExp(r'"score"\s*:\s*(\d+\.?\d*)', caseSensitive: false);
    final match = scoreRegex.firstMatch(html);
    if (match != null) {
      print('Score Match Found: ${match.group(1)}');
      final start = match.start;
      print('Context: ${html.substring((start - 100).clamp(0, html.length), (start + 100).clamp(0, html.length))}');
    } else {
      print('No score match found.');
    }
    
    // Check if "ratingValue" is indeed 0 everywhere
    final allRatings = RegExp(r'"ratingValue"\s*:\s*(\d+\.?\d*)').allMatches(html);
    for (var m in allRatings) {
      print('ratingValue occurrence: ${m.group(1)}');
    }
  } catch(e) {
    print('Error: $e');
  }
}
