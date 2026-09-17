# google_mlkit_text_recognition (`pubspec.yaml`) bundles a language-switch
# path that references the optional Chinese/Devanagari/Japanese/Korean
# script recognizer variants — this app only pulls in the default (Latin)
# recognizer, so those classes are legitimately absent at build time. R8
# can't verify a call path it never takes, so without these rules a release
# build (`flutter build apk`/`--release`) fails outright with "Missing
# classes detected while running R8" even though nothing is actually
# broken at runtime. Rules below are exactly what AGP's own R8 run
# generates into build/app/outputs/mapping/release/missing_rules.txt when
# this file doesn't exist — codified here instead of regenerating by hand
# after every release build.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
