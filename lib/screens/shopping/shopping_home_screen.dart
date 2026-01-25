import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/providers/shopping_profider.dart';
import 'package:recette_magique/services/shopping_list_service.dart';
import 'package:recette_magique/screens/shopping/shopping_home_controller.dart';
import 'package:recette_magique/theme.dart';

class ShoppingHomeScreen extends StatelessWidget {
  const ShoppingHomeScreen({super.key});

  void _showCopySuccess(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liste copiée')),
    );
  }

  Future<void> _handleCopy(
    BuildContext context,
    ShoppingHomeController controller,
    List<AggregatedIngredient> items,
  ) async {
    await controller.copyShoppingList(items);
    if (context.mounted) {
      _showCopySuccess(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.watch<ShoppingProvider>();
    final items = shoppingProvider.aggregatedItems;
    final hasSelection = shoppingProvider.selectedRecipes.isNotEmpty;

    return ChangeNotifierProvider(
      create: (_) => ShoppingHomeController(),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.bgGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
              'Courses',
              style: context.textStyles.titleLarge?.bold,
            ),
          actions: [
            if (hasSelection)
              Consumer<ShoppingHomeController>(
                builder: (context, controller, _) {
                  return IconButton(
                    tooltip: 'Copier',
                    onPressed: () => _handleCopy(context, controller, items),
                    icon: const Icon(Icons.copy, color: Colors.blue),
                  );
                },
              ),
            if (hasSelection)
              IconButton(
                tooltip: 'Vider',
                onPressed: () => shoppingProvider.clear(),
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
              ),
          ],
        ),
        body: hasSelection
            ? _ShoppingListContent(
                shoppingProvider: shoppingProvider,
                items: items,
              )
            : _EmptyShoppingState(),
        ),
      ),
    );
  }
}

class _ShoppingListContent extends StatelessWidget {
  final ShoppingProvider shoppingProvider;
  final List<AggregatedIngredient> items;

  const _ShoppingListContent({
    required this.shoppingProvider,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              Icon(
                Icons.list_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${shoppingProvider.selectedRecipes.length} recette${shoppingProvider.selectedRecipes.length > 1 ? 's' : ''}',
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
          child: Consumer<ShoppingHomeController>(
            builder: (context, controller, _) {
              return ListView.separated(
                padding: AppSpacing.paddingMd,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isChecked = controller.isItemChecked(index);
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: CheckboxListTile(
                      value: isChecked,
                      onChanged: (value) => controller.toggleItem(index, value),
                      checkboxShape: const CircleBorder(),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        controller.formatItem(item),
                        style: isChecked
                            ? context.textStyles.bodyLarge
                                ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)
                                .copyWith(decoration: TextDecoration.lineThrough)
                            : context.textStyles.bodyLarge,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyShoppingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 72)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ajoutez des recettes à la liste',
              style: context.textStyles.headlineSmall?.bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Depuis une fiche recette, choisissez le nombre de personnes puis touchez « Liste ».',
              style: context.textStyles.bodyLarge?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}