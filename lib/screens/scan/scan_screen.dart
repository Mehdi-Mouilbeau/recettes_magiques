import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/screens/scan/scan_controller.dart';
import 'package:recette_magique/theme.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  void _showError(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Recette ajoutée avec succès !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handlePickImage(
    BuildContext context,
    ImageSource source,
    ScanController controller,
  ) async {
    try {
      await controller.pickImage(source);
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur lors de la sélection de l\'image');
      }
    }
  }

  Future<void> _handleProcessImage(BuildContext context) async {
    final controller = context.read<ScanController>();
    final authProvider = context.read<AuthProvider>();
    final recipeProvider = context.read<RecipeProvider>();

    try {
      final recipe = await controller.processImage(
        userId: authProvider.currentUser!.uid,
      );

      if (!context.mounted) return;

      if (recipe == null) {
        _showError(context, 'Erreur lors du traitement');
        return;
      }

      final success = await recipeProvider.createRecipe(
        recipe,
        controller.imagePath,
      );

      if (!context.mounted) return;

      if (success) {
        _showSuccess(context);
        context.go('/home');
      } else {
        _showError(context, 'Erreur lors de la sauvegarde');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ChangeNotifierProvider(
      create: (_) => ScanController(),
      child: Consumer<ScanController>(
        builder: (context, controller, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: AppColors.bgGradient,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 24,
                      bottom: 24,
                      left: 16,
                      right: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryHeader,
                    ),
                    child: Column(
                      children: [
                        Text('Scan ta recette',
                            style: AppTextStyles.sheetTitle()),
                        Text(
                            'Transforme ta recette papier en recette numérique',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            )),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: _ScanBody(
                      imagePath: controller.imagePath,
                      imageBytes: controller.imageBytes,
                      extractedText: controller.extractedText,
                      isProcessing: controller.isProcessing,
                      processingStep: controller.processingStep,
                      onPickCamera: () => _handlePickImage(
                        context,
                        ImageSource.camera,
                        controller,
                      ),
                      onPickGallery: () => _handlePickImage(
                        context,
                        ImageSource.gallery,
                        controller,
                      ),
                      onProcess: () => _handleProcessImage(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 90 + bottomInset),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScanBody extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? extractedText;
  final bool isProcessing;
  final String processingStep;

  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onProcess;

  const _ScanBody({
    required this.imagePath,
    required this.imageBytes,
    required this.extractedText,
    required this.isProcessing,
    required this.processingStep,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onProcess,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryHeader,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text(
                    'Comment ça marche ?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: const Text(
                      '1. Prenez une photo claire de la recette\n\n'
                      '2. Le texte sera extrait par l\'IA qui structurera la recette\n\n'
                      '4. Vérifiez et modifiez si nécessaire',
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Image.asset(
                    'assets/icons/mascotte_scan.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isProcessing ? null : onPickCamera,
          icon: const Icon(Icons.camera_alt_outlined,color: Colors.black),
          label: const Text('Prendre une photo',
              style: TextStyle(color: Colors.black)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryHeader,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: isProcessing ? null : onPickGallery,
          icon: const Icon(Icons.photo_library_outlined, color: Colors.black),
          label: const Text(
            'Choisir depuis la galerie',
            style: TextStyle(color: Colors.black),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.control,
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryHeader,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Astuce : Afin de garantir un résultat correct, assure toi que le texte est bien lisible et que l\'éclairage est uniforme.',
            textAlign: TextAlign.left,
          ),
        ),
        if (imagePath != null) ...[
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageBytes != null
                ? Image.memory(
                    imageBytes!,
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
            onPressed: isProcessing ? null : onProcess,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.control,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isProcessing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 16),
                      Flexible(child: Text(processingStep)),
                    ],
                  )
                : const Text('Traiter la recette',
                    style: TextStyle(color: Colors.black)),
          ),
        ],
      ],
    );
  }
}
