// lib/screens/home/widgets/recipes_section.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/ingredients_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/theme.dart';
import 'package:recette_magique/ui/widgets/recipe_grid_card.dart';

import '../home_controller.dart';

class RecipesSection extends StatelessWidget {
  const RecipesSection({
    super.key,
    required this.controller,
    required this.recipes,
    required this.ingProv,
  });

  final HomeController controller;
  final List<Recipe> recipes;
  final IngredientsProvider ingProv;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate(
        [
          // TITLE ROW
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('Mes recettes', style: AppTextStyles.sectionTitle()),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: controller.showFavoritesOnly ? 'Afficher tout' : 'Afficher les favoris',
                    onPressed: controller.toggleFavoritesOnly,
                    icon: Icon(
                      controller.showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // EMPTY / GRID
          if (recipes.isEmpty)
            _EmptyState(
              favoritesOnly: controller.showFavoritesOnly,
              hasIngredients: ingProv.items.isNotEmpty,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final r = recipes[index];
                  final isSelected = r.id != null && controller.selected.contains(r.id);

                  return RecipeGridCard(
                    recipe: r,
                    selectionMode: controller.selectionMode,
                    selected: isSelected,
                    onTap: () {
                      if (controller.selectionMode) {
                        controller.toggleSelected(r);
                      } else {
                        context.push('/recipe/${r.id}');
                      }
                    },
                    onSelect: () => controller.toggleSelected(r),
                    onToggleFavorite: () =>
                        context.read<RecipeProvider>().toggleFavorite(r),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.favoritesOnly,
    required this.hasIngredients,
  });

  final bool favoritesOnly;
  final bool hasIngredients;

  @override
  Widget build(BuildContext context) {
    final title = favoritesOnly
        ? 'Aucun favori'
        : hasIngredients
            ? 'Aucune recette trouvée'
            : 'Aucune recette';

    final subtitle = favoritesOnly
        ? 'Ajoutez des recettes en favoris avec le cœur'
        : hasIngredients
            ? 'Essaie avec d’autres ingrédients'
            : 'Scannez votre première recette pour commencer';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text('📸', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
