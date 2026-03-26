import 'dart:convert';
import 'dart:io';

void main() async {
  print('🎨 Building DEVILS SMASH BURGER Menu HTML...\n');

  // Read the JSON files
  final categoriesFile = File('scripts/temp_categories.json');
  final itemsFile = File('scripts/temp_items.json');

  final categories = jsonDecode(await categoriesFile.readAsString()) as List;
  final allItems = jsonDecode(await itemsFile.readAsString()) as List;
  
  // Read and encode logo as base64
  final logoFile = File('scripts/devils_logo.png');
  String logoBase64 = '';
  if (await logoFile.exists()) {
    final logoBytes = await logoFile.readAsBytes();
    logoBase64 = base64Encode(logoBytes);
    print('✅ Logo encoded (${logoBytes.length} bytes)');
  }

  print('📊 Found ${categories.length} categories');
  print('📊 Found ${allItems.length} menu items\n');

  // Group items by category
  final Map<String, List<dynamic>> itemsByCategory = {};
  for (final category in categories) {
    final categoryId = category['id'];
    itemsByCategory[categoryId] = allItems
        .where((item) => item['category_id'] == categoryId)
        .toList();
  }

  // Generate HTML
  final html = generateMenuHTML(categories, itemsByCategory, logoBase64);

  // Save HTML file
  final outputFile = File('scripts/devils_menu.html');
  await outputFile.writeAsString(html);

  print('✅ Menu HTML generated successfully!');
  print('📄 File saved to: ${outputFile.path}');
  print('\n🌐 Next steps:');
  print('   1. Upload this file to Supabase Storage (menus bucket)');
  print('   2. Or host it on any web server');
  print('   3. Generate a QR code with the URL');
  print('   4. Print and display the QR code in your restaurant! 🎉');
}

String generateMenuHTML(List categories, Map<String, List<dynamic>> itemsByCategory, String logoBase64) {
  final categoriesHTML = categories.map((category) {
    final categoryId = category['id'];
    final categoryName = category['name'];
    final items = itemsByCategory[categoryId] ?? [];

    if (items.isEmpty) return '';

    final itemsHTML = items.map((item) {
      final name = item['name'] ?? 'Unknown';
      final price = item['price'];
      final priceStr = price != null ? price.toStringAsFixed(2) : '0.00';
      final description = item['description'] ?? '';
      final imageUrl = item['image_url'];
      
      // Fix image URL (remove localhost blob reference)
      String? cleanImageUrl;
      if (imageUrl != null && imageUrl.toString().startsWith('https://')) {
        final urlStr = imageUrl.toString();
        if (urlStr.contains('blob:http://localhost')) {
          // Image URL is broken, skip it
          cleanImageUrl = null;
        } else {
          cleanImageUrl = urlStr;
        }
      }

      return '''
        <div class="menu-item" data-aos="fade-up">
          ${cleanImageUrl != null ? '''
          <div class="item-image">
            <img src="$cleanImageUrl" alt="$name" loading="lazy" onerror="this.parentElement.style.display='none'">
          </div>
          ''' : ''}
          <div class="item-details">
            <div class="item-header">
              <h3 class="item-name">$name</h3>
              <span class="item-price">€$priceStr</span>
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
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DEVILS SMASH BURGER - Menü</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=Inter:wght@300;400;600;700;900&display=swap" rel="stylesheet">
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
        
        .logo-image {
            margin-bottom: 1.5rem;
            animation: logoFloat 3s ease-in-out infinite;
        }
        
        .brand-logo {
            max-width: 200px;
            height: auto;
            filter: drop-shadow(0 8px 20px rgba(220, 20, 60, 0.4));
            transition: transform 0.3s ease;
        }
        
        .brand-logo:hover {
            transform: scale(1.05);
        }
        
        @keyframes logoFloat {
            0%, 100% { transform: translateY(0px); }
            50% { transform: translateY(-10px); }
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
            
            h1 {
                font-size: 2.5rem;
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
        
        /* Scroll to top button */
        .scroll-top {
            position: fixed;
            bottom: 2rem;
            right: 2rem;
            background: var(--primary-red);
            color: white;
            width: 50px;
            height: 50px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.5rem;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(220, 20, 60, 0.5);
            transition: all 0.3s ease;
            opacity: 0;
            pointer-events: none;
        }
        
        .scroll-top.visible {
            opacity: 1;
            pointer-events: all;
        }
        
        .scroll-top:hover {
            transform: translateY(-5px);
            box-shadow: 0 6px 20px rgba(220, 20, 60, 0.7);
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="logo-container">
            ${logoBase64.isNotEmpty ? '''
            <div class="logo-image">
                <img src="data:image/png;base64,$logoBase64" alt="DEVILS SMASH BURGER Logo" class="brand-logo">
            </div>
            ''' : ''}
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

    <div class="scroll-top" onclick="scrollToTop()">↑</div>

    <script src="https://unpkg.com/aos@2.3.4/dist/aos.js"></script>
    <script>
        AOS.init({
            duration: 800,
            once: true,
            offset: 100
        });
        
        // Scroll to top functionality
        window.addEventListener('scroll', function() {
            const scrollTop = document.querySelector('.scroll-top');
            if (window.pageYOffset > 300) {
                scrollTop.classList.add('visible');
            } else {
                scrollTop.classList.remove('visible');
            }
        });
        
        function scrollToTop() {
            window.scrollTo({
                top: 0,
                behavior: 'smooth'
            });
        }
    </script>
</body>
</html>
''';
}

