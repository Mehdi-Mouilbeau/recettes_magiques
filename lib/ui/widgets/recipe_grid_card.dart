// lib/ui/widgets/recipe_grid_card.dart
import 'package:flutter/material.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/theme.dart';

class RecipeGridCard extends StatelessWidget {
  final Recipe recipe;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final VoidCallback onToggleFavorite;

  const RecipeGridCard({
    super.key,
    required this.recipe,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onSelect,
    required this.onToggleFavorite,
  });

  String _categoryLabel(RecipeCategory? c) {
    switch (c) {
      case RecipeCategory.entree:
        return 'Entrée';
      case RecipeCategory.plat:
        return 'Plat';
      case RecipeCategory.dessert:
        return 'Dessert';
      case RecipeCategory.boisson:
        return 'Boisson';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFFF3F0C6);

    const double cardRadius = 18;
    const double imageRadius = 20;

    final category = _categoryLabel(recipe.category);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // IMAGE + TAG
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(imageRadius),
                          child: _RecipeImage(recipe: recipe),
                        ),
                      ),
                      
                      if (category.isNotEmpty)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F0C9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),

                      // Mode sélection (petit indicateur discret)
                      if (selectionMode)
                        Positioned(
                          left: 10,
                          top: 10,
                          child: InkWell(
                            onTap: onSelect,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: AppColors.text,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // TITRE + COEUR (ligne du bas)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onToggleFavorite,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: AppColors.text,
                          size: 18,
                        ),
                      ),
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

class _RecipeImage extends StatelessWidget {
  final Recipe recipe;
  const _RecipeImage({required this.recipe});

  @override
  Widget build(BuildContext context) {
    // Adapte ici si ton modèle a un autre champ (imageUrl / image / photoUrl etc.)
    final String? url = (recipe as dynamic).imageUrl as String?;

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 46, color: AppColors.textMuted),
      ),
    );
  }
}
