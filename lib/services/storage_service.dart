import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service de stockage Firebase Storage
/// Gère l'upload des images de recettes
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload une image de recette et retourne l'URL de téléchargement
  /// Le chemin sera: recipes/{userId}/{recipeId}/{filename}
  Future<String?> uploadRecipeImage({
    required String imagePath,
    required String userId,
    required String recipeId,
  }) async {
    try {
      // Sur le Web, l'accès direct au système de fichiers n'est pas supporté
      // et image_picker retourne un blob URL. On saute l'upload pour éviter un crash.
      if (kIsWeb) {
        debugPrint('Web: upload d\'image ignoré (non supporté via File).');
        return null;
      }
      final file = File(imagePath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'recipes/$userId/$recipeId/$fileName';

      debugPrint('Upload image: $path');

      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(file);

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Image uploadée: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('Erreur upload image: $e');
      return null;
    }
  }

  /// Supprime une image de recette depuis son URL
  Future<void> deleteRecipeImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      debugPrint('Image supprimée: $imageUrl');
    } catch (e) {
      debugPrint('Erreur suppression image: $e');
    }
  }

  /// Upload image bytes (e.g., AI-generated) and return download URL
  Future<String?> uploadRecipeImageBytes({
    required Uint8List bytes,
    required String userId,
    required String recipeId,
    String fileName = 'ai.png',
    String contentType = 'image/png',
  }) async {
    try {
      final path = 'recipes/$userId/$recipeId/$fileName';
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(bytes, metadata);
      final url = await uploadTask.ref.getDownloadURL();
      debugPrint('AI image uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('Erreur upload image bytes: $e');
      return null;
    }
  }

  /// Supprime toutes les images d'une recette
  Future<void> deleteRecipeImages(String userId, String recipeId) async {
    try {
      final path = 'recipes/$userId/$recipeId';
      final ref = _storage.ref().child(path);
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        await item.delete();
      }

      debugPrint('Images supprimées pour recette: $recipeId');
    } catch (e) {
      debugPrint('Erreur suppression images recette: $e');
    }
  }
}
