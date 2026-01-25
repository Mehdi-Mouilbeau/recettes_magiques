import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// Service OCR pour extraire le texte des images
/// - Fix iOS: normalise l'orientation EXIF (très fréquent sur iPhone)
class OCRService {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String?> extractTextFromImage(String imagePath) async {
    try {
      final normalizedPath = await _normalizeImageIfNeeded(imagePath);

      final inputImage = InputImage.fromFilePath(normalizedPath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final text = recognizedText.text.trim();
      if (text.isEmpty) {
        debugPrint("Aucun texte détecté dans l'image");
        return null;
      }

      debugPrint('Texte extrait (${text.length} caractères)');
      return text;
    } catch (e) {
      debugPrint('Erreur OCR: $e');
      return null;
    }
  }

  /// Normalise l'image (applique rotation EXIF) et réécrit un fichier temporaire.
  /// Sur Android ça ne gêne pas, sur iOS ça règle souvent le "no text detected".
  Future<String> _normalizeImageIfNeeded(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return imagePath;

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imagePath;

      //  applique automatiquement l'orientation EXIF si présente
      final fixed = img.bakeOrientation(decoded);

      // Si rien n'a changé, on peut retourner l'original
      // (bakeOrientation retourne quand même une image, donc on compare grossièrement)
      if (fixed.width == decoded.width &&
          fixed.height == decoded.height &&
          fixed.format == decoded.format) {
        // Même dimensions / format → on évite d'écrire un nouveau fichier
        // (optionnel, tu peux enlever ce if si tu veux toujours réécrire)
      }

      final tempDir = Directory.systemTemp;
      final outPath =
          '${tempDir.path}/ocr_fixed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final outBytes = img.encodeJpg(fixed, quality: 95);
      await File(outPath).writeAsBytes(outBytes, flush: true);

      return outPath;
    } catch (e) {
      debugPrint('Normalize image failed (fallback to original): $e');
      return imagePath;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}