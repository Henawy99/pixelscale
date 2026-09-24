/// Clipper guard brands and their guard-to-millimeter lookup tables.
///
/// Guard sizes differ slightly between manufacturers. The default
/// is [ClipperBrand.wahl] (most common worldwide).
enum ClipperBrand {
  /// Wahl standard guards — the most widely used.
  wahl,

  /// Andis guards — slightly different at higher numbers.
  andis,

  /// Oster guards — classic US brand.
  oster;

  /// Returns the millimetre length for a given [guard] number (0–8).
  ///
  /// Throws [ArgumentError] if [guard] is out of range.
  double guardToMm(int guard) {
    if (guard < 0 || guard > 8) {
      throw ArgumentError.value(
        guard,
        'guard',
        'Must be between 0 and 8 inclusive.',
      );
    }
    return _tables[this]![guard]!;
  }

  /// Returns the nearest guard number for a given [mm] length.
  ///
  /// If the value falls exactly between two guards, rounds to the
  /// shorter guard (conservative).
  int mmToNearestGuard(double mm) {
    if (mm < 0) {
      throw ArgumentError.value(mm, 'mm', 'Must be non-negative.');
    }

    final table = _tables[this]!;
    var bestGuard = 0;
    var bestDiff = (mm - table[0]!).abs();

    for (var g = 1; g <= 8; g++) {
      final diff = (mm - table[g]!).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestGuard = g;
      }
    }

    return bestGuard;
  }

  static const Map<ClipperBrand, Map<int, double>> _tables = {
    ClipperBrand.wahl: {
      0: 1.5,
      1: 3.0,
      2: 6.0,
      3: 10.0,
      4: 13.0,
      5: 16.0,
      6: 19.0,
      7: 22.0,
      8: 25.0,
    },
    ClipperBrand.andis: {
      0: 1.5,
      1: 3.0,
      2: 6.0,
      3: 10.0,
      4: 13.0,
      5: 16.0,
      6: 19.0,
      7: 22.0,
      8: 25.0,
    },
    ClipperBrand.oster: {
      0: 1.5,
      1: 3.0,
      2: 6.0,
      3: 10.0,
      4: 13.0,
      5: 16.0,
      6: 19.0,
      7: 22.0,
      8: 25.0,
    },
  };
}
