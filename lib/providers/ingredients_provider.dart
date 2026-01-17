import 'package:flutter/foundation.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/services/recipe_service.dart';

class IngredientsProvider extends ChangeNotifier {
  List<String> _items = <String>[];
  List<Recipe> _suggestions = <Recipe>[];
  bool _isLoadingSuggestions = false;
  String? _suggestionsError;

  List<String> get items => _items;
  List<Recipe> get suggestions => _suggestions;
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  String? get suggestionsError => _suggestionsError;

  void setLocal(List<String> items) {
    _items = items;
    notifyListeners();
  }

  void clearLocal() {
    _items = <String>[];
    _suggestions = <Recipe>[];
    _suggestionsError = null;
    notifyListeners();
  }

  Future<void> fetchSuggestions(String uid) async {
    _isLoadingSuggestions = true;
    _suggestionsError = null;
    notifyListeners();

    try {
      if (_items.isEmpty) {
        _suggestions = <Recipe>[];
        _isLoadingSuggestions = false;
        notifyListeners();
        return;
      }

      final service = RecipeService();
      final list = await service.searchByIngredients(uid, _items);
      _suggestions = list;
      _isLoadingSuggestions = false;
      notifyListeners();
    } catch (e) {
      debugPrint('IngredientsProvider.fetchSuggestions error: $e');
      _suggestionsError = 'Impossible de charger les recettes suggérées';
      _isLoadingSuggestions = false;
      notifyListeners();
    }
  }
}
