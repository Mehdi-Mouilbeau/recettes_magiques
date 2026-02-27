import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/services/recipe_service.dart';
import 'package:recette_magique/services/storage_service.dart';
import 'package:recette_magique/services/backend_config.dart';

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
      onError: (_) {
        _errorMessage =
            "Impossible de charger les recettes. Vérifiez l'index Firestore.";
        notifyListeners();
      },
    );
  }

  void filterByCategory(RecipeCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    _favoritesOnly = value;
    notifyListeners();
  }

  Future<bool> createRecipe(Recipe recipe, String? imagePath) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage = 'Backend non configuré.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final recipeId = await _recipeService.createRecipe(recipe);
      _isLoading = false;
      notifyListeners();
      return recipeId != null;
    } catch (_) {
      _errorMessage = 'Erreur lors de la création';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> regenerateImage(String recipeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken(true);

      final url = Uri.parse(
        'https://europe-west1-recette-magique-7de15.cloudfunctions.net/regenerateRecipeImage',
      );

      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'recipeId': recipeId}),
      );

      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateRecipe(Recipe recipe) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage = 'Backend non configuré.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final updatedRecipe =
          recipe.copyWith(updatedAt: DateTime.now());

      final success = await _recipeService.updateRecipe(updatedRecipe);

      if (success) {
        final idx = _recipes.indexWhere((r) => r.id == recipe.id);
        if (idx != -1) {
          _recipes[idx] = updatedRecipe;
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (_) {
      _errorMessage = 'Erreur lors de la mise à jour';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecipe(Recipe recipe) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage = 'Backend non configuré.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (recipe.id != null) {
        await _storageService.deleteRecipeImages(recipe.userId, recipe.id!);
      }

      final success = await _recipeService.deleteRecipe(recipe.id!);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (_) {
      _errorMessage = 'Erreur lors de la suppression';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateNote(String recipeId, String? note) async {
    if (!BackendConfig.firebaseReady) return false;

    final ok =
        await _recipeService.updateNote(recipeId: recipeId, note: note);

    if (ok) {
      final idx = _recipes.indexWhere((r) => r.id == recipeId);
      if (idx != -1) {
        _recipes[idx] = _recipes[idx]
            .copyWith(note: note, updatedAt: DateTime.now());
        notifyListeners();
      }
    }
    return ok;
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    if (!BackendConfig.firebaseReady || recipe.id == null) return;

    final newValue = !recipe.isFavorite;

    final success = await _recipeService.setFavorite(
      recipeId: recipe.id!,
      value: newValue,
    );

    if (success) {
      final idx = _recipes.indexWhere((r) => r.id == recipe.id);
      if (idx != -1) {
        _recipes[idx] =
            _recipes[idx].copyWith(isFavorite: newValue);
        notifyListeners();
      }
    }
  }

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