import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/shopping_profider.dart';
import 'package:recette_magique/theme.dart';

import 'package:recette_magique/ui/widgets/round_icon_button.dart';
import 'package:recette_magique/ui/widgets/heart_button.dart';
import 'package:recette_magique/ui/widgets/info_chip.dart';

import 'package:recette_magique/ui/widgets/recipe/category_pill.dart';
import 'package:recette_magique/ui/widgets/recipe/small_pill.dart';
import 'package:recette_magique/ui/widgets/recipe/circle_control_button.dart';
import 'package:recette_magique/ui/widgets/recipe/step_number_circle.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _people;
  late final TextEditingController _noteController;

  static const double _headerHeight = 360;
  static const double _overlap = 34;

  @override
  void initState() {
    super.initState();
    _people = (widget.recipe.servings ?? 4).clamp(1, 24);
    _noteController = TextEditingController(text: widget.recipe.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final imageUrl = recipe.imageUrl ?? recipe.scannedImageUrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // ================= HEADER IMAGE =================
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: _headerHeight,
                  width: double.infinity,
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.black12),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.restaurant_menu,
                            size: 80,
                            color: Colors.white,
                          ),
                        )
                      : Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: Text(
                            recipe.category.displayName,
                            style: const TextStyle(
                              fontSize: 26,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),

                // overlay gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.transparent,
                          Colors.black.withOpacity(0.25),
                        ],
                      ),
                    ),
                  ),
                ),

                // top actions
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RoundIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => context.pop(),
                        ),
                        HeartButton(
                          isFavorite: recipe.isFavorite,
                          onTap: () => context
                              .read<RecipeProvider>()
                              .toggleFavorite(recipe),
                          backgroundColor: AppColors.roundButton,
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),

                // rounded top card
                Positioned(
                  left: 0,
                  right: 0,
                  top: _headerHeight - _overlap,
                  child: Container(
                    height: 60,
                    decoration: const BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.sheet),
                        topRight: Radius.circular(AppRadius.sheet),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ================= CONTENT =================
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.card,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg + _overlap,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title + category
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                                height: 1.1,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CategoryPill(text: recipe.category.displayName),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      InfoChip(
                        background: AppColors.chipIngredients,
                        icon: Icons.restaurant,
                        label: '${recipe.ingredients.length} ingrédients',
                      ),
                      InfoChip(
                        background: AppColors.chipTime,
                        icon: Icons.schedule,
                        label: recipe.estimatedTime,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ============ INGREDIENTS ============
                  Row(
                    children: [
                      Text(
                        'Ingrédients',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                      ),
                      const SizedBox(width: 12),
                      SmallPill(
                        text: '$_people pers.',
                        icon: Icons.people_alt,
                      ),
                      const Spacer(),
                      CircleControlButton(
                        icon: Icons.remove,
                        onTap: () => setState(
                          () => _people = (_people - 1).clamp(1, 24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleControlButton(
                        icon: Icons.add,
                        onTap: () => setState(
                          () => _people = (_people + 1).clamp(1, 24),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  ...recipe.ingredients.map(
                    (ingredient) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _scaleIngredientLine(
                                ingredient,
                                recipe.servings ?? 4,
                                _people,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: AppColors.text,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  Center(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          context
                              .read<ShoppingProvider>()
                              .addRecipe(recipe, _people);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Ajouté à la liste de courses'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                          context.go('/courses');
                        },
                        child: const Text(
                          'Ajouter à la liste de courses',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ============ STEPS ============
                  Text(
                    'Préparation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  ...recipe.steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StepNumberCircle(number: index + 1),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: AppColors.text,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.xl),

                  // ============ NOTE ============
                  Text(
                    'Note',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _noteController,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Vos annotations personnelles...',
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (recipe.id == null) return;

                              final ok = await context
                                  .read<RecipeProvider>()
                                  .updateNote(
                                    recipe.id!,
                                    _noteController.text.trim(),
                                  );

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Note enregistrée'
                                      : 'Erreur lors de l\'enregistrement'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.save),
                            label: const Text(
                              'Enregistrer',
                              style:
                                  TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= INGREDIENT SCALING =================

  String _scaleIngredientLine(
    String line,
    int basePeople,
    int targetPeople,
  ) {
    final ratio = targetPeople / (basePeople <= 0 ? 1 : basePeople);
    if (ratio == 1) return line;

    final fractionRegex = RegExp(r'(\d+)\s*/\s*(\d+)');
    final numberRegex = RegExp(r'(\d+[\.,]?\d*)');

    final fMatch = fractionRegex.firstMatch(line);
    if (fMatch != null) {
      final num = double.parse(fMatch.group(1)!);
      final den = double.parse(fMatch.group(2)!);
      return line.replaceFirst(
        fMatch.group(0)!,
        _formatNumber((num / den) * ratio),
      );
    }

    final nMatch = numberRegex.firstMatch(line);
    if (nMatch != null) {
      final val = double.tryParse(nMatch.group(1)!.replaceAll(',', '.'));
      if (val != null) {
        return line.replaceFirst(
          nMatch.group(0)!,
          _formatNumber(val * ratio),
        );
      }
    }

    return line;
  }

  String _formatNumber(double v) {
    final half = (v * 2).round() / 2.0;
    if ((half - half.round()).abs() < 0.001) return half.round().toString();
    return half.toStringAsFixed(1).replaceAll('.', ',');
  }
}
