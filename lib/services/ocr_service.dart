import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service OCR pour extraire le texte des images
/// Utilise Google ML Kit Text Recognition
class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extrait le texte depuis un fichier image
  /// Retourne le texte reconnu ou null en cas d'erreur
  Future<String?> extractTextFromImage(String imagePath) async {
    try {
      if (kIsWeb) {
        debugPrint('OCR non supporté sur le Web avec google_mlkit_text_recognition.');
        return null;
      }
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        debugPrint('Aucun texte détecté dans l\'image');
        return null;
      }

      debugPrint('Texte extrait (${recognizedText.text.length} caractères)');
      return recognizedText.text;
    } catch (e) {
      debugPrint('Erreur OCR: $e');
      return null;
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _textRecognizer.close();
  }
}
