import 'package:flutter/material.dart';
import 'dart:async';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/services/recipe_service.dart';
import 'package:recette_magique/services/storage_service.dart';
import 'package:recette_magique/services/backend_config.dart';

/// Provider pour gérer l'état des recettes
class RecipeProvider extends ChangeNotifier {
  final RecipeService _recipeService = RecipeService();
  final StorageService _storageService = StorageService();

  List<Recipe> _recipes = [];
  RecipeCategory? _selectedCategory;
  bool _isLoading = false;
  String? _errorMessage;
  bool _favoritesOnly = false;
  StreamSubscription<List<Recipe>>? _recipesSub;

  List<Recipe> get recipes => _recipes;
  RecipeCategory? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get favoritesOnly => _favoritesOnly;

  /// Récupérer les recettes filtrées
  List<Recipe> get filteredRecipes {
    Iterable<Recipe> list = _recipes;
    if (_selectedCategory != null) {
      list = list.where((r) => r.category == _selectedCategory);
    }
    if (_favoritesOnly) {
      list = list.where((r) => r.isFavorite);
    }
    return list.toList();
  }

  /// Charger les recettes de l'utilisateur
  void loadUserRecipes(String userId) {
    if (!BackendConfig.firebaseReady) {
      _recipes = [];
      notifyListeners();
      return;
    }
    _recipesSub?.cancel();
    _recipesSub = _recipeService.getUserRecipes(userId).listen(
      (recipes) {
        _recipes = recipes;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        // Souvent dû à un index composite manquant
        _errorMessage = "Impossible de charger les recettes. Vérifiez l'index Firestore (userId + createdAt).";
        notifyListeners();
      },
    );
  }

  /// Filtrer par catégorie
  void filterByCategory(RecipeCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Afficher uniquement les favoris
  void setFavoritesOnly(bool value) {
    _favoritesOnly = value;
    notifyListeners();
  }

  /// Créer une nouvelle recette
  Future<bool> createRecipe(Recipe recipe, String? imagePath) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage = 'Backend non configuré. Connectez Firebase via le panneau Dreamflow.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Créer la recette pour obtenir l'ID
      final recipeId = await _recipeService.createRecipe(recipe);
      if (recipeId == null) {
        _errorMessage = 'Erreur lors de la création';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Uploader l'image si présente
      if (imagePath != null) {
        final imageUrl = await _storageService.uploadRecipeImage(
          imagePath: imagePath,
          userId: recipe.userId,
          recipeId: recipeId,
        );

        // Mettre à jour la recette avec l'URL de l'image
        if (imageUrl != null) {
          final updatedRecipe = recipe.copyWith(
            id: recipeId,
            scannedImageUrl: imageUrl,
          );
          await _recipeService.updateRecipe(updatedRecipe);
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mettre à jour une recette
  Future<bool> updateRecipe(Recipe recipe) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage = 'Backend non configuré. Connectez Firebase via le panneau Dreamflow.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _recipeService.updateRecipe(recipe);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Supprimer une recette
  Future<bool> deleteRecipe(Recipe recipe) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage = 'Backend non configuré. Connectez Firebase via le panneau Dreamflow.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Supprimer les images
      if (recipe.id != null) {
        await _storageService.deleteRecipeImages(recipe.userId, recipe.id!);
      }

      // Supprimer la recette
      final success = await _recipeService.deleteRecipe(recipe.id!);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

   /// Basculer favori pour une recette
  Future<void> toggleFavorite(Recipe recipe) async {
    if (!BackendConfig.firebaseReady || recipe.id == null) return;
    final newValue = !recipe.isFavorite;
    final success = await _recipeService.setFavorite(recipeId: recipe.id!, value: newValue);
    if (success) {
      // Mettre à jour localement pour un retour instantané
      final idx = _recipes.indexWhere((r) => r.id == recipe.id);
      if (idx != -1) {
        _recipes[idx] = _recipes[idx].copyWith(isFavorite: newValue);
        notifyListeners();
      }
    }
  }

  /// Rechercher des recettes
  Future<void> searchRecipes(String userId, String query) async {
    if (query.isEmpty) {
      loadUserRecipes(userId);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _recipes = await _recipeService.searchRecipes(userId, query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur lors de la recherche';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Réinitialiser le message d'erreur
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _recipesSub?.cancel();
    super.dispose();
  }
}
