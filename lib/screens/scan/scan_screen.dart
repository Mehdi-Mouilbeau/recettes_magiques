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
import 'package:recette_magique/theme.dart';

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100, // important iOS
        maxWidth: 3000,
        maxHeight: 3000,
      );
      
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
        } catch (e) {
          // On ignore l'erreur d'aperçu, cela n'empêche pas l'OCR ni l'upload
        }
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image');
    }
  }

  Future<void> _processImage() async {
    if (_imagePath == null) return;

    //  Analytics : l'utilisateur lance un scan
    await FirebaseAnalytics.instance.logEvent(
      name: 'scan_started',
    );

    setState(() {
      _isProcessing = true;
      _processingStep = 'Extraction du texte...';
    });

    try {
      // Étape 1: OCR
      final text = await _ocrService.extractTextFromImage(_imagePath!);
      if (text == null || text.isEmpty) {
        _showError('Aucun texte détecté dans l\'image');
        setState(() => _isProcessing = false);
        return;
      }

      setState(() {
        _extractedText = text;
        _processingStep = 'Traitement par l\'IA...';
      });

      // ⏱️ Début mesure IA
      final aiStart = DateTime.now();

      // Étape 2: Traitement IA (Cloud Function Gemini)
      final aiResponse = await _aiService.processRecipeText(text);

      // ⏱️ Fin mesure IA
      final aiDurationMs = DateTime.now().difference(aiStart).inMilliseconds;

// 🔥 Analytics : performance IA
      await FirebaseAnalytics.instance.logEvent(
        name: 'ai_recipe_processed',
        parameters: {
          'duration_ms': aiDurationMs,
          'text_length': text.length,
        },
      );

      if (aiResponse == null) {
        _showError('Erreur lors du traitement par l\'IA');
        setState(() => _isProcessing = false);
        return;
      }

      setState(() {
        _processingStep = 'Sauvegarde de la recette...';
      });

      // Étape 3: Créer la recette
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

      setState(() => _isProcessing = false);

      if (success && mounted) {
        _showSuccess();
        context.go('/home');
      } else {
        _showError('Erreur lors de la sauvegarde');
      }
    } catch (e) {
      _showError('Une erreur est survenue');
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recette ajoutée avec succès !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scanner une recette',
          style: context.textStyles.titleLarge?.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Comment ça marche ?',
                        style: context.textStyles.titleMedium?.bold.withColor(
                          Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '1. Prenez une photo claire de la recette\n'
                    '2. Le texte sera extrait automatiquement\n'
                    '3. L\'IA structurera la recette\n'
                    '4. Vérifiez et modifiez si nécessaire',
                    style: context.textStyles.bodyMedium?.withColor(
                      Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Boutons de sélection
            FilledButton.icon(
              onPressed:
                  _isProcessing ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Prendre une photo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            OutlinedButton.icon(
              onPressed:
                  _isProcessing ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choisir depuis la galerie'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),

            // Prévisualisation de l'image
            if (_imagePath != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: _imageBytes != null
                    ? Image.memory(
                        _imageBytes!,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 300,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Center(
                            child: Icon(Icons.image_outlined, size: 48)),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Bouton de traitement
              FilledButton(
                onPressed: _isProcessing ? null : _processImage,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
                          const SizedBox(width: AppSpacing.md),
                          Text(_processingStep),
                        ],
                      )
                    : const Text('Traiter la recette'),
              ),
            ],

            // Texte extrait (prévisualisation)
            if (_extractedText != null && !_isProcessing) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Texte extrait',
                style: context.textStyles.titleMedium?.bold,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  _extractedText!,
                  style: context.textStyles.bodySmall,
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
