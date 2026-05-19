import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurantadmin/config/online_brands.dart';
import 'package:restaurantadmin/providers/cart_provider.dart';
import 'package:restaurantadmin/screens/public/public_brand_order_screen.dart';
import 'package:restaurantadmin/screens/public/public_order_hub_screen.dart';

/// Lightweight web app shell for customer ordering (no POS login).
class PublicOrderingApp extends StatelessWidget {
  const PublicOrderingApp({super.key});

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final path = settings.name ?? Uri.base.path;
    if (path == '/order' || path == '/order/') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const PublicOrderHubScreen(),
      );
    }
    final slug = publicOrderSlugFromPath(path);
    if (slug != null) {
      final brand = onlineBrandBySlug(slug);
      if (brand != null) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PublicBrandOrderScreen(brand: brand),
        );
      }
    }
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const PublicOrderHubScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = Uri.base.path.isEmpty ? '/order' : Uri.base.path;

    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp(
        title: 'Online bestellen',
        debugShowCheckedModeBanner: false,
        onGenerateRoute: _onGenerateRoute,
        initialRoute: initial,
      ),
    );
  }
}
