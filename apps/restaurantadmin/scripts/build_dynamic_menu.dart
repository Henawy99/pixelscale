import 'dart:convert';
import 'dart:io';

void main() async {
  print('🎨 Building Dynamic DEVILS SMASH BURGER Menu...\n');

  // Read the logo and encode as base64
  final logoFile = File('scripts/devils_logo.png');
  String logoBase64 = '';
  if (await logoFile.exists()) {
    final logoBytes = await logoFile.readAsBytes();
    logoBase64 = base64Encode(logoBytes);
    print('✅ Logo encoded (${logoBytes.length} bytes)');
  }

  // Generate dynamic HTML that fetches live from Supabase
  final html = generateDynamicMenuHTML(logoBase64);

  // Save HTML file
  final outputFile = File('scripts/menu.html');
  await outputFile.writeAsString(html);

  print('✅ Dynamic menu HTML generated!');
  print('📄 File saved to: ${outputFile.path}');
  print('\n🌐 This menu will auto-update from your Supabase database!');
  print('📤 Upload as "menu.html" for clean URL');
}

String generateDynamicMenuHTML(String logoBase64) {
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
            from { text-shadow: 0 4px 20px rgba(0, 0, 0, 0.5), 0 0 40px rgba(220, 20, 60, 0.5); }
            to { text-shadow: 0 4px 30px rgba(0, 0, 0, 0.8), 0 0 60px rgba(220, 20, 60, 0.8); }
        }
        
        .tagline {
            font-size: 1.2rem;
            color: var(--accent-gold);
            font-weight: 300;
            letter-spacing: 2px;
            margin-top: 0.5rem;
            text-shadow: 0 2px 10px rgba(0, 0, 0, 0.5);
        }
        
        .loading {
            text-align: center;
            padding: 4rem 2rem;
            color: var(--text-secondary);
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
            opacity: 0;
            animation: fadeInUp 0.5s ease-out forwards;
        }
        
        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
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
        
        .flame-emoji {
            font-size: 1.5rem;
            animation: flicker 1.5s infinite;
        }
        
        @keyframes flicker {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        
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

    <main class="container" id="menu-container">
        <div class="loading">
            <p>Loading menu...</p>
        </div>
    </main>

    <footer class="footer">
        <p><span class="flame-emoji">🔥</span> DEVILS SMASH BURGER <span class="flame-emoji">🔥</span></p>
        <p style="margin-top: 1rem;">Made with ❤️ and 🍔</p>
    </footer>

    <script>
        const SUPABASE_URL = 'https://iluhlynzkgubtaswvgwt.supabase.co';
        const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3aWFmemJhdndzeGZheHd6bmxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI4Mjk5NTUsImV4cCI6MjA0ODQwNTk1NX0.Y8r7-A0fgYCQVy8lWCbXxvmQJMh_SxVJODUgb8h56wY';
        const DEVILS_BRAND_ID = '4446a388-aaa7-402f-be4d-b82b23797415';

        async function fetchMenu() {
            try {
                const headers = {
                    'apikey': SUPABASE_ANON_KEY,
                    'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
                };

                // Fetch categories
                const categoriesUrl = SUPABASE_URL + '/rest/v1/menu_categories?brand_id=eq.' + DEVILS_BRAND_ID + '&order=display_order.asc&select=*';
                const categoriesResponse = await fetch(categoriesUrl, { headers });
                const categories = await categoriesResponse.json();

                // Fetch menu items
                const itemsUrl = SUPABASE_URL + '/rest/v1/menu_items?brand_id=eq.' + DEVILS_BRAND_ID + '&order=display_order.asc&select=*';
                const itemsResponse = await fetch(itemsUrl, { headers });
                const allItems = await itemsResponse.json();

                // Group items by category
                const itemsByCategory = {};
                categories.forEach(category => {
                    itemsByCategory[category.id] = allItems.filter(item => item.category_id === category.id);
                });

                renderMenu(categories, itemsByCategory);
            } catch (error) {
                console.error('Error loading menu:', error);
                document.getElementById('menu-container').innerHTML = 
                    '<div class="loading"><p style="color: #DC143C;">Error loading menu. Please refresh the page.</p></div>';
            }
        }

        function cleanImageUrl(url) {
            if (!url) return null;
            // Remove blob: references and only use proper Supabase URLs
            if (url.includes('blob:')) return null;
            if (url.startsWith('https://') && url.includes('supabase.co')) return url;
            return null;
        }

        function renderMenu(categories, itemsByCategory) {
            const container = document.getElementById('menu-container');
            let html = '';

            categories.forEach((category, categoryIndex) => {
                const items = itemsByCategory[category.id] || [];
                if (items.length === 0) return;

                html += '<section class="menu-category">';
                html += '<h2 class="category-title">' + category.name + '</h2>';
                html += '<div class="menu-grid">';

                items.forEach((item, itemIndex) => {
                    const delay = (categoryIndex * 0.1 + itemIndex * 0.05);
                    const imageUrl = cleanImageUrl(item.image_url);
                    const price = item.price ? item.price.toFixed(2) : '0.00';
                    
                    html += '<div class="menu-item" style="animation-delay: ' + delay + 's">';
                    
                    if (imageUrl) {
                        html += '<div class="item-image">';
                        html += '<img src="' + imageUrl + '" alt="' + item.name + '" loading="lazy" onerror="this.parentElement.style.display=\\'none\\'">';
                        html += '</div>';
                    }
                    
                    html += '<div class="item-details">';
                    html += '<div class="item-header">';
                    html += '<h3 class="item-name">' + item.name + '</h3>';
                    html += '<span class="item-price">€' + price + '</span>';
                    html += '</div>';
                    
                    if (item.description) {
                        html += '<p class="item-description">' + item.description + '</p>';
                    }
                    
                    html += '</div>';
                    html += '</div>';
                });

                html += '</div>';
                html += '</section>';
            });

            container.innerHTML = html;
        }

        // Load menu on page load
        fetchMenu();
    </script>
</body>
</html>
''';
}


