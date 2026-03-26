import 'package:flutter/material.dart';

/// Validation utilities for forms
class Validators {
  /// Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    // Remove whitespace
    value = value.trim();
    
    // RFC 5322 compliant email regex (simplified)
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  /// Password validation - Simple and easy!
  static String? validatePassword(String? value, {bool isConfirm = false}) {
    if (value == null || value.isEmpty) {
      return isConfirm ? 'Please confirm your password' : 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  /// Password strength (0-3) - Simple scoring
  /// 0 = Weak, 1 = Fair, 2 = Good, 3 = Strong
  static int getPasswordStrength(String password) {
    if (password.isEmpty) return 0;
    
    int strength = 0;
    
    // Length-based scoring (simple and clear)
    if (password.length >= 6) strength++;
    if (password.length >= 8) strength++;
    if (password.length >= 10) strength++;
    
    return strength;
  }

  /// Get password strength label
  static String getPasswordStrengthLabel(int strength) {
    switch (strength) {
      case 0:
        return 'Too Short';
      case 1:
        return 'Fair';
      case 2:
        return 'Good';
      case 3:
        return 'Strong';
      default:
        return 'Too Short';
    }
  }

  /// Get password strength color
  static Color getPasswordStrengthColor(int strength) {
    switch (strength) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  /// Phone number validation (basic)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional in most cases
    }
    
    // Remove non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length < 7) {
      return 'Phone number is too short';
    }
    
    if (digitsOnly.length > 15) {
      return 'Phone number is too long';
    }
    
    return null;
  }

  /// Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    
    value = value.trim();
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (value.length > 50) {
      return 'Name is too long';
    }
    
    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }
    
    return null;
  }

  /// Age validation from birth date
  static String? validateAge(DateTime? birthDate) {
    if (birthDate == null) {
      return null; // Age is optional
    }
    
    final now = DateTime.now();
    final age = now.year - birthDate.year - 
        (now.month < birthDate.month || 
         (now.month == birthDate.month && now.day < birthDate.day) ? 1 : 0);
    
    if (age < 5) {
      return 'You must be at least 5 years old';
    }
    
    if (age > 120) {
      return 'Please enter a valid birth date';
    }
    
    return null;
  }
}

