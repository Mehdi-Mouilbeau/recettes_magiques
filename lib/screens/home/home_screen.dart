import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/leftovers_provider.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/screens/shopping/shopping_list_screen.dart';
import 'package:recette_magique/theme.dart';

import 'package:recette_magique/ui/widgets/category_tile.dart';
import 'package:recette_magique/ui/widgets/recipe_grid_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VoidCallback? _authStateListener;
  AuthProvider? _authProvider;

  final TextEditingController _ingredientsController = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selected = {};

  RecipeCategory? _category;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _authProvider = context.read<AuthProvider>();
      final recipeProvider = context.read<RecipeProvider>();
      final leftoversProvider = context.read<LeftoversProvider>();

      _authStateListener = () {
        final user = _authProvider?.currentUser;
        if (user != null) {
          recipeProvider.loadUserRecipes(user.uid);
          leftoversProvider.load(user.uid);
        }
      };

      _authProvider!.addListener(_authStateListener!);

      final user = _authProvider!.currentUser;
      if (user != null) {
        recipeProvider.loadUserRecipes(user.uid);
        leftoversProvider.load(user.uid);
      }
    });
  }

  void _loadRecipes() {
    final auth = _authProvider ?? context.read<AuthProvider>();
    final recipeProvider = context.read<RecipeProvider>();
    final user = auth.currentUser;
    if (user != null) recipeProvider.loadUserRecipes(user.uid);
  }

  void _onSearchIngredients() {
    final raw = _ingredientsController.text.trim();
    final auth = _authProvider ?? context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final list = raw
        .split(RegExp(r'[;,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    context.read<RecipeProvider>().searchByIngredients(user.uid, list);
  }

  void _resetSearch() {
    _ingredientsController.clear();
    _loadRecipes();
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (!mounted) return;
      context.go('/login');
    }
  }

  void _toggleCartMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RecipeProvider>();
    final all = prov.filteredRecipes;

    final byCategory = _category == null
        ? all
        : all.where((r) => r.category == _category).toList();

    final recipes = _showFavoritesOnly
        ? byCategory.where((r) => r.isFavorite).toList()
        : byCategory;

    return Scaffold(
      backgroundColor: Colors.transparent,

      // ⚠️ Si ton gradient est déjà appliqué globalement via MaterialApp.builder,
      // tu peux supprimer tout le Container ci-dessous.
      body: Container(
        decoration: const BoxDecoration(
          // ✅ idéalement remplace par: gradient: AppColors.bgGradient,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(
                  onSignOut: _signOut,
                  selectionMode: _selectionMode,
                  selectedCount: _selected.length,
                  onCartPressed: _toggleCartMode,
                  onConfirm: _selected.isEmpty ? null : _confirmSelection,
                ),
              ),
              SliverToBoxAdapter(
                child: _CategoryRow(
                  category: _category,
                  onChange: _setCategory,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: _SearchBar(
                  controller: _ingredientsController,
                  onSearch: _onSearchIngredients,
                  onReset: _resetSearch,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: _SectionTitle(
                  showFavoritesOnly: _showFavoritesOnly,
                  onToggleFavorites: () =>
                      setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (recipes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(favoritesOnly: _showFavoritesOnly),
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
                            r.id != null && _selected.contains(r.id);

                        return RecipeGridCard(
                          recipe: r,
                          selectionMode: _selectionMode,
                          selected: isSelected,
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelected(r);
                            } else {
                              context.push('/recipe/${r.id}');
                            }
                          },
                          onSelect: () => _toggleSelected(r),
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
      ),
    );
  }

  void _setCategory(RecipeCategory? value) {
    setState(() => _category = value);
  }

  void _toggleSelected(Recipe recipe) {
    if (recipe.id == null) return;
    setState(() {
      if (_selected.contains(recipe.id)) {
        _selected.remove(recipe.id);
      } else {
        _selected.add(recipe.id!);
      }
    });
  }

  Future<void> _confirmSelection() async {
    final all = context.read<RecipeProvider>().recipes;
    final selected =
        all.where((r) => r.id != null && _selected.contains(r.id)).toList();
    if (selected.isEmpty) return;

    Map<String, int> personsByRecipe = {
      for (final r in selected) r.id!: (r.servings ?? 4).clamp(1, 24),
    };

    final confirmed = await showModalBottomSheet<bool>(
  context: context,
  useRootNavigator: true, // ✅ au-dessus du ShellRoute / navbar
  isScrollControlled: true, // ✅ évite modale coupée
  backgroundColor: Colors.transparent, // ✅ pour gérer nous-mêmes le container arrondi
  builder: (ctx) {
    return StatefulBuilder(
      builder: (ctx, setModalState) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.55,
                minChildSize: 0.35,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_cart_outlined),
                            const SizedBox(width: 8),
                            Text(
                              'Personnes par recette',
                              style: Theme.of(ctx).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ✅ LISTE (scrollable via DraggableScrollableSheet)
                        for (final r in selected) ...[
                          _PersonsRow(
                            title: r.title,
                            value: personsByRecipe[r.id!] ?? (r.servings ?? 4),
                            onMinus: () {
                              final id = r.id!;
                              final current =
                                  personsByRecipe[id] ?? (r.servings ?? 4);
                              setModalState(() {
                                personsByRecipe[id] = max(1, current - 1);
                              });
                            },
                            onPlus: () {
                              final id = r.id!;
                              final current =
                                  personsByRecipe[id] ?? (r.servings ?? 4);
                              setModalState(() {
                                personsByRecipe[id] = min(24, current + 1);
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(ctx, true),
                            icon: const Icon(Icons.check),
                            label: const Text('Générer la liste'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  },
);

    if (confirmed == true && mounted) {
      final allRecipes = context.read<RecipeProvider>().recipes;
      final selectedRecipes = allRecipes
          .where((r) => r.id != null && _selected.contains(r.id))
          .toList();

      setState(() {
        _selectionMode = false;
        _selected.clear();
      });

      context.push(
        '/shopping',
        extra: ShoppingListArgs(
          recipes: selectedRecipes,
          personsByRecipe: personsByRecipe,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_authProvider != null && _authStateListener != null) {
      _authProvider!.removeListener(_authStateListener!);
    }
    _authStateListener = null;
    _ingredientsController.dispose();
    super.dispose();
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
              'RECETTE MAGIQUE',
              style: AppTextStyles.brandTitle(),
            ),
          ),

          // 🛒 caddie / fermer
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

          // ✅ valider (uniquement en mode sélection)
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

          // 🚪 déconnexion
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
            onTap: () =>
                onChange(category == RecipeCategory.plat ? null : RecipeCategory.plat),
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onReset;

  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
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
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            hintText: 'Rechercher',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
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
                  tooltip: 'Rechercher',
                  onPressed: onSearch,
                  icon: const Icon(Icons.arrow_forward, color: AppColors.text),
                ),
                IconButton(
                  tooltip: 'Réinitialiser',
                  onPressed: onReset,
                  icon: const Icon(Icons.clear, color: AppColors.text),
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
  const _EmptyState({required this.favoritesOnly});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📸', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              favoritesOnly ? 'Aucun favori' : 'Aucune recette',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              favoritesOnly
                  ? 'Ajoutez des recettes en favoris avec le cœur'
                  : 'Scannez votre première recette pour commencer',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
}
class _PersonsRow extends StatelessWidget {
  final String title;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _PersonsRow({
    required this.title,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
