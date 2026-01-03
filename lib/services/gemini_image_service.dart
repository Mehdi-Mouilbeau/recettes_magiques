import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiImages {
  static const String _cloudFunctionUrl =
      'https://europe-west1-recette-magique-7de15.cloudfunctions.net/generateRecipeImage';

  static Future<Uint8List?> generateRecipeImage({
    required String title,
    required String category,
    required List<String> keyIngredients,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'category': category,
              'ingredients': keyIngredients,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) {
        debugPrint('Gemini image function failed: ${resp.statusCode} ${resp.body}');
        return null;
      }

      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final b64 = (data['b64'] as String?) ?? '';
      if (b64.isEmpty) return null;

      return base64Decode(b64);
    } catch (e) {
      debugPrint('Gemini image generation error: $e');
      return null;
    }
  }
}
