import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Run this script with: dart run scripts/generate_menu_website.dart

const String SUPABASE_URL = 'https://iwiafzbavwsxfaxwznlc.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3aWFmemJhdndzeGZheHd6bmxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI4Mjk5NTUsImV4cCI6MjA0ODQwNTk1NX0.Y8r7-A0fgYCQVy8lWCbXxvmQJMh_SxVJODUgb8h56wY';
const String DEVILS_BRAND_ID = '4446a388-aaa7-402f-be4d-b82b23797415';

Future<void> main() async {
  print('🍔 Generating DEVILS SMASH BURGER Menu Website...\n');

  try {
    // 1. Fetch menu data from Supabase
    print('📡 Fetching menu data from Supabase...');
    final menuData = await fetchMenuData();
    
    // 2. Generate HTML
    print('🎨 Generating HTML menu page...');
    final html = generateMenuHTML(menuData);
    
    // 3. Save HTML file
    final htmlFile = File('scripts/menu.html');
    await htmlFile.writeAsString(html);
    print('✅ HTML saved to: ${htmlFile.path}');
    
    // 4. Upload to Supabase Storage
    print('\n📤 Uploading to Supabase Storage...');
    final publicUrl = await uploadToSupabase(html);
    print('✅ Menu is live at: $publicUrl');
    
    // 5. Generate QR Code (save as PNG)
    print('\n🎯 QR Code URL: $publicUrl');
    print('\n📱 Instructions:');
    print('   1. Open this URL in your browser to see the menu');
    print('   2. Use an online QR code generator with this URL:');
    print('      https://www.qr-code-generator.com/');
    print('   3. Or scan this QR in the generated PNG file');
    
    print('\n✅ All done! Your menu website is ready! 🎉');
    
  } catch (e, stack) {
    print('❌ Error: $e');
    print(stack);
    exit(1);
  }
}

Future<Map<String, dynamic>> fetchMenuData() async {
  final headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': 'Bearer $SUPABASE_ANON_KEY',
  };
  
  // Fetch categories
  final categoriesUrl = '$SUPABASE_URL/rest/v1/menu_categories?brand_id=eq.$DEVILS_BRAND_ID&order=display_order.asc&select=*';
  final categoriesResponse = await http.get(Uri.parse(categoriesUrl), headers: headers);
  
  if (categoriesResponse.statusCode != 200) {
    throw Exception('Failed to fetch categories: ${categoriesResponse.body}');
  }
  
  final categories = jsonDecode(categoriesResponse.body) as List;
  print('   Found ${categories.length} categories');
  
  // Fetch all menu items for this brand
  final itemsUrl = '$SUPABASE_URL/rest/v1/menu_items?brand_id=eq.$DEVILS_BRAND_ID&order=display_order.asc&select=*';
  final itemsResponse = await http.get(Uri.parse(itemsUrl), headers: headers);
  
  if (itemsResponse.statusCode != 200) {
    throw Exception('Failed to fetch menu items: ${itemsResponse.body}');
  }
  
  final allItems = jsonDecode(itemsResponse.body) as List;
  print('   Found ${allItems.length} menu items');
  
  // Group items by category
  final Map<String, List<dynamic>> itemsByCategory = {};
  for (final category in categories) {
    final categoryId = category['id'];
    itemsByCategory[categoryId] = allItems
        .where((item) => item['category_id'] == categoryId)
        .toList();
  }
  
  return {
    'categories': categories,
    'itemsByCategory': itemsByCategory,
  };
}

String generateMenuHTML(Map<String, dynamic> menuData) {
  final categories = menuData['categories'] as List;
  final itemsByCategory = menuData['itemsByCategory'] as Map<String, List<dynamic>>;
  
  final categoriesHTML = categories.map((category) {
    final categoryId = category['id'];
    final categoryName = category['name'];
    final items = itemsByCategory[categoryId] ?? [];
    
    if (items.isEmpty) return '';
    
    final itemsHTML = items.map((item) {
      final name = item['name'] ?? 'Unknown';
      final price = item['price']?.toString() ?? '0';
      final description = item['description'] ?? '';
      final imageUrl = item['image_url'];
      
      return '''
        <div class="menu-item" data-aos="fade-up">
          ${imageUrl != null ? '''
          <div class="item-image">
            <img src="$imageUrl" alt="$name" loading="lazy">
          </div>
          ''' : ''}
          <div class="item-details">
            <div class="item-header">
              <h3 class="item-name">$name</h3>
              <span class="item-price">CHF $price</span>
            </div>
            ${description.isNotEmpty ? '<p class="item-description">$description</p>' : ''}
          </div>
        </div>
      ''';
    }).join('\n');
    
    return '''
      <section class="menu-category" id="${categoryName.toLowerCase().replaceAll(' ', '-')}">
        <h2 class="category-title" data-aos="fade-right">$categoryName</h2>
        <div class="menu-grid">
          $itemsHTML
        </div>
      </section>
    ''';
  }).join('\n');
  
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DEVILS SMASH BURGER - Menu</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://unpkg.com/aos@2.3.4/dist/aos.css">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        :root {
            --primary-red: #DC143C;
            --dark-bg: #0a0a0a;
            --card-bg: #1a1a1a;
            --text-primary: #ffffff;
            --text-secondary: #b0b0b0;
            --accent-gold: #FFD700;
        }
        
        body {
            font-family: 'Inter', sans-serif;
            background: linear-gradient(135deg, #0a0a0a 0%, #1a0505 100%);
            color: var(--text-primary);
            line-height: 1.6;
            min-height: 100vh;
        }
        
        .header {
            background: linear-gradient(180deg, rgba(220, 20, 60, 0.95) 0%, rgba(139, 0, 0, 0.95) 100%);
            padding: 3rem 1.5rem;
            text-align: center;
            position: relative;
            overflow: hidden;
            box-shadow: 0 10px 30px rgba(220, 20, 60, 0.3);
        }
        
        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1440 320"><path fill="%23000000" fill-opacity="0.1" d="M0,96L48,112C96,128,192,160,288,160C384,160,480,128,576,122.7C672,117,768,139,864,144C960,149,1056,139,1152,122.7C1248,107,1344,85,1392,74.7L1440,64L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"></path></svg>') no-repeat bottom;
            background-size: cover;
            opacity: 0.1;
        }
        
        .logo-container {
            position: relative;
            z-index: 2;
        }
        
        h1 {
            font-family: 'Bebas Neue', cursive;
            font-size: clamp(2.5rem, 8vw, 5rem);
            letter-spacing: 3px;
            text-shadow: 0 4px 20px rgba(0, 0, 0, 0.5), 0 0 40px rgba(220, 20, 60, 0.5);
            margin-bottom: 0.5rem;
            animation: glow 2s ease-in-out infinite alternate;
        }
        
        @keyframes glow {
            from {
                text-shadow: 0 4px 20px rgba(0, 0, 0, 0.5), 0 0 40px rgba(220, 20, 60, 0.5);
            }
            to {
                text-shadow: 0 4px 30px rgba(0, 0, 0, 0.8), 0 0 60px rgba(220, 20, 60, 0.8);
            }
        }
        
        .tagline {
            font-size: 1.2rem;
            color: var(--accent-gold);
            font-weight: 300;
            letter-spacing: 2px;
            margin-top: 0.5rem;
            text-shadow: 0 2px 10px rgba(0, 0, 0, 0.5);
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 3rem 1.5rem;
        }
        
        .menu-category {
            margin-bottom: 4rem;
        }
        
        .category-title {
            font-family: 'Bebas Neue', cursive;
            font-size: 2.5rem;
            color: var(--primary-red);
            margin-bottom: 2rem;
            padding-bottom: 0.5rem;
            border-bottom: 3px solid var(--primary-red);
            letter-spacing: 2px;
            text-transform: uppercase;
        }
        
        .menu-grid {
            display: grid;
            gap: 2rem;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
        }
        
        .menu-item {
            background: var(--card-bg);
            border-radius: 16px;
            overflow: hidden;
            transition: all 0.3s ease;
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.4);
            border: 1px solid rgba(220, 20, 60, 0.2);
        }
        
        .menu-item:hover {
            transform: translateY(-8px);
            box-shadow: 0 12px 30px rgba(220, 20, 60, 0.4);
            border-color: var(--primary-red);
        }
        
        .item-image {
            width: 100%;
            height: 200px;
            overflow: hidden;
            background: linear-gradient(135deg, #2a2a2a 0%, #1a1a1a 100%);
        }
        
        .item-image img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            transition: transform 0.3s ease;
        }
        
        .menu-item:hover .item-image img {
            transform: scale(1.1);
        }
        
        .item-details {
            padding: 1.5rem;
        }
        
        .item-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            gap: 1rem;
            margin-bottom: 0.5rem;
        }
        
        .item-name {
            font-size: 1.3rem;
            font-weight: 600;
            color: var(--text-primary);
            flex: 1;
        }
        
        .item-price {
            font-family: 'Bebas Neue', cursive;
            font-size: 1.5rem;
            color: var(--accent-gold);
            font-weight: bold;
            white-space: nowrap;
        }
        
        .item-description {
            color: var(--text-secondary);
            font-size: 0.95rem;
            line-height: 1.5;
        }
        
        .footer {
            text-align: center;
            padding: 3rem 1.5rem;
            background: var(--card-bg);
            margin-top: 4rem;
            border-top: 2px solid var(--primary-red);
        }
        
        .footer p {
            color: var(--text-secondary);
            font-size: 0.9rem;
        }
        
        .footer .flame-emoji {
            font-size: 1.5rem;
            animation: flicker 1.5s infinite;
        }
        
        @keyframes flicker {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        
        /* Mobile Responsiveness */
        @media (max-width: 768px) {
            .menu-grid {
                grid-template-columns: 1fr;
            }
            
            .category-title {
                font-size: 2rem;
            }
            
            .header {
                padding: 2rem 1rem;
            }
        }
        
        /* Loading animation */
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        .menu-item {
            animation: fadeIn 0.5s ease-out;
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="logo-container">
            <h1>🔥 DEVILS SMASH BURGER 🔥</h1>
            <p class="tagline">Sinfully Delicious Burgers</p>
        </div>
    </header>

    <main class="container">
        $categoriesHTML
    </main>

    <footer class="footer">
        <p><span class="flame-emoji">🔥</span> DEVILS SMASH BURGER <span class="flame-emoji">🔥</span></p>
        <p style="margin-top: 1rem;">Made with ❤️ and 🍔</p>
    </footer>

    <script src="https://unpkg.com/aos@2.3.4/dist/aos.js"></script>
    <script>
        AOS.init({
            duration: 800,
            once: true,
            offset: 100
        });
    </script>
</body>
</html>
''';
}

Future<String> uploadToSupabase(String htmlContent) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = 'devils-menu-$timestamp.html';
  
  // Upload to Supabase Storage
  final uploadUrl = '$SUPABASE_URL/storage/v1/object/menus/$fileName';
  
  final response = await http.post(
    Uri.parse(uploadUrl),
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': 'Bearer $SUPABASE_ANON_KEY',
      'Content-Type': 'text/html',
    },
    body: htmlContent,
  );
  
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Failed to upload to Supabase: ${response.statusCode} - ${response.body}');
  }
  
  // Return public URL
  return '$SUPABASE_URL/storage/v1/object/public/menus/$fileName';
}

