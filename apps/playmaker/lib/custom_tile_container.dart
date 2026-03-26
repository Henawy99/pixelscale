import 'package:flutter/material.dart';

class CustomTileContainer extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final double? height; // Nullable height parameter

  const CustomTileContainer({
    Key? key,
    required this.child,
    this.isSelected = false,
    this.height, // Initialize the height
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 70, 
      decoration: BoxDecoration(
        color: isSelected ? Colors.green[50] : Colors.white,
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey[300]!,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: child,
      ),
    );
  }
}
