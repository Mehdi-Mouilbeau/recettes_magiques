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

  List<AggregatedIngredient> get aggregatedItems => _service.buildShoppingList(
        recipes: _selected,
        personsByRecipe: _personsByRecipe,
      );

  Future<void> addRecipe(Recipe recipe, int persons) async {
    if (recipe.id == null) return;
    final id = recipe.id!;

    final idx = _selected.indexWhere((r) => r.id == id);
    if (idx == -1) {
      _selected.add(recipe);
    } else {
      _selected[idx] = recipe;
    }

    _personsByRecipe[id] = persons.clamp(1, 24);

    await persist();
    notifyListeners();
  }

  Future<void> removeRecipe(String recipeId) async {
    _selected.removeWhere((r) => r.id == recipeId);
    _personsByRecipe.remove(recipeId);

    await persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _selected.clear();
    _personsByRecipe.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    notifyListeners();
  }

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

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }

    if (decoded is! Map) return;

    final idsRaw = decoded['ids'];
    final personsRaw = decoded['persons'];

    if (idsRaw is! List) return;

    final byId = <String, Recipe>{
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
      for (final entry in personsRaw.entries) {
        final k = entry.key;
        final v = entry.value;

        if (k is! String) continue;

        int? parsed;
        if (v is int) parsed = v;
        if (v is double) parsed = v.round();

        if (parsed != null) {
          _personsByRecipe[k] = parsed.clamp(1, 24);
        }
      }
    }

    notifyListeners();
  }
}
