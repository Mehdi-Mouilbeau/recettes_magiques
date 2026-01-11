import 'package:flutter/material.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/services/shopping_list_service.dart';

/// Provider that accumulates selected recipes for the shopping list.
class ShoppingProvider extends ChangeNotifier {
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
      _selected[idx] = recipe; // refresh reference if updated
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

  /// Aggregated items computed from current selection.
  List<AggregatedIngredient> get aggregatedItems => _service.buildShoppingList(
        recipes: _selected,
        personsByRecipe: _personsByRecipe,
      );
}
