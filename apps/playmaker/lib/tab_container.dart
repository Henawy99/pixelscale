import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomTabContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool clipImage; // Add this line

  const CustomTabContainer({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.color = Colors.white,
    this.clipImage = false, // Add this line
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(1.1, 1.1),
            blurRadius: 10.0,
          ),
        ],
      ),
      child: clipImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: child,
            )
          : Padding(
              padding: padding,
              child: child,
            ),
    );
  }
}

String formatJoinedDate(DateTime joined) {
  final DateFormat formatter = DateFormat('dd.MM.yyyy');
  return formatter.format(joined);
}
