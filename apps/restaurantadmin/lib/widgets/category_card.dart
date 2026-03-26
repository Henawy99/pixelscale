import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CategoryCard extends StatelessWidget {
  final String categoryName;
  final String? imageUrl; // Now nullable
  final bool isNetworkImage; // To distinguish between asset and network
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.categoryName,
    this.imageUrl, // Nullable
    this.isNetworkImage = false, // Default to asset image
    required this.onTap,
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
          ],
        ),
      ),
    );
  }
}
