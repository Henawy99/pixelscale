# R8 keep rules for Google ML Kit Text Recognition
# These rules prevent R8 from removing classes required by the google_mlkit_text_recognition plugin.

# Keep specific language recognizer options and their builders
-keep class com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions { *; }
-keep class com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder { *; }
-keep class com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions { *; }
-keep class com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder { *; }
-keep class com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions { *; }
-keep class com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder { *; }
-keep class com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions { *; }
-keep class com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder { *; }

# Keep general TextRecognizerOptions and its Builder as they might also be referenced
-keep class com.google.mlkit.vision.text.TextRecognizerOptions { *; }
-keep class com.google.mlkit.vision.text.TextRecognizerOptions$Builder { *; }

# Broader rule if specific ones are not enough (can be commented out if the above are sufficient)
-keep class com.google.mlkit.vision.text.** { *; }

# Keep rules for the Flutter plugin wrapper if necessary (usually not needed if the above are correct)
-keep class com.google_mlkit_text_recognition.** { *; }
