import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service IA pour transformer le texte OCR en recette structurée
/// Appelle une Cloud Function Firebase (Gemini)
class AIService {
  /// URL de la Cloud Function déployée
  static const String _cloudFunctionUrl =
      'https://europe-west1-recette-magique-7de15.cloudfunctions.net/processRecipe';

  /// Transforme le texte OCR en recette structurée via Cloud Function
  ///
  /// Retour attendu :
  /// {
  ///   "title": "",
  ///   "category": "entrée | plat | dessert | boisson",
  ///   "ingredients": [],
  ///   "steps": [],
  ///   "tags": [],
  ///   "source": "",
  ///   "preparationTime": "",
  ///   "cookingTime": "",
  ///   "estimatedTime": ""
  /// }
  Future<Map<String, dynamic>?> processRecipeText(String ocrText) async {
    try {
      debugPrint('📤 Envoi du texte à l\'IA (${ocrText.length} caractères)');

      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': ocrText}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Recette reçue : ${data['title']}');
        return data;
      } else {
        debugPrint(
          '❌ Erreur Cloud Function '
          '${response.statusCode} : ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('🔥 Erreur traitement IA : $e');
      return null;
    }
  }
}