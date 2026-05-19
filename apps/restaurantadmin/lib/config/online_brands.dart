import 'package:flutter/material.dart';

/// Public ordering sites — one slug per ghost kitchen (used in URLs and edge functions).
class OnlineBrandConfig {
  final String slug;
  final String id;
  final String name;
  final String tagline;
  final String logoAssetPath;
  final Color primaryColor;
  final Color accentColor;

  const OnlineBrandConfig({
    required this.slug,
    required this.id,
    required this.name,
    required this.tagline,
    required this.logoAssetPath,
    required this.primaryColor,
    required this.accentColor,
  });

  String get orderPath => '/order/$slug';
}

const List<OnlineBrandConfig> kOnlineBrands = [
  OnlineBrandConfig(
    slug: 'devils-smash-burger',
    id: '4446a388-aaa7-402f-be4d-b82b23797415',
    name: 'DEVILS SMASH BURGER',
    tagline: 'Smash burgers, frisch zubereitet.',
    logoAssetPath: 'assets/restaurantlogos/devilssmashburger.png',
    primaryColor: Color(0xFFC62828),
    accentColor: Color(0xFFFF6F00),
  ),
  OnlineBrandConfig(
    slug: 'tacotastic',
    id: 'f5116077-8de3-488b-bf9d-75295f791dce',
    name: 'TACOTASTIC',
    tagline: 'French Tacos & Street Food.',
    logoAssetPath: 'assets/restaurantlogos/tacotastic.jpeg',
    primaryColor: Color(0xFFE65100),
    accentColor: Color(0xFFFFD54F),
  ),
  OnlineBrandConfig(
    slug: 'crispy-chicken-lab',
    id: '8ec82a94-89f5-4603-bb35-c47c78d66d2a',
    name: 'CRISPY CHICKEN LAB',
    tagline: 'Knuspriges Hähnchen, jedes Mal.',
    logoAssetPath: 'assets/restaurantlogos/crispychickenlab.jpeg',
    primaryColor: Color(0xFFF9A825),
    accentColor: Color(0xFF5D4037),
  ),
  OnlineBrandConfig(
    slug: 'the-bowl-spot',
    id: '59bf0f09-ab58-48a0-9b3f-13c7709c8600',
    name: 'THE BOWL SPOT',
    tagline: 'Frische Bowls, voller Geschmack.',
    logoAssetPath: 'assets/restaurantlogos/thebowlspot.jpeg',
    primaryColor: Color(0xFF2E7D32),
    accentColor: Color(0xFF81C784),
  ),
];

OnlineBrandConfig? onlineBrandBySlug(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  final key = slug.toLowerCase().trim();
  for (final b in kOnlineBrands) {
    if (b.slug == key) return b;
  }
  return null;
}

bool isPublicOrderPath(String path) {
  final segments = Uri.parse(path).pathSegments;
  return segments.isNotEmpty && segments.first == 'order';
}

String? publicOrderSlugFromPath(String path) {
  final segments = Uri.parse(path).pathSegments;
  if (segments.length >= 2 && segments.first == 'order') {
    return segments[1];
  }
  return null;
}
