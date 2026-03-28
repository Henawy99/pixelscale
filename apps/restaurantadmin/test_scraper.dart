import 'dart:io';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://www.lieferando.at/speisekarte/devels-smash-burger-5023';
  
  final response = await http.get(Uri.parse(url), headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  });
  
  print('Status code: ${response.statusCode}');
  final html = response.body;
  
  final RegExp jsonLdRatingRegex = RegExp(r'"ratingValue"\s*:\s*"?(\d+\.?\d*)"?');
  final match = jsonLdRatingRegex.firstMatch(html);
  
  if (match != null) {
     print('JSON-LD Rating Match: ${match.group(1)}');
  } else {
     print('No JSON-LD rating match');
  }
  
  final document = parser.parse(html);
  final ratingElement = document.querySelector('[data-qa="restaurant-header-rating"]');
  if (ratingElement != null) {
      String text = ratingElement.text.trim();
      print('Element text: $text');
      final RegExp numRegex = RegExp(r'(\d+\.\d+)');
      final numMatch = numRegex.firstMatch(text);
      if (numMatch != null) print('Regex matched: ${numMatch.group(1)}');
  } else {
     print('No data-qa element found');
  }
  
  // also try to find any raw occurrences of ratingValue
  print('Raw "ratingValue" occurrences:');
  final matches = RegExp(r'ratingValue').allMatches(html);
  print(matches.length);
}
