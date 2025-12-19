import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service IA pour transformer le texte OCR en recette structurée
/// Appelle une Cloud Function Firebase (Gemini)
class AIService {
  /// ✅ URL de la Cloud Function déployée
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
  ///   "estimatedTime": ""
  /// }
  Future<Map<String, dynamic>?> processRecipeText(String ocrText) async {
    try {
      debugPrint('📤 Envoi du texte à l’IA (${ocrText.length} caractères)');

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

  /// Simulation locale pour les tests (DEV uniquement)
  Future<Map<String, dynamic>> mockProcessRecipeText(String ocrText) async {
    await Future.delayed(const Duration(seconds: 2));

    final lowerText = ocrText.toLowerCase();
    String category = 'plat';

    if (lowerText.contains('dessert') ||
        lowerText.contains('gâteau') ||
        lowerText.contains('tarte') ||
        lowerText.contains('crème')) {
      category = 'dessert';
    } else if (lowerText.contains('salade') ||
        lowerText.contains('soupe') ||
        lowerText.contains('entrée')) {
      category = 'entrée';
    } else if (lowerText.contains('jus') ||
        lowerText.contains('boisson') ||
        lowerText.contains('cocktail')) {
      category = 'boisson';
    }

    return {
      'title': 'Recette extraite',
      'category': category,
      'ingredients': [
        'Ingrédient 1',
        'Ingrédient 2',
        'Ingrédient 3',
      ],
      'steps': [
        'Préparer les ingrédients',
        'Mélanger',
        'Cuire',
        'Servir',
      ],
      'tags': ['scan', 'test'],
      'source': 'OCR',
      'estimatedTime': '30 min',
    };
  }
}
