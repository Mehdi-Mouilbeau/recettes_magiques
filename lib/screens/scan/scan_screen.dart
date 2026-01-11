import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/services/ocr_service.dart';
import 'package:recette_magique/services/ai_service.dart';
import 'package:recette_magique/models/recipe_model.dart';

/// Écran de scan de recette avec OCR
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final OCRService _ocrService = OCRService();
  final AIService _aiService = AIService();

  String? _imagePath;
  Uint8List? _imageBytes;
  String? _extractedText;
  bool _isProcessing = false;
  String _processingStep = '';

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

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Recette ajoutée avec succès !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 3000,
        maxHeight: 3000,
      );

      if (!mounted) return;

      if (image != null) {
        setState(() {
          _imagePath = image.path;
          _imageBytes = null;
          _extractedText = null;
        });

        try {
          final bytes = await image.readAsBytes();
          if (!mounted) return;
          setState(() => _imageBytes = bytes);
        } catch (_) {
          // ignore preview error
        }
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  Future<void> _processImage() async {
    if (_imagePath == null) return;

    await FirebaseAnalytics.instance.logEvent(name: 'scan_started');
    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _processingStep = 'Extraction du texte...';
    });

    try {
      final text = await _ocrService.extractTextFromImage(_imagePath!);
      if (!mounted) return;

      if (text == null || text.isEmpty) {
        _showError('Aucun texte détecté dans l\'image');
        if (!mounted) return;
        setState(() => _isProcessing = false);
        return;
      }

      setState(() {
        _extractedText = text;
        _processingStep = 'Traitement par l\'IA...';
      });

      final aiStart = DateTime.now();
      final aiResponse = await _aiService.processRecipeText(text);
      if (!mounted) return;

      final aiDurationMs = DateTime.now().difference(aiStart).inMilliseconds;

      await FirebaseAnalytics.instance.logEvent(
        name: 'ai_recipe_processed',
        parameters: {
          'duration_ms': aiDurationMs,
          'text_length': text.length,
        },
      );
      if (!mounted) return;

      if (aiResponse == null) {
        _showError('Erreur lors du traitement par l\'IA');
        if (!mounted) return;
        setState(() => _isProcessing = false);
        return;
      }

      setState(() {
        _processingStep = 'Sauvegarde de la recette...';
      });

      final authProvider = context.read<AuthProvider>();
      final recipeProvider = context.read<RecipeProvider>();

      final recipe = Recipe(
        userId: authProvider.currentUser!.uid,
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

      final success = await recipeProvider.createRecipe(recipe, _imagePath);
      if (!mounted) return;

      setState(() => _isProcessing = false);

      if (success) {
        _showSuccess();
        context.go('/home');
        return;
      }

      _showError('Erreur lors de la sauvegarde');
    } catch (_) {
      _showError('Une erreur est survenue');
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Scanner une recette',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text(
                        'Comment ça marche ?',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Prenez une photo claire de la recette\n'
                    '2. Le texte sera extrait automatiquement\n'
                    '3. L\'IA structurera la recette\n'
                    '4. Vérifiez et modifiez si nécessaire',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Prendre une photo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choisir depuis la galerie'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (_imagePath != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _imageBytes != null
                    ? Image.memory(
                        _imageBytes!,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 300,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 48),
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _isProcessing ? null : _processImage,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 16),
                          Text(_processingStep),
                        ],
                      )
                    : const Text('Traiter la recette'),
              ),
            ],

            if (_extractedText != null && !_isProcessing) ...[
              const SizedBox(height: 24),
              const Text(
                'Texte extrait',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _extractedText!,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
