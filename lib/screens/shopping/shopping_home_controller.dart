import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recette_magique/services/shopping_list_service.dart';

class ShoppingHomeController extends ChangeNotifier {
  final Set<int> _checkedItems = {};

  Set<int> get checkedItems => _checkedItems;

  void toggleItem(int index, bool? isChecked) {
    if (isChecked == true) {
      _checkedItems.add(index);
    } else {
      _checkedItems.remove(index);
    }
    notifyListeners();
  }

  bool isItemChecked(int index) => _checkedItems.contains(index);

  String formatItem(AggregatedIngredient ingredient) {
    if (ingredient.totalAmount != null && ingredient.unit != null) {
      final amount = ingredient.totalAmount!;
      final unit = ingredient.unit!;
      return '${_prettyNumber(amount)} $unit — ${ingredient.name}';
    }
    if (ingredient.occurrences > 1) {
      return '${ingredient.occurrences} × ${ingredient.name}';
    }
    return ingredient.name;
  }

  String _prettyNumber(double number) {
    if (number == number.roundToDouble()) {
      return number.toStringAsFixed(0);
    }
    if (number < 10) {
      return number.toStringAsFixed(1);
    }
    return number.toStringAsFixed(0);
  }

  Future<void> copyShoppingList(List<AggregatedIngredient> items) async {
    final buffer = StringBuffer()..writeln('Liste de courses');
    
    for (final item in items) {
      buffer.writeln('• ${formatItem(item)}');
    }
    
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  void reset() {
    _checkedItems.clear();
    notifyListeners();
  }
}