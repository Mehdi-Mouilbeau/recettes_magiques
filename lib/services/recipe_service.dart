import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:recette_magique/models/recipe_model.dart';

/// Service de gestion des recettes dans Firestore
/// Toutes les opérations CRUD sur les recettes
class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection des recettes
  CollectionReference get _recipesCollection => _firestore.collection('recipes');

  /// Créer une nouvelle recette
  Future<String?> createRecipe(Recipe recipe) async {
    try {
      final docRef = await _recipesCollection.add(recipe.toJson());
      debugPrint('Recette créée: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Erreur création recette: $e');
      return null;
    }
  }

  /// Met à jour uniquement la note d'une recette
  Future<bool> updateNote({required String recipeId, required String? note}) async {
    try {
      await _recipesCollection.doc(recipeId).update({
        'note': note,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour note: $e');
      return false;
    }
  }

  /// Mettre à jour une recette existante
  Future<bool> updateRecipe(Recipe recipe) async {
    try {
      if (recipe.id == null) return false;

      await _recipesCollection.doc(recipe.id).update(
        recipe.copyWith(updatedAt: DateTime.now()).toJson(),
      );
      debugPrint('Recette mise à jour: ${recipe.id}');
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour recette: $e');
      return false;
    }
  }

  /// Supprimer une recette
  Future<bool> deleteRecipe(String recipeId) async {
    try {
      await _recipesCollection.doc(recipeId).delete();
      debugPrint('Recette supprimée: $recipeId');
      return true;
    } catch (e) {
      debugPrint('Erreur suppression recette: $e');
      return false;
    }
  }

  /// Récupérer une recette par ID
  Future<Recipe?> getRecipe(String recipeId) async {
    try {
      final doc = await _recipesCollection.doc(recipeId).get();
      if (doc.exists) {
        return Recipe.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur récupération recette: $e');
      return null;
    }
  }

  /// Stream de toutes les recettes d'un utilisateur
  /// Triées par date de création (plus récentes en premier)
  Stream<List<Recipe>> getUserRecipes(String userId) {
    return _recipesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }

  /// Stream des recettes filtrées par catégorie
  Stream<List<Recipe>> getUserRecipesByCategory(
    String userId,
    RecipeCategory category,
  ) {
    return _recipesCollection
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }

  /// Rechercher des recettes par titre
  Future<List<Recipe>> searchRecipes(String userId, String query) async {
    try {
      // Note: Firestore ne supporte pas la recherche full-text native
      // Cette implémentation est basique. Pour une vraie recherche,
      // utilisez Algolia ou créez un index de recherche
      final snapshot = await _recipesCollection
          .where('userId', isEqualTo: userId)
          .get();

      final recipes = snapshot.docs
          .map((doc) => Recipe.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .where((recipe) =>
              recipe.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return recipes;
    } catch (e) {
      debugPrint('Erreur recherche recettes: $e');
      return [];
    }
  }

  /// Met à jour le statut favori d'une recette (pour son propriétaire)
  Future<bool> setFavorite({required String recipeId, required bool value}) async {
    try {
      await _recipesCollection.doc(recipeId).update({
        'favorite': value,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour favori: $e');
      return false;
    }
  }

  /// Recherche naïve par ingrédients disponibles (filtrage côté client)
  Future<List<Recipe>> searchByIngredients(String userId, List<String> rawIngredients) async {
    try {
      final snapshot = await _recipesCollection.where('userId', isEqualTo: userId).get();
      final all = snapshot.docs
          .map((doc) => Recipe.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final tokens = _normalizeList(rawIngredients);
      if (tokens.isEmpty) return all;

      List<MapEntry<Recipe, int>> scored = [];
      for (final r in all) {
        final joined = r.ingredients.map((e) => _normalize(e)).join(' \n ');
        int score = 0;
        for (final t in tokens) {
          if (t.isEmpty) continue;
          if (joined.contains(t)) score++;
        }
        if (score > 0) scored.add(MapEntry(r, score));
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      return scored.map((e) => e.key).toList();
    } catch (e) {
      debugPrint('Erreur recherche par ingrédients: $e');
      return [];
    }
  }

  static List<String> _normalizeList(List<String> list) =>
      list.map((e) => _normalize(e)).where((e) => e.isNotEmpty).toList();

  /// Normalisation basique: minuscule, accents retirés, espaces compressés
  static String _normalize(String input) {
    final lower = input.toLowerCase().trim();
    final deacc = lower
        .replaceAll(RegExp('[àáâäãå]'), 'a')
        .replaceAll(RegExp('[ç]'), 'c')
        .replaceAll(RegExp('[èéêë]'), 'e')
        .replaceAll(RegExp('[ìíîï]'), 'i')
        .replaceAll(RegExp('[ñ]'), 'n')
        .replaceAll(RegExp('[òóôöõ]'), 'o')
        .replaceAll(RegExp('[ùúûü]'), 'u')
        .replaceAll(RegExp('[ýÿ]'), 'y');
    return deacc.replaceAll(RegExp('\n+'), ' ').replaceAll(RegExp('s+'), ' ');
  }
}
