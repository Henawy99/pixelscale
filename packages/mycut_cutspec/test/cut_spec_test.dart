import 'package:mycut_cutspec/mycut_cutspec.dart';
import 'package:test/test.dart';

void main() {
  group('CutSpec', () {
    const spec = CutSpec(
      fadeType: FadeType.mid,
      fadeGuardStart: 1,
      fadeGuardEnd: 4,
      topLengthMm: 45,
      texture: 'point_cut',
      textureDirection: TextureDirection.forward,
      sideburns: SideburnLength.mid,
      beardGuard: 3,
      styling: StylingFinish.matteClay,
    );

    test('describe() produces English summary', () {
      final desc = spec.describe();
      expect(desc, contains('Sides: #1 to #4'));
      expect(desc, contains('Mid Fade'));
      expect(desc, contains('Top: 45mm'));
      expect(desc, contains('Neckline: Tapered'));
    });

    test('describe() produces German summary', () {
      final desc = spec.describe(locale: 'de');
      expect(desc, contains('Seiten: #1 bis #4'));
      expect(desc, contains('Mittlerer Fade'));
      expect(desc, contains('Oben: 45mm'));
      expect(desc, contains('Nacken: Auslaufend'));
    });

    test('toJson() serializes correctly', () {
      final json = spec.toJson();

      final sides = json['sides'] as Map<String, dynamic>;
      expect(sides['guard_start'], equals(1));
      expect(sides['guard_end'], equals(4));
      expect(sides['fade_type'], equals('mid'));

      final top = json['top'] as Map<String, dynamic>;
      expect(top['length_mm'], equals(45));
      expect(top['texture'], equals('point_cut'));
      expect(top['direction'], equals('forward'));

      expect(json['neckline'], equals('tapered'));
      expect(json['sideburns'], equals('mid'));

      final beard = json['beard'] as Map<String, dynamic>;
      expect(beard['guard'], equals(3));
      expect(json['styling'], equals('matteClay'));
      expect(json['confidence'], equals('customerEstimate'));
    });

    test('toJson() omits null optional fields', () {
      const minimal = CutSpec(
        fadeType: FadeType.none,
        fadeGuardStart: 0,
        fadeGuardEnd: 0,
        topLengthMm: 50,
      );

      final json = minimal.toJson();
      final top = json['top'] as Map<String, dynamic>;
      expect(json.containsKey('beard'), isFalse);
      expect(json.containsKey('styling'), isFalse);
      expect(top.containsKey('texture'), isFalse);
      expect(top.containsKey('direction'), isFalse);
    });

    test('default confidence is customerEstimate', () {
      const s = CutSpec(
        fadeType: FadeType.low,
        fadeGuardStart: 1,
        fadeGuardEnd: 3,
        topLengthMm: 30,
      );
      expect(s.confidence, equals(CutSpecConfidence.customerEstimate));
    });

    test('barberConfirmed confidence serializes correctly', () {
      const s = CutSpec(
        fadeType: FadeType.high,
        fadeGuardStart: 0,
        fadeGuardEnd: 5,
        topLengthMm: 40,
        confidence: CutSpecConfidence.barberConfirmed,
      );
      expect(s.toJson()['confidence'], equals('barberConfirmed'));
    });
  });

  group('FadeType', () {
    test('all fade types are present', () {
      expect(
        FadeType.values,
        containsAll([
          FadeType.low,
          FadeType.mid,
          FadeType.high,
          FadeType.taper,
          FadeType.drop,
          FadeType.burst,
          FadeType.none,
        ]),
      );
    });
  });

  group('describe() all fade types', () {
    for (final ft in FadeType.values) {
      test('${ft.name} fade produces non-empty description', () {
        final spec = CutSpec(
          fadeType: ft,
          fadeGuardStart: 1,
          fadeGuardEnd: 3,
          topLengthMm: 25,
        );
        expect(spec.describe(), isNotEmpty);
        expect(spec.describe(locale: 'de'), isNotEmpty);
      });
    }
  });
}
