// lib/screens/home/widgets/home_top_panel.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/ingredients_provider.dart';
import 'package:recette_magique/theme.dart';
import 'package:recette_magique/ui/widgets/category_tile.dart';

import '../home_controller.dart';

class HomeTopPanel extends StatelessWidget {
  const HomeTopPanel({
    super.key,
    required this.controller,
  });

  final HomeController controller;

  static const double height = 300;

  @override
  Widget build(BuildContext context) {
    final ingProv = context.watch<IngredientsProvider>();
    final headerAction = _HeaderAction.from(controller);

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.primaryHeader),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ClipRect(
                  child: Column(
                    children: [
                      // ----------------------------
                      // HEADER (fixe)
                      // ----------------------------
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Text('Recettes',
                                          style: AppTextStyles.appTitle()),
                                      Text(
                                          'dans ma poche',
                                          style: AppTextStyles.secondaryAppTitle()),
                                          const SizedBox(height: 10),
                                    ],
                                  ),
                                  Image.asset(
                                    'assets/icons/mascotte.png',
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: headerAction.tooltip,
                              onPressed: headerAction.onPressed(context),
                              icon: Icon(headerAction.icon,
                                  color: AppColors.text),
                            ),
                            IconButton(
                              tooltip: 'Déconnexion',
                              onPressed: () => controller.signOut(context),
                              icon: const Icon(Icons.logout_outlined,
                                  color: AppColors.text),
                            ),
                            IconButton(
                              tooltip: 'Profil',
                              onPressed: () => context.push('/account'),
                              icon: const Icon(Icons.person,
                                  color: AppColors.text),
                            ),
                          ],
                        ),
                      ),

                      // ----------------------------
                      // RESTE (flexible)
                      // ----------------------------
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Catégories avec images assets
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _cat(
                                      label: 'Entrée',
                                      assetPath:
                                          'assets/icons/iconcards/icon_entree.png',
                                      active: controller.category ==
                                          RecipeCategory.entree,
                                      onTap: () => controller.setCategory(
                                        controller.category ==
                                                RecipeCategory.entree
                                            ? null
                                            : RecipeCategory.entree,
                                      ),
                                    ),
                                    _cat(
                                      label: 'Plat',
                                      assetPath: 'assets/icons/iconcards/icon_plat.png',
                                      active: controller.category ==
                                          RecipeCategory.plat,
                                      onTap: () => controller.setCategory(
                                        controller.category ==
                                                RecipeCategory.plat
                                            ? null
                                            : RecipeCategory.plat,
                                      ),
                                    ),
                                    _cat(
                                      label: 'Dessert',
                                      assetPath: 'assets/icons/iconcards/icon_cake.png',
                                      active: controller.category ==
                                          RecipeCategory.dessert,
                                      onTap: () => controller.setCategory(
                                        controller.category ==
                                                RecipeCategory.dessert
                                            ? null
                                            : RecipeCategory.dessert,
                                      ),
                                    ),
                                    _cat(
                                      label: 'Boisson',
                                      assetPath:
                                          'assets/icons/iconcards/icon_boisson.png',
                                      active: controller.category ==
                                          RecipeCategory.boisson,
                                      onTap: () => controller.setCategory(
                                        controller.category ==
                                                RecipeCategory.boisson
                                            ? null
                                            : RecipeCategory.boisson,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Search
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.secondaryHeader,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          boxShadow: const [
                                            BoxShadow(
                                              blurRadius: 18,
                                              offset: Offset(0, 10),
                                              color: AppColors.shadow,
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller:
                                              controller.fieldController,
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: (_) =>
                                              controller.addFromField(context),
                                          decoration: InputDecoration(
                                            hintText: 'Rechercher',
                                            hintStyle: AppTextStyles.hint(),
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              color: AppColors.textMuted,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor:
                                                AppColors.secondaryHeader,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: controller.toggleFavoritesOnly,
                                      borderRadius: BorderRadius.circular(999),
                                      child: Tooltip(
                                        message: controller.showFavoritesOnly
                                            ? 'Afficher tout'
                                            : 'Afficher les favoris',
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryHeader,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            controller.showFavoritesOnly
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: AppColors.test,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),

                              // Status compact
                              const SizedBox(height: 6),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: _CompactStatus(ingProv: ingProv),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _cat({
    required String label,
    required String assetPath,
    required bool active,
    required VoidCallback onTap,
  }) {
    return CategoryTile(
      label: label,
      icon: Image.asset(
        assetPath,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
      active: active,
      onTap: onTap,
    );
  }
}

/// widget interne compact
class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.ingProv});
  final IngredientsProvider ingProv;

  @override
  Widget build(BuildContext context) {
    final hasProgress = ingProv.isLoadingSuggestions;
    final err = ingProv.suggestionsError;

    if (!hasProgress && err == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasProgress) const LinearProgressIndicator(minHeight: 3),
        if (err != null) ...[
          const SizedBox(height: 4),
          Text(
            err,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.muted().withColor(
              Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback? Function(BuildContext context) _builder;

  const _HeaderAction._({
    required this.icon,
    required this.tooltip,
    required VoidCallback? Function(BuildContext) builder,
  }) : _builder = builder;

  VoidCallback? onPressed(BuildContext context) => _builder(context);

  static _HeaderAction from(HomeController c) {
    if (!c.selectionMode) {
      return _HeaderAction._(
        icon: Icons.shopping_cart_outlined,
        tooltip: 'Créer une liste de courses',
        builder: (_) => c.toggleCartMode,
      );
    }
    if (c.selected.isEmpty) {
      return _HeaderAction._(
        icon: Icons.close,
        tooltip: 'Quitter la sélection',
        builder: (_) => c.toggleCartMode,
      );
    }
    return _HeaderAction._(
      icon: Icons.check_circle,
      tooltip: 'Générer la liste (${c.selected.length})',
      builder: (ctx) => () => c.confirmSelection(ctx),
    );
  }
}
