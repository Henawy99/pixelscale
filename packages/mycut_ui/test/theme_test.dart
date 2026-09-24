import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_ui/mycut_ui.dart';

void main() {
  group('MyCutTheme', () {
    test('dark theme is Material 3 dark', () {
      final theme = MyCutTheme.dark;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.dark));
    });

    test('dark theme uses correct primary color', () {
      final theme = MyCutTheme.dark;
      expect(theme.colorScheme.primary, equals(MyCutColors.primary));
    });

    test('dark theme scaffold background is surface', () {
      final theme = MyCutTheme.dark;
      expect(theme.scaffoldBackgroundColor, equals(MyCutColors.surface));
    });

    test('receiver theme has larger body text', () {
      final receiver = MyCutTheme.receiver;
      final dark = MyCutTheme.dark;

      expect(
        receiver.textTheme.bodyMedium?.fontSize,
        greaterThan(dark.textTheme.bodyMedium?.fontSize ?? 0),
        reason: 'Receiver needs min 24pt body for barber readability',
      );
    });

    test('receiver body medium is at least 24pt', () {
      final receiver = MyCutTheme.receiver;
      expect(
        receiver.textTheme.bodyMedium?.fontSize,
        greaterThanOrEqualTo(24),
      );
    });
  });

  group('MyCutColors', () {
    test('primary is gold', () {
      expect(MyCutColors.primary, equals(const Color(0xFFF2CA50)));
    });

    test('surface is near-black', () {
      expect(MyCutColors.surface, equals(const Color(0xFF131315)));
    });

    test('gold gradient has 3 stops', () {
      expect(MyCutColors.goldGradient.colors, hasLength(3));
    });
  });
}
