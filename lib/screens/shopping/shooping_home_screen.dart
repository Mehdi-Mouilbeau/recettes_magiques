import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/providers/shopping_profider.dart';
import 'package:flutter/services.dart';
import 'package:recette_magique/services/shopping_list_service.dart';
import 'package:recette_magique/theme.dart';

class ShoppingHomeScreen extends StatefulWidget {
  const ShoppingHomeScreen({super.key});

  @override
  State<ShoppingHomeScreen> createState() => _ShoppingHomeScreenState();
}

class _ShoppingHomeScreenState extends State<ShoppingHomeScreen> {
  final Set<int> _checked = {};

  String _formatItem(AggregatedIngredient i) {
    if (i.totalAmount != null && i.unit != null) {
      final n = i.totalAmount!;
      final u = i.unit!;
      return '${_prettyNumber(n)} $u — ${i.name}';
    }
    if (i.occurrences > 1) return '${i.occurrences} × ${i.name}';
    return i.name;
  }

  String _prettyNumber(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    if (n < 10) return n.toStringAsFixed(1);
    return n.toStringAsFixed(0);
  }

  Future<void> _copy(List<AggregatedIngredient> items) async {
    final buffer = StringBuffer()
      ..writeln('Liste de courses');
    for (final i in items) {
      buffer.writeln('• ${_formatItem(i)}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liste copiée')));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ShoppingProvider>();
    final items = prov.aggregatedItems;
    final hasSelection = prov.selectedRecipes.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Courses', style: context.textStyles.titleLarge?.bold),
        actions: [
          if (hasSelection)
            IconButton(
              tooltip: 'Copier',
              onPressed: () => _copy(items),
              icon: const Icon(Icons.copy, color: Colors.blue),
            ),
          if (hasSelection)
            IconButton(
              tooltip: 'Vider',
              onPressed: () => prov.clear(),
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
            ),
        ],
      ),
      body: hasSelection
          ? Column(
              children: [
                Padding(
                  padding: AppSpacing.paddingMd,
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text('${prov.selectedRecipes.length} recette${prov.selectedRecipes.length > 1 ? 's' : ''}', style: context.textStyles.bodyLarge),
                      const Spacer(),
                      Text('${items.length} articles', style: context.textStyles.labelLarge?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
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
                      final isChecked = _checked.contains(index);
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: CheckboxListTile(
                          value: isChecked,
                          onChanged: (v) => setState(() => v == true ? _checked.add(index) : _checked.remove(index)),
                          checkboxShape: const CircleBorder(),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            _formatItem(i),
                            style: isChecked
                                ? context.textStyles.bodyLarge?.withColor(Theme.of(context).colorScheme.onSurfaceVariant).copyWith(decoration: TextDecoration.lineThrough)
                                : context.textStyles.bodyLarge,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          : Center(
              child: Padding(
                padding: AppSpacing.paddingXl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🛒', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Ajoutez des recettes à la liste', style: context.textStyles.headlineSmall?.bold, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Depuis une fiche recette, choisissez le nombre de personnes puis touchez « Liste ».',
                        style: context.textStyles.bodyLarge?.withColor(Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
    );
  }
}
