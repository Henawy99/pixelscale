import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';

/// The complete catalog of 24 curated hairstyles for the style browser.
///
/// Organized into 5 categories: Fades, Classic, Textured, Buzz, Long.
/// Each entry includes a prompt fragment for AI generation and a default
/// [CutSpec] representing the style's typical barber parameters.
const List<Hairstyle> hairstyleCatalog = [
  // ─────────── Fades ───────────
  Hairstyle(
    key: 'low_fade',
    name: 'Low Fade',
    category: HairstyleCategory.fades,
    description: 'Gradual taper starting just above the ear',
    promptFragment:
        'a clean low fade with a gradual taper starting just above the ear',
    tags: ['professional', 'clean', 'versatile'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.low,
      fadeGuardStart: 0,
      fadeGuardEnd: 3,
      topLengthMm: 50,
    ),
  ),
  Hairstyle(
    key: 'mid_fade',
    name: 'Mid Fade',
    category: HairstyleCategory.fades,
    description: 'Balanced blend starting at the mid-point of the sides',
    promptFragment:
        'a mid fade with the blend starting at the mid-point of the sides',
    tags: ['popular', 'balanced', 'modern'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.mid,
      fadeGuardStart: 0,
      fadeGuardEnd: 3,
      topLengthMm: 50,
    ),
  ),
  Hairstyle(
    key: 'high_fade',
    name: 'High Fade',
    category: HairstyleCategory.fades,
    description:
        'Dramatic contrast with the blend starting '
        'high near the temples',
    promptFragment:
        'a high fade with the shortest length starting high near the temples',
    tags: ['bold', 'dramatic', 'sharp'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.high,
      fadeGuardStart: 0,
      fadeGuardEnd: 2,
      topLengthMm: 60,
    ),
  ),
  Hairstyle(
    key: 'skin_fade',
    name: 'Skin Fade',
    category: HairstyleCategory.fades,
    description: 'Sides taken down to bare skin with gradual upward blend',
    promptFragment:
        'a skin fade (bald fade) with sides taken down to bare skin',
    tags: ['bold', 'clean', 'sharp'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.high,
      fadeGuardStart: 0,
      fadeGuardEnd: 2,
      topLengthMm: 50,
    ),
  ),
  Hairstyle(
    key: 'drop_fade',
    name: 'Drop Fade',
    category: HairstyleCategory.fades,
    description: 'Curved arc that drops behind the ear',
    promptFragment:
        'a drop fade that drops behind the ear in a curved arc',
    tags: ['stylish', 'curved', 'modern'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.drop,
      fadeGuardStart: 0,
      fadeGuardEnd: 3,
      topLengthMm: 55,
    ),
  ),
  Hairstyle(
    key: 'burst_fade',
    name: 'Burst Fade',
    category: HairstyleCategory.fades,
    description: 'Circular pattern radiating from behind the ear',
    promptFragment:
        'a burst fade radiating outward from behind the ear',
    tags: ['trendy', 'unique', 'mohawk-compatible'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.burst,
      fadeGuardStart: 0,
      fadeGuardEnd: 3,
      topLengthMm: 60,
    ),
  ),
  Hairstyle(
    key: 'taper_fade',
    name: 'Taper Fade',
    category: HairstyleCategory.fades,
    description: 'Subtle, conservative blend from the natural hairline',
    promptFragment:
        'a classic taper fade with a subtle gradual '
        'blend from the natural hairline',
    tags: ['conservative', 'professional', 'subtle'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 1,
      fadeGuardEnd: 4,
      topLengthMm: 50,
    ),
  ),
  Hairstyle(
    key: 'temple_fade',
    name: 'Temple Fade',
    category: HairstyleCategory.fades,
    description: 'Only the temple and sideburn area faded',
    promptFragment:
        'a temple fade with only the temple and sideburn area faded',
    tags: ['minimal', 'clean', 'professional'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 1,
      fadeGuardEnd: 3,
      topLengthMm: 50,
    ),
  ),

  // ─────────── Classic ───────────
  Hairstyle(
    key: 'pompadour',
    name: 'Pompadour',
    category: HairstyleCategory.classic,
    description: 'Voluminous height on top swept back, 1950s inspired',
    promptFragment:
        'a classic pompadour with voluminous height on top swept back',
    tags: ['retro', 'volume', 'statement'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 1,
      fadeGuardEnd: 4,
      topLengthMm: 75,
      textureDirection: TextureDirection.back,
      styling: StylingFinish.pomade,
    ),
  ),
  Hairstyle(
    key: 'slick_back',
    name: 'Slick Back',
    category: HairstyleCategory.classic,
    description: 'Hair combed straight back with a polished wet-look finish',
    promptFragment:
        'a slick back style with hair combed straight back, sleek and polished',
    tags: ['polished', 'formal', 'sleek'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 2,
      fadeGuardEnd: 4,
      topLengthMm: 70,
      textureDirection: TextureDirection.back,
      styling: StylingFinish.pomade,
    ),
  ),
  Hairstyle(
    key: 'side_part',
    name: 'Side Part',
    category: HairstyleCategory.classic,
    description: 'Defined part line with hair combed to one side',
    promptFragment:
        'a classic side part with a defined part line, hair combed to one side',
    tags: ['professional', 'timeless', 'gentleman'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 2,
      fadeGuardEnd: 4,
      topLengthMm: 60,
      part: HairPart.hardLeft,
    ),
  ),
  Hairstyle(
    key: 'comb_over',
    name: 'Comb Over',
    category: HairstyleCategory.classic,
    description: 'Longer hair on top swept to one side with blended fade',
    promptFragment:
        'a modern comb over with longer hair on top swept to one side',
    tags: ['modern', 'versatile', 'professional'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.mid,
      fadeGuardStart: 1,
      fadeGuardEnd: 3,
      topLengthMm: 65,
      part: HairPart.hardLeft,
    ),
  ),
  Hairstyle(
    key: 'crew_cut',
    name: 'Crew Cut',
    category: HairstyleCategory.classic,
    description:
        'Short, uniform sides with slightly longer '
        'top brushed forward',
    promptFragment:
        'a classic crew cut with short uniform sides and slightly longer top',
    tags: ['military', 'clean', 'low-maintenance'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 1,
      fadeGuardEnd: 3,
      topLengthMm: 25,
      textureDirection: TextureDirection.forward,
    ),
  ),
  Hairstyle(
    key: 'ivy_league',
    name: 'Ivy League',
    category: HairstyleCategory.classic,
    description: 'Like a crew cut but with enough length to part and style',
    promptFragment:
        'an ivy league cut with enough length on top to part and style',
    tags: ['preppy', 'polished', 'professional'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 2,
      fadeGuardEnd: 4,
      topLengthMm: 40,
      part: HairPart.natural,
    ),
  ),

  // ───────────── Textured ─────────────
  Hairstyle(
    key: 'textured_crop',
    name: 'Textured Crop',
    category: HairstyleCategory.textured,
    description: 'Choppy layered texture on top with a sharp fade',
    promptFragment:
        'a textured crop with choppy layered texture on top falling forward',
    tags: ['modern', 'trendy', 'european'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.high,
      fadeGuardStart: 0,
      fadeGuardEnd: 2,
      topLengthMm: 40,
      texture: 'point_cut',
      textureDirection: TextureDirection.forward,
    ),
  ),
  Hairstyle(
    key: 'french_crop',
    name: 'French Crop',
    category: HairstyleCategory.textured,
    description: 'Short textured fringe falling forward with tight faded sides',
    promptFragment:
        'a French crop with a short textured fringe falling forward',
    tags: ['european', 'fringe', 'low-maintenance'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.mid,
      fadeGuardStart: 0,
      fadeGuardEnd: 2,
      topLengthMm: 35,
      textureDirection: TextureDirection.forward,
    ),
  ),
  Hairstyle(
    key: 'messy_fringe',
    name: 'Messy Fringe',
    category: HairstyleCategory.textured,
    description: 'Tousled piece-y bangs with relaxed texture throughout',
    promptFragment:
        'a messy fringe style with tousled piece-y bangs falling naturally',
    tags: ['casual', 'relaxed', 'youthful'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 2,
      fadeGuardEnd: 4,
      topLengthMm: 55,
      textureDirection: TextureDirection.forward,
      styling: StylingFinish.airDry,
    ),
  ),
  Hairstyle(
    key: 'textured_quiff',
    name: 'Textured Quiff',
    category: HairstyleCategory.textured,
    description: 'Volume lifted at the front with modern effortless texture',
    promptFragment:
        'a textured quiff with volume lifted at '
        'the front, modern and effortless',
    tags: ['volume', 'modern', 'versatile'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.mid,
      fadeGuardStart: 1,
      fadeGuardEnd: 3,
      topLengthMm: 60,
      textureDirection: TextureDirection.up,
      styling: StylingFinish.matteClay,
    ),
  ),

  // ─────────── Buzz ───────────
  Hairstyle(
    key: 'buzz_cut',
    name: 'Buzz Cut',
    category: HairstyleCategory.buzz,
    description: 'Single clipper guard length all over, clean and minimal',
    promptFragment:
        'a uniform buzz cut with a single clipper guard length all over',
    tags: ['minimal', 'low-maintenance', 'military'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.none,
      fadeGuardStart: 2,
      fadeGuardEnd: 2,
      topLengthMm: 6,
    ),
  ),
  Hairstyle(
    key: 'induction_buzz',
    name: 'Induction Buzz',
    category: HairstyleCategory.buzz,
    description: 'Shortest clipper setting all over the head',
    promptFragment:
        'an induction buzz with hair taken down to '
        'the shortest clipper setting',
    tags: ['minimal', 'zero-guard', 'clean'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.none,
      fadeGuardStart: 0,
      fadeGuardEnd: 0,
      topLengthMm: 1,
    ),
  ),
  Hairstyle(
    key: 'butch_cut',
    name: 'Butch Cut',
    category: HairstyleCategory.buzz,
    description: 'Slightly longer buzz on top with shorter sides',
    promptFragment:
        'a butch cut with slightly longer uniform '
        'buzz on top and shorter sides',
    tags: ['military', 'classic', 'clean'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.taper,
      fadeGuardStart: 1,
      fadeGuardEnd: 2,
      topLengthMm: 12,
    ),
  ),

  // ─────────── Long ───────────
  Hairstyle(
    key: 'man_bun',
    name: 'Man Bun',
    category: HairstyleCategory.long,
    description: 'Hair gathered at the crown into a neat bun',
    promptFragment:
        'a man bun with enough length to gather '
        'hair at the crown into a neat bun',
    tags: ['long', 'tied', 'trendy'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.none,
      fadeGuardStart: 4,
      fadeGuardEnd: 6,
      topLengthMm: 150,
    ),
  ),
  Hairstyle(
    key: 'curtains',
    name: 'Curtains',
    category: HairstyleCategory.long,
    description: 'Center-parted hair falling to each side, medium length',
    promptFragment:
        'curtain bangs with a center part, '
        'hair falling to each side of the face',
    tags: ['trendy', 'retro', 'e-boy'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.none,
      fadeGuardStart: 3,
      fadeGuardEnd: 5,
      topLengthMm: 100,
      part: HairPart.natural,
      styling: StylingFinish.airDry,
    ),
  ),
  Hairstyle(
    key: 'flow',
    name: 'Flow',
    category: HairstyleCategory.long,
    description: 'Medium-to-long hair swept back naturally with movement',
    promptFragment:
        'a flow hairstyle with medium-to-long hair swept back naturally',
    tags: ['natural', 'volume', 'movement'],
    defaultCutSpec: CutSpec(
      fadeType: FadeType.none,
      fadeGuardStart: 4,
      fadeGuardEnd: 6,
      topLengthMm: 120,
      textureDirection: TextureDirection.back,
      styling: StylingFinish.airDry,
    ),
  ),
];

/// Returns hairstyles filtered by [category], or all if null.
List<Hairstyle> getStylesByCategory(HairstyleCategory? category) {
  if (category == null) return hairstyleCatalog;
  return hairstyleCatalog.where((s) => s.category == category).toList();
}

/// Finds a hairstyle by its key, or null if not found.
Hairstyle? getStyleByKey(String key) {
  try {
    return hairstyleCatalog.firstWhere((s) => s.key == key);
  } catch (_) {
    return null;
  }
}
