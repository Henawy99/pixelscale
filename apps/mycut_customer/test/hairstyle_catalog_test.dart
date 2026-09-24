import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_customer/src/data/hairstyle_catalog.dart';

void main() {
  group('hairstyleCatalog', () {
    test('contains exactly 24 styles', () {
      expect(hairstyleCatalog, hasLength(24));
    });

    test('all keys are unique', () {
      final keys = hairstyleCatalog.map((s) => s.key).toSet();
      expect(keys, hasLength(24));
    });

    test('all styles have non-empty prompt fragments', () {
      for (final style in hairstyleCatalog) {
        expect(
          style.promptFragment,
          isNotEmpty,
          reason: '${style.key} has empty prompt fragment',
        );
      }
    });

    test('all styles have non-empty descriptions', () {
      for (final style in hairstyleCatalog) {
        expect(
          style.description,
          isNotEmpty,
          reason: '${style.key} has empty description',
        );
      }
    });

    test('all styles have valid defaultCutSpec', () {
      for (final style in hairstyleCatalog) {
        expect(
          style.defaultCutSpec.fadeGuardStart,
          greaterThanOrEqualTo(0),
          reason: '${style.key} has negative guard start',
        );
        expect(
          style.defaultCutSpec.fadeGuardEnd,
          greaterThanOrEqualTo(style.defaultCutSpec.fadeGuardStart),
          reason: '${style.key} has guard end < guard start',
        );
        expect(
          style.defaultCutSpec.topLengthMm,
          greaterThan(0),
          reason: '${style.key} has zero/negative top length',
        );
      }
    });
  });

  group('Category distribution', () {
    test('Fades has 8 styles', () {
      final fades = getStylesByCategory(HairstyleCategory.fades);
      expect(fades, hasLength(8));
    });

    test('Classic has 6 styles', () {
      final classic = getStylesByCategory(HairstyleCategory.classic);
      expect(classic, hasLength(6));
    });

    test('Textured has 4 styles', () {
      final textured = getStylesByCategory(HairstyleCategory.textured);
      expect(textured, hasLength(4));
    });

    test('Buzz has 3 styles', () {
      final buzz = getStylesByCategory(HairstyleCategory.buzz);
      expect(buzz, hasLength(3));
    });

    test('Long has 3 styles', () {
      final long = getStylesByCategory(HairstyleCategory.long);
      expect(long, hasLength(3));
    });

    test('null category returns all styles', () {
      expect(getStylesByCategory(null), hasLength(24));
    });
  });

  group('getStyleByKey', () {
    test('finds known style', () {
      final style = getStyleByKey('mid_fade');
      expect(style, isNotNull);
      expect(style!.name, 'Mid Fade');
    });

    test('returns null for unknown key', () {
      expect(getStyleByKey('nonexistent'), isNull);
    });

    test('finds every catalog entry by key', () {
      for (final style in hairstyleCatalog) {
        expect(getStyleByKey(style.key), isNotNull);
      }
    });
  });
}
