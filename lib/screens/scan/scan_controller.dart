import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'package:recette_magique/services/ocr_service.dart';
import 'package:recette_magique/services/ai_service.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class ScanController extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  final OCRService _ocrService = OCRService();
  final AIService _aiService = AIService();

  String? _imagePath;
  Uint8List? _imageBytes;
  String? _extractedText;
  bool _isProcessing = false;
  String _processingStep = '';

  String? get imagePath => _imagePath;
  Uint8List? get imageBytes => _imageBytes;
  String? get extractedText => _extractedText;
  bool get isProcessing => _isProcessing;
  String get processingStep => _processingStep;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  int? _extractServings(Map<String, dynamic> data) {
    try {
      final keys = ['servings', 'persons', 'nbPersons', 'people', 'portions'];
      for (final k in keys) {
        if (data.containsKey(k) && data[k] != null) {
          final v = data[k];
          if (v is int) return v;
          if (v is double) return v.round();
          final m = RegExp(r'(\d+)').firstMatch(v.toString());
          if (m != null) return int.parse(m.group(1)!);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 3000,
        maxHeight: 3000,
      );

      if (image != null) {
        _imagePath = image.path;
        _imageBytes = null;
        _extractedText = null;
        notifyListeners();

        try {
          final bytes = await image.readAsBytes();
          _imageBytes = bytes;
          notifyListeners();
        } catch (_) {
          // ignore preview error
        }
      }
    } catch (e) {
      throw Exception('Erreur lors de la sélection de l\'image');
    }
  }

  Future<Recipe?> processImage({
    required String userId,
  }) async {
    if (_imagePath == null) return null;

    await FirebaseAnalytics.instance.logEvent(name: 'scan_started');

    _isProcessing = true;
    _processingStep = 'Extraction du texte...';
    notifyListeners();

    try {
      final text = await _ocrService.extractTextFromImage(_imagePath!);

      if (text == null || text.isEmpty) {
        _isProcessing = false;
        notifyListeners();
        throw Exception('Aucun texte détecté dans l\'image');
      }

      _extractedText = text;
      _processingStep = 'Traitement par l\'IA...';
      notifyListeners();

      final aiStart = DateTime.now();
      final aiResponse = await _aiService.processRecipeText(text);
      final aiDurationMs = DateTime.now().difference(aiStart).inMilliseconds;

      await FirebaseAnalytics.instance.logEvent(
        name: 'ai_recipe_processed',
        parameters: {
          'duration_ms': aiDurationMs,
          'text_length': text.length,
        },
      );

      if (aiResponse == null) {
        _isProcessing = false;
        notifyListeners();
        throw Exception('Erreur lors du traitement par l\'IA');
      }

      _processingStep = 'Sauvegarde de la recette...';
      notifyListeners();

      final recipe = Recipe(
        userId: userId,
        title: aiResponse['title'] as String,
        category: RecipeCategory.fromString(aiResponse['category'] as String),
        ingredients: List<String>.from(aiResponse['ingredients'] as List),
        steps: List<String>.from(aiResponse['steps'] as List),
        tags: List<String>.from(aiResponse['tags'] as List),
        source: aiResponse['source'] as String,
        estimatedTime: aiResponse['estimatedTime'] as String,
        servings: _extractServings(aiResponse),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _isProcessing = false;
      notifyListeners();

      return recipe;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    _imagePath = null;
    _imageBytes = null;
    _extractedText = null;
    _isProcessing = false;
    _processingStep = '';
    notifyListeners();
  }
}