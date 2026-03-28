import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CategoryCard extends StatelessWidget {
  final String categoryName;
  final String? imageUrl; // Now nullable
  final bool isNetworkImage; // To distinguish between asset and network
  final VoidCallback onTap;
  final VoidCallback? onSettingsTap;
  final Map<String, double?>? ratings;

  const CategoryCard({
    super.key,
    required this.categoryName,
    this.imageUrl,
    this.isNetworkImage = false,
    required this.onTap,
    this.onSettingsTap,
    this.ratings,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (isNetworkImage) {
        imageWidget = CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image_outlined, size: 50, color: Colors.grey[600]),
          ),
        );
      } else {
        // Asset image
        imageWidget = Image.asset(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
            print("Error loading asset: $imageUrl, Exception: $exception");
            return Container(
              color: Colors.grey[300],
              child: Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey[600]),
            );
          },
        );
      }
    } else {
      // Placeholder if no image URL is provided
      imageWidget = Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(Icons.category_outlined, size: 50, color: Colors.grey[400]),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2.0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        margin: const EdgeInsets.all(4),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: <Widget>[
            Positioned.fill(child: imageWidget),
            // Gradient overlay for text readability
            Container(
              height: 60, // Smaller overlay to reduce card visual size
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withAlpha((0.7 * 255).round()), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            // Category Name
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                categoryName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  shadows: <Shadow>[ // Adding a subtle shadow for better readability
                    Shadow(
                      offset: Offset(1.0, 1.0),
                      blurRadius: 3.0,
                      color: Color.fromARGB(150, 0, 0, 0),
                    ),
                  ],
                ),
              ),
            ),
            if (ratings != null && ratings!.values.any((r) => r != null))
              Positioned(
                bottom: 40,
                left: 12,
                right: 12,
                child: Row(
                  children: ratings!.entries
                      .where((e) => e.value != null)
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: e.value! < 4.0 ? Colors.redAccent : Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${e.key[0]}: ${e.value}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            if (onSettingsTap != null)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                  onPressed: onSettingsTap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
