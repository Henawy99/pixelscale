import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final String url;
  final String heroTag;
  const ReceiptViewerDialog({super.key, required this.url, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: AspectRatio(
                  aspectRatio: 3/4,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Download',
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

