import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/providers/shopping_profider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/recipe_provider.dart';

enum MealType { lunch, dinner }

class PlannedMeal {
  final Recipe recipe;
  final int persons;

  const PlannedMeal({required this.recipe, required this.persons});
}

class AgendaController {
  AgendaController({required this.notify});

  final VoidCallback notify;

  static const _storageKey = 'agenda_plans_v2';

  DateTime _weekStart = DateTime.now();

  final Map<DateTime, Map<MealType, PlannedMeal>> _plans = {};

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _mondayOf(DateTime d) {
    final k = _dayKey(d);
    return k.subtract(Duration(days: k.weekday - DateTime.monday));
  }

  List<DateTime> get weekDays =>
      List.generate(7, (i) => _dayKey(_weekStart.add(Duration(days: i))));

  Future<void> init(BuildContext context) async {
    _weekStart = _mondayOf(DateTime.now());
    await _load(context);
    notify();
  }

  void prevWeek() {
    _weekStart = _dayKey(_weekStart.subtract(const Duration(days: 7)));
    notify();
  }

  void nextWeek() {
    _weekStart = _dayKey(_weekStart.add(const Duration(days: 7)));
    notify();
  }

  void goToCurrentWeek() {
    _weekStart = _mondayOf(DateTime.now());
    notify();
  }

  PlannedMeal? mealFor(DateTime day, MealType type) {
    final k = _dayKey(day);
    return _plans[k]?[type];
  }

  Future<void> setMeal(
    BuildContext context, {
    required DateTime day,
    required MealType type,
    required Recipe recipe,
    required int persons,
  }) async {
    if (recipe.id == null) return;

    final k = _dayKey(day);
    final map = {...(_plans[k] ?? <MealType, PlannedMeal>{})};

    map[type] = PlannedMeal(recipe: recipe, persons: persons.clamp(1, 24));
    _plans[k] = map;

    notify();
    await _save();
  }

  Future<void> removeMeal(DateTime day, MealType type) async {
    final k = _dayKey(day);
    final map = {...(_plans[k] ?? <MealType, PlannedMeal>{})};

    map.remove(type);
    if (map.isEmpty) {
      _plans.remove(k);
    } else {
      _plans[k] = map;
    }

    notify();
    await _save();
  }

  bool get canExport {
    for (final entry in _plans.entries) {
      for (final m in entry.value.values) {
        if (m.recipe.id != null) return true;
      }
    }
    return false;
  }

  Future<void> exportToCourses(BuildContext context) async {
    final shopping = context.read<ShoppingProvider>();
    shopping.clear();

    final Map<String, Recipe> byId = {};
    final Map<String, int> personsByRecipe = {};

    for (final entry in _plans.entries) {
      for (final m in entry.value.values) {
        final id = m.recipe.id;
        if (id == null) continue;
        byId[id] = m.recipe;
        personsByRecipe[id] = (personsByRecipe[id] ?? 0) + m.persons.clamp(1, 24);
      }
    }

    for (final e in personsByRecipe.entries) {
      final recipe = byId[e.key];
      if (recipe != null) shopping.addRecipe(recipe, e.value);
    }

    await shopping.persist();
    notify();
  }

  List<Recipe> allRecipes(BuildContext context) {
    return context.read<RecipeProvider>().recipes;
  }

  String weekRangeLabel() {
    final start = _weekStart;
    final end = _dayKey(_weekStart.add(const Duration(days: 6)));

    final m1 = _monthFr(start.month);
    final m2 = _monthFr(end.month);

    if (start.month == end.month) {
      return 'Semaine du ${start.day} au ${end.day} $m1';
    }
    return 'Semaine du ${start.day} $m1 au ${end.day} $m2';
  }

  String dayNameFr(DateTime d) {
    const names = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return names[(d.weekday - 1) % 7];
  }

  String dayShortDateFr(DateTime d) {
    final m = _monthShortFr(d.month);
    return '${d.day} $m';
  }

  String _monthFr(int m) {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  String _monthShortFr(int m) {
    const months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    final data = <String, dynamic>{};

    for (final entry in _plans.entries) {
      final day = entry.key;
      final iso = _iso(day);

      final lunch = entry.value[MealType.lunch];
      final dinner = entry.value[MealType.dinner];

      data[iso] = {
        'lunch': lunch == null
            ? null
            : {
                'recipeId': lunch.recipe.id,
                'persons': lunch.persons,
              },
        'dinner': dinner == null
            ? null
            : {
                'recipeId': dinner.recipe.id,
                'persons': dinner.persons,
              },
      };
    }

    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> _load(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;

    final recipes = context.read<RecipeProvider>().recipes;
    final Map<String, Recipe> byId = {
      for (final r in recipes)
        if (r.id != null) r.id!: r,
    };

    _plans.clear();

    for (final entry in decoded.entries) {
      final dayIso = entry.key;
      final val = entry.value;

      final day = _parseIso(dayIso);
      if (day == null) continue;
      if (val is! Map) continue;

      final lunchRaw = val['lunch'];
      final dinnerRaw = val['dinner'];

      final map = <MealType, PlannedMeal>{};

      if (lunchRaw is Map) {
        final id = lunchRaw['recipeId'];
        final persons = lunchRaw['persons'];
        if (id is String && byId[id] != null) {
          map[MealType.lunch] = PlannedMeal(
            recipe: byId[id]!,
            persons: (persons is int ? persons : 4).clamp(1, 24),
          );
        }
      }

      if (dinnerRaw is Map) {
        final id = dinnerRaw['recipeId'];
        final persons = dinnerRaw['persons'];
        if (id is String && byId[id] != null) {
          map[MealType.dinner] = PlannedMeal(
            recipe: byId[id]!,
            persons: (persons is int ? persons : 4).clamp(1, 24),
          );
        }
      }

      if (map.isNotEmpty) {
        _plans[_dayKey(day)] = map;
      }
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseIso(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
