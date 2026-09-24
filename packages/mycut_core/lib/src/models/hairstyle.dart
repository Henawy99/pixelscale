import 'package:mycut_cutspec/mycut_cutspec.dart';

/// Category groupings for the hairstyle catalog.
enum HairstyleCategory {
  fades('Fades', '💇'),
  classic('Classic', '✂️'),
  textured('Textured', '🌊'),
  buzz('Buzz', '⚡'),
  long('Long', '🦁');

  const HairstyleCategory(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// A curated hairstyle definition for the style browser.
///
/// Each hairstyle contains a human-readable description, a prompt fragment
/// for the AI model, and a default [CutSpec] that represents the style's
/// typical barber parameters.
class Hairstyle {
  const Hairstyle({
    required this.key,
    required this.name,
    required this.category,
    required this.description,
    required this.promptFragment,
    required this.defaultCutSpec,
    this.tags = const [],
  });

  /// Unique identifier for this style (e.g., 'low_fade').
  final String key;

  /// Display name (e.g., 'Low Fade').
  final String name;

  /// Category this style belongs to.
  final HairstyleCategory category;

  /// Brief human-readable description for the style browser card.
  final String description;

  /// AI prompt fragment injected into the generation prompt.
  ///
  /// Example: "a clean low fade with a gradual taper from skin at the
  /// temples blending to a #3 guard at the parietal ridge"
  final String promptFragment;

  /// The default cut specification for this style.
  final CutSpec defaultCutSpec;

  /// Search/filter tags (e.g., ['short', 'professional', 'clean']).
  final List<String> tags;

  @override
  String toString() => 'Hairstyle($key: $name)';
}
