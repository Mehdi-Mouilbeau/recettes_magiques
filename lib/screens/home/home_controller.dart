import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/ingredients_provider.dart';
import 'package:recette_magique/providers/shopping_profider.dart';

class HomeController {
  HomeController({required this.notify});

  final VoidCallback notify;

  VoidCallback? _authStateListener;
  AuthProvider? _authProvider;

  final TextEditingController fieldController = TextEditingController();

  bool selectionMode = false;
  final Set<String> selected = {};

  RecipeCategory? category;
  bool showFavoritesOnly = false;

  void init(BuildContext context) {
    _authProvider = context.read<AuthProvider>();
    final recipeProvider = context.read<RecipeProvider>();

    _authStateListener = () async {
      final user = _authProvider?.currentUser;
      if (user != null) {
        recipeProvider.loadUserRecipes(user.uid);

        final all = recipeProvider.recipes;
        await context.read<ShoppingProvider>().hydrateFromStorage(all);

        await context.read<IngredientsProvider>().fetchSuggestions(user.uid);
      }
    };

    _authProvider!.addListener(_authStateListener!);

    final user = _authProvider!.currentUser;
    if (user != null) {
      () async {
        recipeProvider.loadUserRecipes(user.uid);

        final all = recipeProvider.recipes;
        await context.read<ShoppingProvider>().hydrateFromStorage(all);

        await context.read<IngredientsProvider>().fetchSuggestions(user.uid);
      }();
    }
  }

  void dispose() {
    if (_authProvider != null && _authStateListener != null) {
      _authProvider!.removeListener(_authStateListener!);
    }
    _authStateListener = null;
    fieldController.dispose();
  }

  String? _uid(BuildContext context) {
    final auth = _authProvider ?? context.read<AuthProvider>();
    return auth.currentUser?.uid;
  }

  List<Recipe> visibleRecipes(BuildContext context) {
    final ingredientsProv = context.watch<IngredientsProvider>();
    final hasItems = ingredientsProv.items.isNotEmpty;

    final base = hasItems
        ? ingredientsProv.suggestions
        : context.watch<RecipeProvider>().filteredRecipes;

    final byCategory = category == null
        ? base
        : base.where((r) => r.category == category).toList();

    return showFavoritesOnly
        ? byCategory.where((r) => r.isFavorite).toList()
        : byCategory;
  }

  void setCategory(RecipeCategory? value) {
    category = value;
    notify();
  }

  void toggleFavoritesOnly() {
    showFavoritesOnly = !showFavoritesOnly;
    notify();
  }

  void toggleCartMode() {
    selectionMode = !selectionMode;
    if (!selectionMode) selected.clear();
    notify();
  }

  void toggleSelected(Recipe recipe) {
    if (recipe.id == null) return;
    final id = recipe.id!;
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    notify();
  }

  Future<void> addFromField(BuildContext context) async {
    final raw = fieldController.text.trim();
    if (raw.isEmpty) return;

    final prov = context.read<IngredientsProvider>();
    final list = [...prov.items];

    for (final token in raw.split(RegExp(r'[;,\n]'))) {
      final t = token.trim();
      if (t.isNotEmpty && !list.contains(t)) list.add(t);
    }

    prov.setLocal(list);
    fieldController.clear();

    final uid = _uid(context);
    if (uid != null) {
      await prov.fetchSuggestions(uid);
    }
  }

  Future<void> removeItem(BuildContext context, String item) async {
    final prov = context.read<IngredientsProvider>();
    final list = [...prov.items]..remove(item);
    prov.setLocal(list);

    final uid = _uid(context);
    if (uid != null) {
      await prov.fetchSuggestions(uid);
    }
  }

  Future<void> clearItems(BuildContext context) async {
    final prov = context.read<IngredientsProvider>();
    prov.clearLocal();

    final uid = _uid(context);
    if (uid != null) {
      await prov.fetchSuggestions(uid);
    }
  }

  Future<void> signOut(BuildContext context) async {
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

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
      if (!context.mounted) return;
      context.go('/login');
    }
  }

  Future<void> confirmSelection(BuildContext context) async {
    final all = context.read<RecipeProvider>().recipes;
    final chosen =
        all.where((r) => r.id != null && selected.contains(r.id)).toList();
    if (chosen.isEmpty) return;

    final Map<String, int> personsByRecipe = {
      for (final r in chosen) r.id!: (r.servings ?? 4).clamp(1, 24),
    };

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                            for (final r in chosen) ...[
                              _PersonsRow(
                                title: r.title,
                                value:
                                    personsByRecipe[r.id!] ?? (r.servings ?? 4),
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

    if (confirmed == true && context.mounted) {
      final allRecipes = context.read<RecipeProvider>().recipes;
      final selectedRecipes = allRecipes
          .where((r) => r.id != null && selected.contains(r.id))
          .toList();

      // On sort du mode sélection dans l'écran Home
      selectionMode = false;
      selected.clear();
      notify();

      // On remplit le provider (et ça persiste automatiquement)
      final shopping = context.read<ShoppingProvider>();
      for (final r in selectedRecipes) {
        final id = r.id!;
        final persons = personsByRecipe[id] ?? (r.servings ?? 4);
        await shopping.addRecipe(r, persons);
      }

      if (!context.mounted) return;
      // On va directement à l'onglet Courses
      context.go('/courses');
    }
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
