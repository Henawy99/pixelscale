import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'd63e529d55cad9d34ee13cf56d487aa6';
  
  final deliveryUrl = 'https://www.lieferando.at/speisekarte/devels-smash-burger-5023';
  final foodoraUrl = 'https://www.foodora.at/restaurant/qpcb/devils-smash-burger-qpcb';
  final googleUrl = 'https://maps.app.goo.gl/pRZkBY73GWcvMpET6';

  for (var url in [deliveryUrl, foodoraUrl, googleUrl]) {
    final scraperApiUrl = "https://api.scraperapi.com?api_key=$apiKey&url=${Uri.encodeComponent(url)}&render=true";
    print('Fetching $url...');
    try {
      final response = await http.get(Uri.parse(scraperApiUrl)).timeout(Duration(seconds: 45));
      final filename = '/tmp/debug_' + url.split('/').last + '.html';
      File(filename).writeAsStringSync(response.body);
      print('Saved to $filename');
    } catch(e) {
      print('Error fetching $url: $e');
    }
  }
}
