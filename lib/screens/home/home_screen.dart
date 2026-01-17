import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/ingredients_provider.dart';
import 'package:recette_magique/theme.dart';

import 'package:recette_magique/ui/widgets/category_tile.dart';
import 'package:recette_magique/ui/widgets/recipe_grid_card.dart';

import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController c;

  @override
  void initState() {
    super.initState();
    c = HomeController(notify: () {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      c.init(context);
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = c.visibleRecipes(context);
    final ingProv = context.watch<IngredientsProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: false,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                onSignOut: () => c.signOut(context),
                selectionMode: c.selectionMode,
                selectedCount: c.selected.length,
                onCartPressed: c.toggleCartMode,
                onConfirm:
                    c.selected.isEmpty ? null : () => c.confirmSelection(context),
              ),
            ),
            SliverToBoxAdapter(
              child: _CategoryRow(
                category: c.category,
                onChange: c.setCategory,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _IngredientsSearchBar(
                controller: c.fieldController,
                onAdd: () => c.addFromField(context),
                onClear: () => c.clearItems(context),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: _IngredientsChips(
                onDelete: (it) => c.removeItem(context, it),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ingProv.isLoadingSuggestions)
                      const LinearProgressIndicator(),
                    if (ingProv.suggestionsError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        ingProv.suggestionsError!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _SectionTitle(
                showFavoritesOnly: c.showFavoritesOnly,
                onToggleFavorites: c.toggleFavoritesOnly,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (recipes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  favoritesOnly: c.showFavoritesOnly,
                  hasIngredients: ingProv.items.isNotEmpty,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final r = recipes[index];
                      final isSelected =
                          r.id != null && c.selected.contains(r.id);

                      return RecipeGridCard(
                        recipe: r,
                        selectionMode: c.selectionMode,
                        selected: isSelected,
                        onTap: () {
                          if (c.selectionMode) {
                            c.toggleSelected(r);
                          } else {
                            context.push('/recipe/${r.id}');
                          }
                        },
                        onSelect: () => c.toggleSelected(r),
                        onToggleFavorite: () =>
                            context.read<RecipeProvider>().toggleFavorite(r),
                      );
                    },
                    childCount: recipes.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final VoidCallback onSignOut;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onCartPressed;
  final VoidCallback? onConfirm;

  const _HomeHeader({
    required this.onSignOut,
    required this.selectionMode,
    required this.selectedCount,
    required this.onCartPressed,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'RECETTES Dans Ta Poche',
              style: AppTextStyles.brandTitle(),
            ),
          ),
          IconButton(
            tooltip: selectionMode
                ? 'Quitter la sélection'
                : 'Créer une liste de courses',
            onPressed: onCartPressed,
            icon: Icon(
              selectionMode ? Icons.close : Icons.shopping_cart_outlined,
              color: AppColors.text,
            ),
          ),
          if (selectionMode)
            IconButton(
              tooltip: selectedCount == 0
                  ? 'Sélectionne des recettes'
                  : 'Générer la liste ($selectedCount)',
              onPressed: onConfirm,
              icon: Icon(
                Icons.check,
                color:
                    selectedCount == 0 ? AppColors.textMuted : AppColors.text,
              ),
            ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_outlined, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final RecipeCategory? category;
  final ValueChanged<RecipeCategory?> onChange;

  const _CategoryRow({required this.category, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CategoryTile(
            label: 'Entrée',
            icon: Icons.restaurant,
            active: category == RecipeCategory.entree,
            onTap: () => onChange(
              category == RecipeCategory.entree ? null : RecipeCategory.entree,
            ),
          ),
          CategoryTile(
            label: 'Plat',
            icon: Icons.restaurant_menu,
            active: category == RecipeCategory.plat,
            onTap: () => onChange(
              category == RecipeCategory.plat ? null : RecipeCategory.plat,
            ),
          ),
          CategoryTile(
            label: 'Dessert',
            icon: Icons.icecream,
            active: category == RecipeCategory.dessert,
            onTap: () => onChange(
              category == RecipeCategory.dessert ? null : RecipeCategory.dessert,
            ),
          ),
          CategoryTile(
            label: 'Boisson',
            icon: Icons.local_drink,
            active: category == RecipeCategory.boisson,
            onTap: () => onChange(
              category == RecipeCategory.boisson ? null : RecipeCategory.boisson,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;
  final VoidCallback onClear;

  const _IngredientsSearchBar({
    required this.controller,
    required this.onAdd,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<IngredientsProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.tile,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              offset: Offset(0, 8),
              color: AppColors.shadow,
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onAdd(),
          decoration: InputDecoration(
            hintText: 'Ajouter un ingrédient (ex: tomates, carottes)',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.add, color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AppColors.tile,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Ajouter',
                  onPressed: prov.isLoadingSuggestions ? null : onAdd,
                  icon: const Icon(Icons.check_circle, color: AppColors.text),
                ),
                IconButton(
                  tooltip: 'Vider',
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline, color: AppColors.text),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientsChips extends StatelessWidget {
  final ValueChanged<String> onDelete;

  const _IngredientsChips({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<IngredientsProvider>();
    final items = prov.items;

    if (items.isEmpty) {
      // return const Padding(
      //   padding: EdgeInsets.symmetric(horizontal: 16),
      //   child: Align(
      //     alignment: Alignment.centerLeft,
      //     child: Text(
      //       'Ajoute tes ingrédients pour voir les recettes correspondantes 👇',
      //     ),
      //   ),
      // );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final it in items)
            Chip(
              label: Text(it),
              onDeleted: () => onDelete(it),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final bool showFavoritesOnly;
  final VoidCallback onToggleFavorites;

  const _SectionTitle({
    required this.showFavoritesOnly,
    required this.onToggleFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mes recettes',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
            ),
          ),
          Material(
            color: Colors.white.withOpacity(0.35),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip:
                  showFavoritesOnly ? 'Afficher tout' : 'Afficher les favoris',
              onPressed: onToggleFavorites,
              icon: Icon(
                showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool favoritesOnly;
  final bool hasIngredients;

  const _EmptyState({
    required this.favoritesOnly,
    required this.hasIngredients,
  });

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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📸', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
