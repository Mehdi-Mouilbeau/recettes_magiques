import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:recette_magique/models/recipe_model.dart';

class AgendaProvider extends ChangeNotifier {
  final Map<DateTime, List<Recipe>> _plan = {};
  final Random _rng = Random();

  Map<DateTime, List<Recipe>> get plan => _plan;

  DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Recipe> itemsFor(DateTime day) {
    final k = dayKey(day);
    return _plan[k] ?? <Recipe>[];
  }

  void add(DateTime day, Recipe recipe) {
    final k = dayKey(day);
    final list = [...(_plan[k] ?? <Recipe>[])];
    list.add(recipe);
    _plan[k] = list;
    notifyListeners();
  }

  void remove(DateTime day, int index) {
    final k = dayKey(day);
    final list = [...(_plan[k] ?? <Recipe>[])];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) {
      _plan.remove(k);
    } else {
      _plan[k] = list;
    }
    notifyListeners();
  }

  void reorderWithinDay(DateTime day, int oldIndex, int newIndex) {
    final k = dayKey(day);
    final list = [...(_plan[k] ?? <Recipe>[])];
    if (oldIndex < 0 || oldIndex >= list.length) return;

    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= list.length) newIndex = list.length - 1;

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    _plan[k] = list;
    notifyListeners();
  }

  void moveToDay({
    required DateTime fromDay,
    required int fromIndex,
    required DateTime toDay,
    int? toIndex,
  }) {
    final fromK = dayKey(fromDay);
    final toK = dayKey(toDay);

    final fromList = [...(_plan[fromK] ?? <Recipe>[])];
    if (fromIndex < 0 || fromIndex >= fromList.length) return;

    final item = fromList.removeAt(fromIndex);

    if (fromList.isEmpty) {
      _plan.remove(fromK);
    } else {
      _plan[fromK] = fromList;
    }

    final toList = [...(_plan[toK] ?? <Recipe>[])];
    final insertAt = (toIndex == null)
        ? toList.length
        : toIndex.clamp(0, toList.length);
    toList.insert(insertAt, item);

    _plan[toK] = toList;
    notifyListeners();
  }

  void clearDay(DateTime day) {
    final k = dayKey(day);
    _plan.remove(k);
    notifyListeners();
  }

  void clearAll() {
    _plan.clear();
    notifyListeners();
  }

  void generateWeek({
    required List<Recipe> source,
    required DateTime startDay,
    int days = 7,
    bool favoritesOnly = false,
    RecipeCategory? category,
    int recipesPerDay = 1,
  }) {
    final start = dayKey(startDay);

    var pool = source;
    if (favoritesOnly) pool = pool.where((r) => r.isFavorite).toList();
    if (category != null) pool = pool.where((r) => r.category == category).toList();

    if (pool.isEmpty) return;

    for (int i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final k = dayKey(day);

      final generated = <Recipe>[];
      final usedIds = <String>{};

      for (int j = 0; j < recipesPerDay; j++) {
        final tries = min(pool.length, 20);
        Recipe picked = pool[_rng.nextInt(pool.length)];

        for (int t = 0; t < tries; t++) {
          final candidate = pool[_rng.nextInt(pool.length)];
          final id = candidate.id ?? '${candidate.title}_${candidate.hashCode}';
          if (!usedIds.contains(id)) {
            picked = candidate;
            break;
          }
        }

        final pid = picked.id ?? '${picked.title}_${picked.hashCode}';
        usedIds.add(pid);
        generated.add(picked);
      }

      _plan[k] = generated;
    }

    notifyListeners();
  }
}
