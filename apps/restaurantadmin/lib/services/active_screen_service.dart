import 'package:flutter/foundation.dart';

class ActiveScreenService {
  ActiveScreenService._internal();
  static final ActiveScreenService _instance = ActiveScreenService._internal();
  factory ActiveScreenService() => _instance;

  // Name of the current top-level screen (e.g., 'orders', 'delivery_monitor', etc.)
  final ValueNotifier<String?> currentTopScreen = ValueNotifier<String?>(null);
}

