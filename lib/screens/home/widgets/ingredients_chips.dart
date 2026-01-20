// lib/screens/home/widgets/ingredients_chips.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:recette_magique/providers/ingredients_provider.dart';

class IngredientsChips extends StatelessWidget {
  const IngredientsChips({
    super.key,
    required this.onDelete,
  });

  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<IngredientsProvider>().items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final it in items)
            Chip(
              label: Text(it),
              onDeleted: () => onDelete(it),
            ),
        ],
      ),
    );
  }
}
