// lib/screens/home/widgets/home_top_panel.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  static const double height = 250;

  static const Color _headerBg = Color(0xFFE3B56E);
  static const Color _searchBg = Color(0xFFDBE6B9);

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
          decoration: const BoxDecoration(color: _headerBg),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: ClipRect(
                    child: Column(
                      children: [
                        // Zone "fixe" (header)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/icons/mascotte.png',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'Recettes dans ma poche',
                                        style: AppTextStyles.brandTitle1(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: headerAction.tooltip,
                                onPressed: headerAction.onPressed(context),
                                icon: Icon(headerAction.icon, color: AppColors.text),
                              ),
                              IconButton(
                                tooltip: 'Déconnexion',
                                onPressed: () => controller.signOut(context),
                                icon: const Icon(Icons.logout_outlined, color: AppColors.text),
                              ),
                              IconButton(
                                tooltip: 'Profil',
                                onPressed: () => context.push('/account'),
                                icon: const Icon(Icons.person, color: AppColors.text),
                              ),
                            ],
                          ),
                        ),

                        // ✅ Le reste devient flexible et scrollable si besoin
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            // Le scroll ne sert que "au cas où" overflow → pas de sensation de scroll
                            child: Column(
                              children: [
                                // Catégories
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _cat(
                                        label: 'Entrée',
                                        icon: Icons.restaurant,
                                        active: controller.category == RecipeCategory.entree,
                                        onTap: () => controller.setCategory(
                                          controller.category == RecipeCategory.entree
                                              ? null
                                              : RecipeCategory.entree,
                                        ),
                                      ),
                                      _cat(
                                        label: 'Plat',
                                        icon: Icons.restaurant_menu,
                                        active: controller.category == RecipeCategory.plat,
                                        onTap: () => controller.setCategory(
                                          controller.category == RecipeCategory.plat
                                              ? null
                                              : RecipeCategory.plat,
                                        ),
                                      ),
                                      _cat(
                                        label: 'Dessert',
                                        icon: Icons.icecream,
                                        active: controller.category == RecipeCategory.dessert,
                                        onTap: () => controller.setCategory(
                                          controller.category == RecipeCategory.dessert
                                              ? null
                                              : RecipeCategory.dessert,
                                        ),
                                      ),
                                      _cat(
                                        label: 'Boisson',
                                        icon: Icons.local_drink,
                                        active: controller.category == RecipeCategory.boisson,
                                        onTap: () => controller.setCategory(
                                          controller.category == RecipeCategory.boisson
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _searchBg,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 18,
                                          offset: Offset(0, 10),
                                          color: AppColors.shadow,
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: controller.fieldController,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => controller.addFromField(context),
                                      decoration: InputDecoration(
                                        hintText: 'Rechercher',
                                        hintStyle: AppTextStyles.hint(),
                                        prefixIcon:
                                            const Icon(Icons.search, color: AppColors.textMuted),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: _searchBg,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Ajouter',
                                              onPressed: ingProv.isLoadingSuggestions
                                                  ? null
                                                  : () => controller.addFromField(context),
                                              icon: const Icon(Icons.check_circle,
                                                  color: AppColors.text),
                                            ),
                                            IconButton(
                                              tooltip: 'Vider',
                                              onPressed: () => controller.clearItems(context),
                                              icon: const Icon(Icons.delete_outline,
                                                  color: AppColors.text),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // ✅ status compact : ne pousse pas trop le layout
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: _CompactStatus(ingProv: ingProv),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return CategoryTile(
      label: label,
      icon: icon,
      active: active,
      onTap: onTap,
    );
  }
}

/// ✅ widget interne (dans le même fichier) très compact
class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.ingProv});
  final IngredientsProvider ingProv;

  @override
  Widget build(BuildContext context) {
    final hasProgress = ingProv.isLoadingSuggestions;
    final err = ingProv.suggestionsError;

    if (!hasProgress && err == null) return const SizedBox(height: 0);

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
            style: AppTextStyles.muted().withColor(Theme.of(context).colorScheme.error),
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
