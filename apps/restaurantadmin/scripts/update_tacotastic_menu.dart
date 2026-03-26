import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  final supabase = Supabase.instance.client;

  try {
    // Find Tacotastic brand
    final brandResponse = await supabase
        .from('brands')
        .select('id')
        .ilike('name', '%taco%')
        .single();
    
    final brandId = brandResponse['id'] as String;
    print('Found Tacotastic brand: $brandId');

    // Create or find "Signature Tacos" category
    String categoryId;
    try {
      final categoryResponse = await supabase
          .from('menu_categories')
          .select('id')
          .eq('brand_id', brandId)
          .eq('name', 'Signature Tacos')
          .single();
      categoryId = categoryResponse['id'] as String;
      print('Found existing category: $categoryId');
    } catch (e) {
      // Category doesn't exist, create it
      final newCategory = await supabase
          .from('menu_categories')
          .insert({
            'brand_id': brandId,
            'name': 'Signature Tacos',
            'display_order': 0,
          })
          .select('id')
          .single();
      categoryId = newCategory['id'] as String;
      print('Created new category: $categoryId');
    }

    // Menu items to add
    final menuItems = [
      {
        'name': 'Philly Cheese French Taco',
        'price': 16.90,
        'description': null,
      },
      {
        'name': 'Grilled Chicken French Taco',
        'price': 15.90,
        'description': null,
      },
      {
        'name': 'Freaky Tenders French Taco',
        'price': 16.90,
        'description': 'French Taco mit knusprigen Chicken Tenders, Putenschinken und unserer hausgemachten Cheese Sauce.',
      },
      {
        'name': 'Chicken Nuggets French Taco',
        'price': 15.90,
        'description': null,
      },
      {
        'name': 'Cheesy Bacon French Taco',
        'price': 15.90,
        'description': null,
      },
      {
        'name': 'Falafel French Taco',
        'price': 15.90,
        'description': null,
      },
    ];

    // Insert menu items
    for (var item in menuItems) {
      await supabase.from('menu_items').insert({
        'category_id': categoryId,
        'brand_id': brandId,
        'name': item['name'],
        'price': item['price'],
        'description': item['description'],
        'display_order': menuItems.indexOf(item),
      });
      print('Added: ${item['name']}');
    }

    print('\n✅ Successfully updated Tacotastic menu!');
    print('Added ${menuItems.length} items to "Signature Tacos" category.');
  } catch (e) {
    print('❌ Error updating menu: $e');
  }
}

