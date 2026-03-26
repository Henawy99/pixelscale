import 'package:flutter/material.dart';

class AppTheme {
  static final lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00BF63),
    primary: const Color(0xFF00BF63),
    onPrimary: Colors.white,
    secondary: const Color(0xFF00BF63),
    onSecondary: Colors.white,
    tertiary: const Color(0xFF00BF63).withOpacity(0.7),
    surface: Colors.white,
    background: Colors.white,
    error: Colors.red,
  );

  static ThemeData get theme => ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00BF63),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BF63),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFF00BF63),
          ),
        ),
        chipTheme: const ChipThemeData(
          selectedColor: Color(0xFF00BF63),
          side: BorderSide.none,
          showCheckmark: false,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFF00BF63),
          thumbColor: const Color(0xFF00BF63),
          inactiveTrackColor: const Color(0xFF00BF63).withOpacity(0.2),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00BF63), width: 2),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF00BF63)),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
} 