/// The confidence level of a [CutSpec].
enum CutSpecConfidence {
  /// The customer selected this from an AI-generated image.
  customerEstimate,

  /// A professional barber reviewed and corrected the spec after a real cut.
  barberConfirmed,
}

/// Fade type classification.
enum FadeType {
  low,
  mid,
  high,
  taper,
  drop,
  burst,
  none,
}

/// Neckline execution style.
enum Neckline {
  blocked,
  rounded,
  tapered,
}

/// Sideburn length.
enum SideburnLength {
  short,
  mid,
  long,
  natural,
}

/// Hair part style.
enum HairPart {
  none,
  natural,
  hardLeft,
  hardRight,
}

/// Styling finish type.
enum StylingFinish {
  matteClay,
  pomade,
  airDry,
  blowDry,
}

/// Hair texture direction on top.
enum TextureDirection {
  forward,
  back,
  left,
  right,
  up,
}

/// Structured cut specification — the barber-readable output.
///
/// This is a plain Dart class for Step 1. Will be migrated to `freezed`
/// in Step 4 when the full model layer is built.
class CutSpec {
  const CutSpec({
    required this.fadeType,
    required this.fadeGuardStart,
    required this.fadeGuardEnd,
    required this.topLengthMm,
    this.texture,
    this.textureDirection,
    this.neckline = Neckline.tapered,
    this.sideburns = SideburnLength.natural,
    this.beardGuard,
    this.part = HairPart.none,
    this.styling,
    this.confidence = CutSpecConfidence.customerEstimate,
  });

  /// Deserializes a [CutSpec] from a JSON-compatible map.
  factory CutSpec.fromJson(Map<String, dynamic> json) {
    final sides = json['sides'] as Map<String, dynamic>? ?? {};
    final top = json['top'] as Map<String, dynamic>? ?? {};
    final beard = json['beard'] as Map<String, dynamic>?;

    return CutSpec(
      fadeType: FadeType.values.firstWhere(
        (e) => e.name == sides['fade_type'],
        orElse: () => FadeType.mid,
      ),
      fadeGuardStart: (sides['guard_start'] as num?)?.toInt() ?? 1,
      fadeGuardEnd: (sides['guard_end'] as num?)?.toInt() ?? 4,
      topLengthMm: (top['length_mm'] as num?)?.toInt() ?? 40,
      texture: top['texture'] as String?,
      textureDirection: top['direction'] != null
          ? TextureDirection.values.firstWhere(
              (e) => e.name == top['direction'],
              orElse: () => TextureDirection.forward,
            )
          : null,
      neckline: Neckline.values.firstWhere(
        (e) => e.name == json['neckline'],
        orElse: () => Neckline.tapered,
      ),
      sideburns: SideburnLength.values.firstWhere(
        (e) => e.name == json['sideburns'],
        orElse: () => SideburnLength.natural,
      ),
      beardGuard: (beard?['guard'] as num?)?.toInt(),
      part: HairPart.values.firstWhere(
        (e) => e.name == json['part'],
        orElse: () => HairPart.none,
      ),
      styling: json['styling'] != null
          ? StylingFinish.values.firstWhere(
              (e) => e.name == json['styling'],
              orElse: () => StylingFinish.matteClay,
            )
          : null,
      confidence: CutSpecConfidence.values.firstWhere(
        (e) => e.name == json['confidence'],
        orElse: () => CutSpecConfidence.customerEstimate,
      ),
    );
  }

  /// The type of fade on the sides.
  final FadeType fadeType;

  /// Starting guard number at the lowest point of the fade (0–8).
  final int fadeGuardStart;

  /// Ending guard number at the parietal ridge (0–8).
  final int fadeGuardEnd;

  /// Length on top in millimeters.
  final int topLengthMm;

  /// Texture technique applied on top (e.g., "point_cut", "slide_cut").
  final String? texture;

  /// Direction of hair on top.
  final TextureDirection? textureDirection;

  /// Neckline execution style.
  final Neckline neckline;

  /// Sideburn length.
  final SideburnLength sideburns;

  /// Beard guard number, if applicable.
  final int? beardGuard;

  /// Hair part style.
  final HairPart part;

  /// Recommended styling finish.
  final StylingFinish? styling;

  /// How confident the spec is — customer guess vs barber-verified.
  final CutSpecConfidence confidence;

  /// Produces a barber-readable summary sentence.
  ///
  /// Supports German (`de`) and English (`en`). Defaults to English
  /// for unrecognised locales.
  String describe({String locale = 'en'}) {
    final isGerman = locale.startsWith('de');

    final fadeLabel = _fadeLabel(fadeType, isGerman: isGerman);
    final sidesDesc = isGerman
        ? 'Seiten: #$fadeGuardStart bis #$fadeGuardEnd ($fadeLabel)'
        : 'Sides: #$fadeGuardStart to #$fadeGuardEnd ($fadeLabel)';

    final topInches = (topLengthMm / 25.4).toStringAsFixed(1);
    final topDesc = isGerman
        ? 'Oben: ${topLengthMm}mm (~$topInches")'
        : 'Top: ${topLengthMm}mm (~$topInches")';

    final neckDesc = isGerman
        ? 'Nacken: ${_necklineLabel(neckline, isGerman: true)}'
        : 'Neckline: ${_necklineLabel(neckline, isGerman: false)}';

    return '$sidesDesc · $topDesc · $neckDesc';
  }

  static String _fadeLabel(FadeType type, {required bool isGerman}) {
    return switch (type) {
      FadeType.low => isGerman ? 'Niedriger Fade' : 'Low Fade',
      FadeType.mid => isGerman ? 'Mittlerer Fade' : 'Mid Fade',
      FadeType.high => isGerman ? 'Hoher Fade' : 'High Fade',
      FadeType.taper => 'Taper',
      FadeType.drop => 'Drop Fade',
      FadeType.burst => 'Burst Fade',
      FadeType.none => isGerman ? 'Kein Fade' : 'No Fade',
    };
  }

  static String _necklineLabel(Neckline nl, {required bool isGerman}) {
    return switch (nl) {
      Neckline.blocked => isGerman ? 'Gerade Linie' : 'Blocked',
      Neckline.rounded => isGerman ? 'Abgerundet' : 'Rounded',
      Neckline.tapered => isGerman ? 'Auslaufend' : 'Tapered',
    };
  }

  /// Serializes the spec to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'sides': {
          'guard_start': fadeGuardStart,
          'guard_end': fadeGuardEnd,
          'fade_type': fadeType.name,
        },
        'top': {
          'length_mm': topLengthMm,
          if (texture != null) 'texture': texture,
          if (textureDirection != null) 'direction': textureDirection!.name,
        },
        'neckline': neckline.name,
        'sideburns': sideburns.name,
        if (beardGuard != null) 'beard': {'guard': beardGuard},
        'part': part.name,
        if (styling != null) 'styling': styling!.name,
        'confidence': confidence.name,
      };
}
