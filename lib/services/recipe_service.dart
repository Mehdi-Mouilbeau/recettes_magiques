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
}
