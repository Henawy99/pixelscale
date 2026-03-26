import 'package:flutter/material.dart' show Color;
import 'package:supabase_flutter/supabase_flutter.dart';

class LevelInfo {
  final String id;
  String label;
  int colorValue;
  Color get color => Color(colorValue);
  List<String> classes;

  LevelInfo({
    required this.id,
    required this.label,
    required this.colorValue,
    required this.classes,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> json) {
    return LevelInfo(
      id: json['level_id'] as String,
      label: json['label'] as String,
      colorValue: int.tryParse(json['color_value'].toString()) ?? 0xFF2E7D32,
      classes: (json['classes'] as List).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'level_id': id,
        'label': label,
        'color_value': colorValue.toString(),
        'classes': classes,
      };
}

// In-memory cache of levels, loaded at app start map from level.id to LevelInfo
Map<String, LevelInfo> kLevels = {
  'green': LevelInfo(
    id: 'green',
    label: 'Green',
    colorValue: 0xFF2E7D32,
    classes: ['Avocado', 'Lemons'],
  ),
};

List<LevelInfo> get allLevelValues => kLevels.values.toList();
List<String> get allClasses => kLevels.values.expand((e) => e.classes).toList();
List<String> classesForLevel(String levelId) => kLevels[levelId]?.classes ?? [];

LevelInfo? levelInfoForClass(String className) {
  for (final info in kLevels.values) {
    if (info.classes.contains(className)) return info;
  }
  return null;
}

// Legacy mappings for older code expecting Enums or Enum names.
String levelColorToDb(dynamic c) => c.toString();

LevelInfo levelColorFromDb(String s) {
  if (kLevels.containsKey(s)) return kLevels[s]!;
  if (kLevels.isNotEmpty) return kLevels.values.first; // fallback
  return LevelInfo(id: s, label: s, colorValue: 0xFF9E9E9E, classes: []);
}

Future<void> loadAcademyClasses() async {
  try {
    final client = Supabase.instance.client;
    final res = await client.from('academy_classes').select();
    final list = res as List;
    if (list.isNotEmpty) {
      kLevels.clear();
      for (final item in list) {
        final info = LevelInfo.fromJson(Map<String, dynamic>.from(item as Map));
        kLevels[info.id] = info;
      }
    }
  } catch (e) {
    // Fallback to initial default cache if offline/error.
  }
}

Future<void> saveAcademyClass(LevelInfo info) async {
  final client = Supabase.instance.client;
  await client.from('academy_classes').upsert(
    info.toJson(),
    onConflict: 'level_id',
  );
  kLevels[info.id] = info;
}

Future<void> deleteAcademyClass(String levelId) async {
  final client = Supabase.instance.client;
  await client.from('academy_classes').delete().eq('level_id', levelId);
  kLevels.remove(levelId);
}
