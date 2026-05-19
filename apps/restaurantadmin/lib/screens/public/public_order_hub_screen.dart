import 'package:flutter/material.dart';
import 'package:restaurantadmin/config/online_brands.dart';
import 'package:restaurantadmin/screens/public/public_brand_order_screen.dart';

/// Landing page listing all ghost kitchen ordering sites (optional hub for ads).
class PublicOrderHubScreen extends StatelessWidget {
  const PublicOrderHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jetzt bestellen'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Wähle deine Küche — Bestellung geht direkt an unsere Küche.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...kOnlineBrands.map((brand) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    brand.logoAssetPath,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  brand.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(brand.tagline),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublicBrandOrderScreen(brand: brand),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
