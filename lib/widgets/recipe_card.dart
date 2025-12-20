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
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              // Image de la recette
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: recipe.scannedImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: recipe.scannedImageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 80,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 80,
                          height: 80,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.restaurant_menu),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: _getCategoryColor().withValues(alpha: 0.2),
                        child: Center(
                          child: Text(
                            recipe.category.displayName[0],
                            style: context.textStyles.headlineMedium?.bold.withColor(
                              _getCategoryColor(),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: context.textStyles.titleMedium?.bold,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor().withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            recipe.category.displayName,
                            style: context.textStyles.labelSmall?.withColor(
                              _getCategoryColor(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recipe.estimatedTime,
                          style: context.textStyles.labelSmall?.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${recipe.ingredients.length} ingrédients',
                      style: context.textStyles.bodySmall?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: recipe.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                    onPressed: () => context.read<RecipeProvider>().toggleFavorite(recipe),
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
    );
  }
}
