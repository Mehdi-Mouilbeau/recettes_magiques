import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/theme.dart';

/// Widget de filtrage par catégorie
class CategoryFilter extends StatelessWidget {
  const CategoryFilter({super.key});

  Color _getCategoryColor(RecipeCategory category) {
    switch (category) {
      case RecipeCategory.entree:
        return Colors.green;
      case RecipeCategory.plat:
        return Colors.orange;
      case RecipeCategory.dessert:
        return Colors.pink;
      case RecipeCategory.boisson:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final selectedCategory = recipeProvider.selectedCategory;

    return Container(
      padding: AppSpacing.verticalMd,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.horizontalMd,
        child: Row(
          children: [
            // Bouton "Toutes"
            _FilterChip(
              label: 'Toutes',
              isSelected: selectedCategory == null,
              onTap: () => recipeProvider.filterByCategory(null),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Boutons des catégories
            ...RecipeCategory.values.map((category) {
              final color = _getCategoryColor(category);
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _FilterChip(
                  label: category.displayName,
                  isSelected: selectedCategory == category,
                  color: color,
                  onTap: () => recipeProvider.filterByCategory(category),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? displayColor
              : displayColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          label,
          style: context.textStyles.labelMedium?.semiBold.withColor(
            isSelected
                ? Colors.white
                : displayColor,
          ),
        ),
      ),
    );
  }
}
