import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final bool clipImage;

  const CustomContainer({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.all(8.0),
    this.color = Colors.white,
    this.clipImage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.6),
            offset: const Offset(1.1, 1.1),
            blurRadius: 10.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: child,
      ),
    );
  }
}

String formatJoinedDate(DateTime joined) {
  final DateFormat formatter = DateFormat('dd.MM.yyyy');
  return formatter.format(joined);
}
