import 'package:flutter/material.dart';

class ReceiptFullscreenViewer extends StatelessWidget {
  final String imageUrl;
  const ReceiptFullscreenViewer({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: InteractiveViewer(
        child: Center(child: Image.network(imageUrl, fit: BoxFit.contain)),
      ),
    );
  }
}

