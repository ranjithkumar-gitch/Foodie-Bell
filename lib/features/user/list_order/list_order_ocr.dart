import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR (no network call) over a photographed shopping list —
/// returns each recognized line of text in reading order, left for
/// `list_order_parser.dart` to turn into item/quantity guesses. A fresh
/// [TextRecognizer] per call keeps this a plain function with nothing to
/// dispose at the call site.
Future<List<String>> recognizeListLines(File image) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFile(image));
    final lines = <String>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) lines.add(text);
      }
    }
    return lines;
  } finally {
    await recognizer.close();
  }
}
