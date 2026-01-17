import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/providers/shopping_profider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/recipe_provider.dart';

enum MealType { lunch, dinner, dessert, snack, other }

class PlannedMeal {
  final Recipe recipe;
  final int persons;
  final MealType type;
  final String? customLabel;

  const PlannedMeal({
    required this.recipe,
    required this.persons,
    required this.type,
    this.customLabel,
  });

  String get label {
    final c = customLabel?.trim();
    if (c != null && c.isNotEmpty) return c;
    switch (type) {
      case MealType.lunch:
        return 'Déjeuner';
      case MealType.dinner:
        return 'Dîner';
      case MealType.dessert:
        return 'Dessert';
      case MealType.snack:
        return 'Goûter';
      case MealType.other:
        return 'Repas';
    }
  }
}

class RecipePickResult {
  final Recipe recipe;
  final int persons;
  final MealType type;
  final String? customLabel;

  const RecipePickResult({
    required this.recipe,
    required this.persons,
    required this.type,
    this.customLabel,
  });
}

class AgendaController {
  AgendaController({required this.notify});

  final VoidCallback notify;

  static const _storageKey = 'agenda_plans_v1';

  DateTime _weekStart = DateTime.now();
  final Map<DateTime, List<PlannedMeal>> _plans = {};

  DateTime get weekStart => _weekStart;

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

  List<PlannedMeal> mealsFor(DateTime day) {
    final k = _dayKey(day);
    return _plans[k] ?? <PlannedMeal>[];
  }

  Future<void> addMeal(BuildContext context, DateTime day, PlannedMeal meal) async {
    final k = _dayKey(day);
    final list = [...(_plans[k] ?? <PlannedMeal>[])];
    list.add(meal);
    _plans[k] = list;
    notify();
    await _save();
  }

  Future<void> removeMeal(DateTime day, int index) async {
    final k = _dayKey(day);
    final list = [...(_plans[k] ?? <PlannedMeal>[])];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) {
      _plans.remove(k);
    } else {
      _plans[k] = list;
    }
    notify();
    await _save();
  }

  Future<void> clearDay(DateTime day) async {
    _plans.remove(_dayKey(day));
    notify();
    await _save();
  }

  Future<void> clearAll() async {
    _plans.clear();
    notify();
    await _save();
  }

  List<Recipe> allRecipes(BuildContext context) {
    return context.read<RecipeProvider>().recipes;
  }

  bool get canExport {
    for (final entry in _plans.entries) {
      for (final m in entry.value) {
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
      for (final m in entry.value) {
        final id = m.recipe.id;
        if (id == null) continue;
        byId[id] = m.recipe;
        personsByRecipe[id] = (personsByRecipe[id] ?? 0) + m.persons.clamp(1, 24);
      }
    }

    for (final e in personsByRecipe.entries) {
      final recipe = byId[e.key];
      if (recipe != null) {
        shopping.addRecipe(recipe, e.value);
      }
    }

    await shopping.persist();

    notify();
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
      data[iso] = entry.value
          .where((m) => m.recipe.id != null)
          .map((m) => {
                'recipeId': m.recipe.id,
                'persons': m.persons,
                'type': m.type.index,
                'customLabel': m.customLabel,
              })
          .toList();
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
      final listRaw = entry.value;

      final day = _parseIso(dayIso);
      if (day == null) continue;
      if (listRaw is! List) continue;

      final meals = <PlannedMeal>[];

      for (final item in listRaw) {
        if (item is! Map) continue;

        final rid = item['recipeId'];
        if (rid is! String) continue;

        final recipe = byId[rid];
        if (recipe == null) continue;

        final persons = (item['persons'] is int) ? item['persons'] as int : 4;
        final typeIndex = (item['type'] is int) ? item['type'] as int : 0;
        final customLabel = (item['customLabel'] is String) ? item['customLabel'] as String : null;

        final type = MealType.values[(typeIndex).clamp(0, MealType.values.length - 1)];

        meals.add(
          PlannedMeal(
            recipe: recipe,
            persons: persons.clamp(1, 24),
            type: type,
            customLabel: customLabel,
          ),
        );
      }

      if (meals.isNotEmpty) {
        _plans[_dayKey(day)] = meals;
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
