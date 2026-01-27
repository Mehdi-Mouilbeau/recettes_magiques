import 'package:flutter/material.dart';
import 'package:recette_magique/models/recipe_model.dart';

class RecipeDetailController extends ChangeNotifier {
  final Recipe recipe;
  final TextEditingController noteController;

  int _people;

  RecipeDetailController({
    required this.recipe,
  })  : _people = (recipe.servings ?? 4).clamp(1, 24),
        noteController = TextEditingController(text: recipe.note ?? '');

  int get people => _people;

  void incrementPeople() {
    _people = (_people + 1).clamp(1, 24);
    notifyListeners();
  }

  void decrementPeople() {
    _people = (_people - 1).clamp(1, 24);
    notifyListeners();
  }

  String scaleIngredientLine(String line) {
    final basePeople = recipe.servings ?? 4;
    final ratio = _people / (basePeople <= 0 ? 1 : basePeople);
    
    if (ratio == 1) return line;

    final fractionRegex = RegExp(r'(\d+)\s*/\s*(\d+)');
    final numberRegex = RegExp(r'(\d+[\.,]?\d*)');

    final fMatch = fractionRegex.firstMatch(line);
    if (fMatch != null) {
      final num = double.parse(fMatch.group(1)!);
      final den = double.parse(fMatch.group(2)!);
      return line.replaceFirst(
        fMatch.group(0)!,
        _formatNumber((num / den) * ratio),
      );
    }

    final nMatch = numberRegex.firstMatch(line);
    if (nMatch != null) {
      final val = double.tryParse(nMatch.group(1)!.replaceAll(',', '.'));
      if (val != null) {
        return line.replaceFirst(
          nMatch.group(0)!,
          _formatNumber(val * ratio),
        );
      }
    }

    return line;
  }

  String _formatNumber(double v) {
    final half = (v * 2).round() / 2.0;
    if ((half - half.round()).abs() < 0.001) return half.round().toString();
    return half.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }
}