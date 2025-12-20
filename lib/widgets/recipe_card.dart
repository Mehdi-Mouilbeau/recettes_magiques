import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/theme.dart';

/// Carte de recette pour la liste
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  Color _getCategoryColor() {
    switch (recipe.category) {
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
    final categoryColor = _getCategoryColor();

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───────────────── IMAGE ─────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: (recipe.imageUrl ?? recipe.scannedImageUrl) != null
                      ? CachedNetworkImage(
                          imageUrl:
                              (recipe.imageUrl ?? recipe.scannedImageUrl)!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 80,
                            height: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.restaurant_menu),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: categoryColor.withValues(alpha: 0.2),
                          alignment: Alignment.center,
                          child: Text(
                            recipe.category.displayName[0],
                            style: context.textStyles.headlineMedium?.bold
                                .withColor(categoryColor),
                          ),
                        ),
                ),

                const SizedBox(width: AppSpacing.md),

                // ───────────────── TEXTE ─────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre
                      Text(
                        recipe.title,
                        style: context.textStyles.titleMedium?.bold,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Ligne 1 : catégorie (chip)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          recipe.category.displayName,
                          style: context.textStyles.labelSmall
                              ?.withColor(categoryColor),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Ligne 2 : durée
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              recipe.estimatedTime,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyles.labelSmall?.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Ingrédients
                      Text(
                        '${recipe.ingredients.length} ingrédients',
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // ───────────────── ACTIONS ─────────────────
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: recipe.isFavorite
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris',
                      onPressed: () =>
                          context.read<RecipeProvider>().toggleFavorite(recipe),
                      icon: Icon(
                        recipe.isFavorite ? Icons.star : Icons.star_outline,
                        color: recipe.isFavorite
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
