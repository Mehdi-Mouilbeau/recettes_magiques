import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/theme.dart';
import 'package:recette_magique/ui/widgets/heart_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final img = recipe.imageUrl ?? recipe.scannedImageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 14,
                  offset: Offset(0, 10),
                  color: AppColors.shadow,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: img != null
                              ? CachedNetworkImage(
                                  imageUrl: img,
                                  fit: BoxFit.cover,
                                  placeholder: (c, _) =>
                                      Container(color: Colors.black12),
                                  errorWidget: (c, _, __) => Container(
                                    color: Colors.black12,
                                    child: const Icon(Icons.photo,
                                        size: 44, color: Colors.white),
                                  ),
                                )
                              : Container(
                                  color: Colors.black12,
                                  child: const Icon(Icons.photo,
                                      size: 44, color: Colors.white),
                                ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.tile,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              recipe.category.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      HeartButton(
                        isFavorite: recipe.isFavorite,
                        onTap: onToggleFavorite,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (selectionMode)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onSelect,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.green.withOpacity(0.90)
                              : Colors.white.withOpacity(0.80),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Icon(
                          selected ? Icons.check : Icons.circle_outlined,
                          size: 18,
                          color: selected ? Colors.white : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
