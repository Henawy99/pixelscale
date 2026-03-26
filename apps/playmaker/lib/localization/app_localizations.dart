import 'package:flutter/material.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationManager {
  // Supported locales
  static const Locale enLocale = Locale('en');
  static const Locale arLocale = Locale('ar');
  
  static const List<Locale> supportedLocales = [
    enLocale,
    arLocale,
  ];
  
  // Default locale
  static const Locale fallbackLocale = Locale('en');
  
  // Preference key
  static const String _localeKey = 'selectedLocale';
  
  // Current locale - will be loaded from shared preferences
  static Locale? _currentLocale;
  
  // Get current locale
  static Locale get currentLocale => _currentLocale ?? fallbackLocale;
  
  // Check if the current locale is RTL
  static bool get isRtl => _currentLocale?.languageCode == 'ar';
  
  // Initialize localization preference
  static Future<Locale> init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? localeString = prefs.getString(_localeKey);
    
    if (localeString != null) {
      List<String> localeParts = localeString.split('_');
      String languageCode = localeParts[0];
      String? countryCode = localeParts.length > 1 ? localeParts[1] : null;
      
      _currentLocale = Locale(languageCode, countryCode);
    } else {
      _currentLocale = fallbackLocale;
    }
    
    return _currentLocale!;
  }
  
  // Change language
  static Future<void> changeLocale(BuildContext context, Locale newLocale) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String localeString = newLocale.countryCode != null 
        ? '${newLocale.languageCode}_${newLocale.countryCode}'
        : newLocale.languageCode;
    
    await prefs.setString(_localeKey, localeString);
    _currentLocale = newLocale;
  }
  
  // Helper method to get AppLocalizations from context
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context)!;
  }
}

// Extension to easily get localizations from context
extension LocalizationExtension on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this)!;
} 