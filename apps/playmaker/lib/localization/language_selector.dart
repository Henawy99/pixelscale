import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:provider/provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                "Language / اللغة",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00BF63),
                ),
              ),
            ),
            _buildLanguageItem(
              context,
              "English",
              LocalizationManager.currentLocale.languageCode == 'en',
              () => _changeLanguage(context, LocalizationManager.enLocale),
              icon: "🇬🇧"
            ),
            _buildLanguageItem(
              context,
              "العربية",
              LocalizationManager.currentLocale.languageCode == 'ar',
              () => _changeLanguage(context, LocalizationManager.arLocale),
              icon: "🇪🇬"
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context,
    String name,
    bool isSelected,
    VoidCallback onTap, {
    String? icon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (icon != null) 
              Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF63),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeLanguage(BuildContext context, Locale locale) async {
    // Save the preference using LocalizationManager
    await LocalizationManager.changeLocale(context, locale);
    // Update the LocaleProvider to trigger UI rebuild
    Provider.of<LocaleProvider>(context, listen: false).setLocale(locale);
    // No need to pop or show dialog, change will be immediate
  }
}
