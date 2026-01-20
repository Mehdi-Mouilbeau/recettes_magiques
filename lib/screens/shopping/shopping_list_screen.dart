import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/services/shopping_list_service.dart';
import 'package:recette_magique/theme.dart';

class ShoppingListArgs {
  final List<Recipe> recipes;
  final Map<String, int> personsByRecipe;
  ShoppingListArgs({required this.recipes, required this.personsByRecipe});
}

class ShoppingListScreen extends StatefulWidget {
  final ShoppingListArgs args;
  const ShoppingListScreen({super.key, required this.args});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late final List<AggregatedIngredient> items;
  final service = ShoppingListService();
  final Set<int> checked = {};

  @override
  void initState() {
    super.initState();
    items = service.buildShoppingList(
      recipes: widget.args.recipes,
      personsByRecipe: widget.args.personsByRecipe,
    );
  }

  String _formatItem(AggregatedIngredient i) {
    if (i.totalAmount != null && i.unit != null) {
      final n = i.totalAmount!;
      final u = i.unit!;

      if (u == 'pcs') {
        final v = n.ceil();
        return '$v ${i.name}';
      }

      return '${_prettyNumber(n)} $u ${i.name}';
    }

    if (i.occurrences > 1) {
      return '${i.occurrences} × ${i.name}';
    }

    return i.name;
  }

  String _prettyNumber(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    if (n < 10) return n.toStringAsFixed(1);
    return n.toStringAsFixed(0);
  }

  Future<void> _copyToClipboard() async {
    final buffer = StringBuffer();
    buffer.writeln('Liste de courses');
    for (final i in items) {
      buffer.writeln('• ${_formatItem(i)}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Liste copiée dans le presse-papiers'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Liste de courses', style: context.textStyles.titleLarge?.bold),
        actions: [
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy, color: Colors.blue),
            onPressed: _copyToClipboard,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${widget.args.recipes.length} recette${widget.args.recipes.length > 1 ? 's' : ''}',
                  style: context.textStyles.bodyLarge,
                ),
                const Spacer(),
                Text(
                  '${items.length} articles',
                  style: context.textStyles.labelLarge?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: AppSpacing.paddingMd,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final i = items[index];
                final isChecked = checked.contains(index);
                return _ShoppingItemTile(
                  label: _formatItem(i),
                  checked: isChecked,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      checked.add(index);
                    } else {
                      checked.remove(index);
                    }
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool?> onChanged;
  const _ShoppingItemTile({required this.label, required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: CheckboxListTile(
        value: checked,
        onChanged: onChanged,
        checkboxShape: const CircleBorder(),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          label,
          style: checked
              ? context.textStyles.bodyLarge
                  ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)
                  .copyWith(decoration: TextDecoration.lineThrough)
              : context.textStyles.bodyLarge,
        ),
      ),
    );
  }
}
