import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.currency(locale: 'de_AT', symbol: '€', decimalDigits: 2);
final NumberFormat _plain = NumberFormat.decimalPattern('de_AT');

String formatMoney(double? amount) => amount == null ? '–' : _money.format(amount);

String formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d.toLocal());

String formatNumber(double n, {int maxDecimals = 2}) {
  final f = NumberFormat.decimalPattern('de_AT')..maximumFractionDigits = maxDecimals;
  return f.format(n);
}

/// 62500 gram → "62,5 kg", 19200 ml → "19,2 l", 24 piece → "24 pcs".
String formatQuantity(double amount, String unit, {bool signed = false}) {
  final sign = signed && amount > 0 ? '+' : '';
  final abs = amount.abs();
  final minus = amount < 0 ? '−' : '';
  String body;
  switch (unit) {
    case 'gram':
      body = abs >= 1000 ? '${formatNumber(abs / 1000)} kg' : '${formatNumber(abs, maxDecimals: 0)} g';
    case 'ml':
      body = abs >= 1000 ? '${formatNumber(abs / 1000)} l' : '${formatNumber(abs, maxDecimals: 0)} ml';
    case 'piece':
      body = '${formatNumber(abs)} pcs';
    default:
      body = '${formatNumber(abs)} $unit';
  }
  return '$sign$minus$body';
}

String unitLabel(String unit) => switch (unit) {
  'gram' => 'grams',
  'ml' => 'ml',
  'piece' => 'pieces',
  _ => unit,
};

String quantityText(double? q) => q == null ? '' : _plain.format(q);

/// Status chip colors and labels shared by the list and the detail screen.
({String label, Color color, IconData icon}) expenseStatusStyle(String status) => switch (status) {
  'analyzing' => (label: 'Reading…', color: const Color(0xFF6B7280), icon: Icons.hourglass_top_rounded),
  'failed' => (label: 'Could not read', color: const Color(0xFFDC2626), icon: Icons.error_outline_rounded),
  'booked' || 'approved' => (label: 'In stock', color: const Color(0xFF059669), icon: Icons.check_circle_rounded),
  'pending_review' => (label: 'Old scan', color: const Color(0xFF9CA3AF), icon: Icons.history_rounded),
  'recorded' => (label: 'Recorded', color: const Color(0xFF64748B), icon: Icons.history_edu_rounded),
  _ => (label: 'To review', color: const Color(0xFFD97706), icon: Icons.rate_review_outlined),
};

/// Stable avatar color per supplier name.
Color supplierColor(String name) {
  const palette = [
    Color(0xFF4F46E5),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF65A30D),
  ];
  return palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length];
}

String initials(String name) {
  final words = name.trim().split(RegExp(r'[\s&]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(1, 2)).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}
