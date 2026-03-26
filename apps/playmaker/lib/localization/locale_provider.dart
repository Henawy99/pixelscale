import 'package:flutter/material.dart';
import 'package:playmakerappstart/localization/app_localizations.dart'; // For LocalizationManager

class LocaleProvider extends ChangeNotifier {
  Locale _locale = LocalizationManager.fallbackLocale; // Initialize with fallback

  LocaleProvider() {
    _initLocale();
  }

  Locale get locale => _locale;

  Future<void> _initLocale() async {
    // Load initial locale from LocalizationManager which loads from SharedPreferences
    _locale = await LocalizationManager.init();
    notifyListeners();
  }

  void setLocale(Locale newLocale) {
    if (_locale == newLocale) return;
    _locale = newLocale;
    // The actual saving to SharedPreferences is handled by LocalizationManager.changeLocale
    // This provider is primarily for notifying listeners about the change.
    notifyListeners();
  }
}
