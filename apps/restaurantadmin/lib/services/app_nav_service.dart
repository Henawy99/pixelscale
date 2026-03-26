import 'package:flutter/foundation.dart';

class AppNavService {
  AppNavService._internal();
  static final AppNavService _instance = AppNavService._internal();
  factory AppNavService() => _instance;

  // 0 = Orders, 1 = Inventory, 2 = Menus, 3 = Payments
  final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);

  // True when DeliveryMonitorScreen is currently in foreground
  final ValueNotifier<bool> deliveryMonitorActive = ValueNotifier<bool>(false);

  void goToOrdersTab() {
    selectedTab.value = 0;
  }

  void goToInventoryTab() {
    selectedTab.value = 1;
  }
}

