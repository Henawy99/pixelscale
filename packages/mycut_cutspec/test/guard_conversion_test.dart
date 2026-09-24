import 'package:mycut_cutspec/mycut_cutspec.dart';
import 'package:test/test.dart';

void main() {
  group('guardToMm (Wahl)', () {
    test('guard 0 returns 1.5mm', () {
      expect(guardToMm(0), equals(1.5));
    });

    test('guard 1 returns 3.0mm', () {
      expect(guardToMm(1), equals(3));
    });

    test('guard 2 returns 6.0mm', () {
      expect(guardToMm(2), equals(6));
    });

    test('guard 3 returns 10.0mm', () {
      expect(guardToMm(3), equals(10));
    });

    test('guard 4 returns 13.0mm', () {
      expect(guardToMm(4), equals(13));
    });

    test('guard 5 returns 16.0mm', () {
      expect(guardToMm(5), equals(16));
    });

    test('guard 6 returns 19.0mm', () {
      expect(guardToMm(6), equals(19));
    });

    test('guard 7 returns 22.0mm', () {
      expect(guardToMm(7), equals(22));
    });

    test('guard 8 returns 25.0mm', () {
      expect(guardToMm(8), equals(25));
    });

    test('negative guard throws ArgumentError', () {
      expect(() => guardToMm(-1), throwsArgumentError);
    });

    test('guard 9 throws ArgumentError', () {
      expect(() => guardToMm(9), throwsArgumentError);
    });
  });

  group('mmToNearestGuard (Wahl)', () {
    test('exact match: 6.0mm → guard 2', () {
      expect(mmToNearestGuard(6), equals(2));
    });

    test('exact match: 1.5mm → guard 0', () {
      expect(mmToNearestGuard(1.5), equals(0));
    });

    test('between guard 1 (3mm) and guard 2 (6mm): 4.0mm → guard 1', () {
      expect(mmToNearestGuard(4), equals(1));
    });

    test('between guard 1 and guard 2: 5.0mm → guard 2', () {
      expect(mmToNearestGuard(5), equals(2));
    });

    test('0mm → guard 0 (closest)', () {
      expect(mmToNearestGuard(0), equals(0));
    });

    test('30mm → guard 8 (closest to 25mm)', () {
      expect(mmToNearestGuard(30), equals(8));
    });

    test('negative mm throws ArgumentError', () {
      expect(() => mmToNearestGuard(-1), throwsArgumentError);
    });
  });

  group('ClipperBrand methods', () {
    test('all brands have tables for guards 0-8', () {
      for (final brand in ClipperBrand.values) {
        for (var g = 0; g <= 8; g++) {
          expect(
            brand.guardToMm(g),
            isA<double>(),
            reason: '${brand.name} guard $g should return a double',
          );
        }
      }
    });

    test('Andis brand works independently', () {
      expect(
        guardToMm(2, brand: ClipperBrand.andis),
        equals(6),
      );
    });

    test('Oster brand mmToNearestGuard works', () {
      expect(
        mmToNearestGuard(10, brand: ClipperBrand.oster),
        equals(3),
      );
    });
  });
}
