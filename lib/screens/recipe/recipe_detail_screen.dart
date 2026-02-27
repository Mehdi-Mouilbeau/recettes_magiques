import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/shopping_profider.dart';
import 'package:recette_magique/screens/recipe/recipe_detail_controller.dart';
import 'package:recette_magique/theme.dart';

import 'package:recette_magique/ui/widgets/round_icon_button.dart';
import 'package:recette_magique/ui/widgets/heart_button.dart';
import 'package:recette_magique/ui/widgets/recipe/category_pill.dart';
import 'package:recette_magique/ui/widgets/recipe/small_pill.dart';
import 'package:recette_magique/ui/widgets/recipe/circle_control_button.dart';
import 'package:recette_magique/ui/widgets/recipe/step_number_circle.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  static const double _expandedHeight = 360;

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
      final success = await context.read<RecipeProvider>().deleteRecipe(recipe);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recette supprimée')),
        );
        context.pop();
      }
    }
  }

  Future<void> _regenerateImage(BuildContext context) async {
    if (recipe.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Régénérer l'image ?"),
        content: const Text(
          'Une nouvelle image sera générée. Ça peut prendre quelques secondes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Régénérer'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final ok = await context.read<RecipeProvider>().regenerateImage(recipe.id!);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? "Régénération lancée" : "Erreur lors de la régénération"),
      ),
    );
  }

  Widget _InfoItem({
    required BuildContext context,
    required String icon,
    required String text,
  }) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(icon, width: 20, height: 20),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = recipe.imageUrl ?? recipe.scannedImageUrl;

    return ChangeNotifierProvider(
      create: (_) => RecipeDetailController(recipe: recipe),
      child: Scaffold(
        backgroundColor: AppColors.card,
        body: Consumer<RecipeDetailController>(
          builder: (context, controller, _) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  expandedHeight: _expandedHeight,
                  pinned: true,
                  stretch: true,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.lg),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RoundIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => context.pop(),
                      ),
                    ),
                  ),
                  actions: [
                    RoundIconButton(
                      icon: Icons.refresh,
                      onTap: () => _regenerateImage(context),
                    ),
                    const SizedBox(width: 10),
                    RoundIconButton(
                      icon: controller.isEditing ? Icons.check : Icons.edit,
                      onTap: () async {
                        if (controller.isEditing) {
                          final ok = await controller
                              .saveChanges(context.read<RecipeProvider>());
                          if (!context.mounted) return;
                          if (ok) {
                            controller.toggleEditing();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Recette mise à jour')),
                            );
                          }
                        } else {
                          controller.toggleEditing();
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      child: HeartButton(
                        isFavorite: recipe.isFavorite,
                        onTap: () =>
                            context.read<RecipeProvider>().toggleFavorite(recipe),
                        backgroundColor: AppColors.roundButton,
                        iconColor: Colors.white,
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.fadeTitle,
                    ],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null)
                          CachedNetworkImage(
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
                        else
                          Container(
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
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.25),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.35),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 28,
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
                ),

                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.sheet),
                        topRight: Radius.circular(AppRadius.sheet),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + category
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: controller.isEditing
                                  ? TextField(
                                      controller: controller.titleController,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.text,
                                            height: 1.1,
                                          ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                      ),
                                    )
                                  : Text(
                                      controller.recipe.title,
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

                        // Container infos (éditable ou lecture)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.overlay,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: controller.isEditing
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller:
                                            controller.preparationTimeController,
                                        decoration: const InputDecoration(
                                          labelText: 'Préparation',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller:
                                            controller.cookingTimeController,
                                        decoration: const InputDecoration(
                                          labelText: 'Cuisson',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    runAlignment: WrapAlignment.center,
                                    spacing: 24,
                                    runSpacing: 16,
                                    children: [
                                      _InfoItem(
                                        context: context,
                                        icon: 'assets/icons/iconcards/icon_ingredients.png',
                                        text: '${recipe.ingredients.length} ingrédients',
                                      ),
                                      if (recipe.preparationTime != null &&
                                          recipe.preparationTime!.isNotEmpty)
                                        _InfoItem(
                                          context: context,
                                          icon: 'assets/icons/iconcards/icon_preparation.png',
                                          text: 'Prépa: ${recipe.preparationTime}',
                                        ),
                                      if (recipe.cookingTime != null &&
                                          recipe.cookingTime!.isNotEmpty)
                                        _InfoItem(
                                          context: context,
                                          icon: 'assets/icons/iconcards/icon_plat.png',
                                          text: 'Cuisson: ${recipe.cookingTime}',
                                        ),
                                    ],
                                  ),
                                ),
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
                              text: '${controller.people} pers.',
                              icon: Icons.people_alt,
                            ),
                            const Spacer(),
                            CircleControlButton(
                              icon: Icons.remove,
                              onTap: controller.decrementPeople,
                            ),
                            const SizedBox(width: 8),
                            CircleControlButton(
                              icon: Icons.add,
                              onTap: controller.incrementPeople,
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        ...controller.recipe.ingredients.map(
                          (ingredient) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Icon(Icons.circle,
                                      size: 7, color: AppColors.text),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    controller.scaleIngredientLine(ingredient),
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              onPressed: () {
                                context
                                    .read<ShoppingProvider>()
                                    .addRecipe(recipe, controller.people);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ajouté à la liste de courses'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                context.go('/courses');
                              },
                              child: const Text(
                                'Ajouter à la liste de courses',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // ============ STEPS ============
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.overlay,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Préparation',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.text,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (controller.isEditing)
                                TextField(
                                  controller: controller.stepsController,
                                  minLines: 5,
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: 'Une étape par ligne',
                                  ),
                                )
                              else
                                ...controller.recipe.steps
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        StepNumberCircle(number: entry.key + 1),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            entry.value,
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
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            onPressed: () => _deleteRecipe(context),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white),
                            label: const Text(
                              'Supprimer cette recette',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 80),

                        // ============ NOTE ============
                        Text(
                          'Note',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: controller.noteController,
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (recipe.id == null) return;
                                    final ok = await context
                                        .read<RecipeProvider>()
                                        .updateNote(
                                          recipe.id!,
                                          controller.noteController.text.trim(),
                                        );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                              ? 'Note enregistrée'
                                              : "Erreur lors de l'enregistrement",
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.save,
                                      color: Colors.white),
                                  label: const Text(
                                    'Enregistrer',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                          height: AppSpacing.lg +
                              MediaQuery.of(context).padding.bottom +
                              50,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}