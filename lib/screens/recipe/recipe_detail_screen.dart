import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/theme.dart';

/// Écran de détail d'une recette
class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  Future<void> _deleteRecipe(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer cette recette ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final recipeProvider = context.read<RecipeProvider>();
      final success = await recipeProvider.deleteRecipe(recipe);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recette supprimée')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar avec image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: recipe.scannedImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: recipe.scannedImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.restaurant_menu, size: 80),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Center(
                        child: Text(
                          recipe.category.displayName[0],
                          style: context.textStyles.displayLarge?.bold.withColor(
                            Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.paddingXl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et catégorie
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: context.textStyles.headlineMedium?.bold,
                        ),
                      ),
                      _CategoryChip(category: recipe.category),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Informations
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        recipe.estimatedTime,
                        style: context.textStyles.bodyMedium?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Icon(
                        Icons.book_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          recipe.source,
                          style: context.textStyles.bodyMedium?.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Tags
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: recipe.tags.map((tag) => Chip(
                        label: Text(tag, style: context.textStyles.labelSmall),
                        padding: EdgeInsets.zero,
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  // Ingrédients
                  Text(
                    'Ingrédients',
                    style: context.textStyles.titleLarge?.bold,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...recipe.ingredients.map((ingredient) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            ingredient,
                            style: context.textStyles.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: AppSpacing.xl),

                  // Étapes
                  Text(
                    'Préparation',
                    style: context.textStyles.titleLarge?.bold,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...recipe.steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: context.textStyles.labelLarge?.bold.withColor(
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              step,
                              style: context.textStyles.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.xl),

                  // Bouton supprimer
                  OutlinedButton.icon(
                    onPressed: () => _deleteRecipe(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer cette recette'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de chip de catégorie
class _CategoryChip extends StatelessWidget {
  final RecipeCategory category;

  const _CategoryChip({required this.category});

  Color _getCategoryColor(BuildContext context) {
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _getCategoryColor(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        category.displayName,
        style: context.textStyles.labelMedium?.bold.withColor(
          _getCategoryColor(context),
        ),
      ),
    );
  }
}
