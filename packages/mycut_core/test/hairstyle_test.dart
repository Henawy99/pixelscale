import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';

void main() {
  group('HairstyleCategory', () {
    test('all categories have labels and emojis', () {
      for (final cat in HairstyleCategory.values) {
        expect(cat.label, isNotEmpty);
        expect(cat.emoji, isNotEmpty);
      }
    });

    test('has exactly 5 categories', () {
      expect(HairstyleCategory.values, hasLength(5));
    });
  });

  group('Hairstyle', () {
    test('can be constructed with required fields', () {
      const style = Hairstyle(
        key: 'test_style',
        name: 'Test Style',
        category: HairstyleCategory.fades,
        description: 'A test style description',
        promptFragment: 'a test style prompt fragment',
        defaultCutSpec: CutSpec(
          fadeType: FadeType.mid,
          fadeGuardStart: 0,
          fadeGuardEnd: 3,
          topLengthMm: 50,
        ),
      );

      expect(style.key, 'test_style');
      expect(style.name, 'Test Style');
      expect(style.category, HairstyleCategory.fades);
      expect(style.tags, isEmpty);
    });

    test('toString includes key and name', () {
      const style = Hairstyle(
        key: 'my_key',
        name: 'My Name',
        category: HairstyleCategory.classic,
        description: 'desc',
        promptFragment: 'prompt',
        defaultCutSpec: CutSpec(
          fadeType: FadeType.taper,
          fadeGuardStart: 1,
          fadeGuardEnd: 4,
          topLengthMm: 60,
        ),
      );

      expect(style.toString(), contains('my_key'));
      expect(style.toString(), contains('My Name'));
    });

    test('defaultCutSpec is accessible', () {
      const style = Hairstyle(
        key: 'buzz_cut',
        name: 'Buzz Cut',
        category: HairstyleCategory.buzz,
        description: 'desc',
        promptFragment: 'prompt',
        defaultCutSpec: CutSpec(
          fadeType: FadeType.none,
          fadeGuardStart: 2,
          fadeGuardEnd: 2,
          topLengthMm: 6,
        ),
      );

      expect(style.defaultCutSpec.fadeType, FadeType.none);
      expect(style.defaultCutSpec.fadeGuardStart, 2);
      expect(style.defaultCutSpec.topLengthMm, 6);
    });

    test('tags can be provided', () {
      const style = Hairstyle(
        key: 'tagged',
        name: 'Tagged',
        category: HairstyleCategory.textured,
        description: 'desc',
        promptFragment: 'prompt',
        tags: ['modern', 'trendy', 'european'],
        defaultCutSpec: CutSpec(
          fadeType: FadeType.high,
          fadeGuardStart: 0,
          fadeGuardEnd: 2,
          topLengthMm: 40,
        ),
      );

      expect(style.tags, hasLength(3));
      expect(style.tags, contains('modern'));
      expect(style.tags, contains('trendy'));
    });
  });
}
