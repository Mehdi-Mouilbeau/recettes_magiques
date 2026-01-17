import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/services/shopping_list_service.dart';

class ShoppingProvider extends ChangeNotifier {
  static const _storageKey = 'shopping_selection_v1';

  final List<Recipe> _selected = <Recipe>[];
  final Map<String, int> _personsByRecipe = <String, int>{};
  final ShoppingListService _service = ShoppingListService();

  List<Recipe> get selectedRecipes => List.unmodifiable(_selected);
  Map<String, int> get personsByRecipe => Map.unmodifiable(_personsByRecipe);

  bool contains(String recipeId) => _selected.any((r) => r.id == recipeId);

  void addRecipe(Recipe recipe, int persons) {
    if (recipe.id == null) return;
    final id = recipe.id!;
    final idx = _selected.indexWhere((r) => r.id == id);
    if (idx == -1) {
      _selected.add(recipe);
    } else {
      _selected[idx] = recipe;
    }
    _personsByRecipe[id] = persons.clamp(1, 24);
    notifyListeners();
  }

  void removeRecipe(String recipeId) {
    _selected.removeWhere((r) => r.id == recipeId);
    _personsByRecipe.remove(recipeId);
    notifyListeners();
  }

  void clear() {
    _selected.clear();
    _personsByRecipe.clear();
    notifyListeners();
  }

  List<AggregatedIngredient> get aggregatedItems => _service.buildShoppingList(
        recipes: _selected,
        personsByRecipe: _personsByRecipe,
      );

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _selected.map((r) => r.id).whereType<String>().toList();
    final data = {
      'ids': ids,
      'persons': _personsByRecipe,
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> hydrateFromStorage(List<Recipe> allRecipes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;

    final idsRaw = decoded['ids'];
    final personsRaw = decoded['persons'];

    if (idsRaw is! List) return;

    final byId = {
      for (final r in allRecipes)
        if (r.id != null) r.id!: r,
    };

    _selected.clear();
    _personsByRecipe.clear();

    for (final id in idsRaw) {
      if (id is! String) continue;
      final r = byId[id];
      if (r != null) _selected.add(r);
    }

    if (personsRaw is Map) {
      for (final e in personsRaw.entries) {
        final k = e.key;
        final v = e.value;
        if (k is String && v is int) {
          _personsByRecipe[k] = v.clamp(1, 24);
        }
      }
    }

    notifyListeners();
  }
}
