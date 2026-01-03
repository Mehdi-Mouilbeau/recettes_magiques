import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/theme.dart';
import 'package:recette_magique/widgets/recipe_card.dart';
import 'package:recette_magique/widgets/category_filter.dart';
import 'package:recette_magique/providers/leftovers_provider.dart';
import 'package:recette_magique/screens/shopping/shopping_list_screen.dart';
import 'package:recette_magique/providers/theme_provider.dart';

/// Écran principal - Liste des recettes
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VoidCallback? _authStateListener;
  final TextEditingController _ingredientsController = TextEditingController();
    bool _selectionMode = false;
    final Set<String> _selected = {};
  @override
  void initState() {
    super.initState();
    // Écoute les changements d'auth pour charger les recettes dynamiquement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final recipeProvider = context.read<RecipeProvider>();
      final leftoversProvider = context.read<LeftoversProvider>();
      _authStateListener = () {
        final user = authProvider.currentUser;
        if (user != null) {
          recipeProvider.loadUserRecipes(user.uid);
          leftoversProvider.load(user.uid);
        }
      };
      authProvider.addListener(_authStateListener!);
      // Chargement initial si déjà connecté
      if (authProvider.currentUser != null) {
        recipeProvider.loadUserRecipes(authProvider.currentUser!.uid);
        leftoversProvider.load(authProvider.currentUser!.uid);
      }
    });
  }

  void _loadRecipes() {
    final authProvider = context.read<AuthProvider>();
    final recipeProvider = context.read<RecipeProvider>();

    if (authProvider.currentUser != null) {
      recipeProvider.loadUserRecipes(authProvider.currentUser!.uid);
    }
  }

  void _onSearchIngredients() {
    final raw = _ingredientsController.text.trim();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUser == null) return;
    final list = raw
        .split(RegExp(r'[;,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    context.read<RecipeProvider>().searchByIngredients(authProvider.currentUser!.uid, list);
  }

  // Ouverture des restes déplacée dans l'onglet Restes

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
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final recipes = recipeProvider.filteredRecipes;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selected.length} sélectionnée${_selected.length > 1 ? 's' : ''}'
              : 'Mes Recettes',
          style: context.textStyles.titleLarge?.bold,
        ),
        actions: [
          // Light/Dark toggle
          Builder(builder: (context) {
            final themeProv = context.watch<ThemeProvider>();
            final isDark = themeProv.mode == ThemeMode.dark;
            return IconButton(
              tooltip: isDark ? 'Mode clair' : 'Mode sombre',
              icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round, color: Colors.orange),
              onPressed: () => themeProv.toggle(),
            );
          }),
          if (!_selectionMode) ...[
            IconButton(
              tooltip: 'Composer une liste de courses',
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => setState(() => _selectionMode = true),
            ),
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: _signOut,
            ),
          ] else ...[
            IconButton(
              tooltip: 'Valider la sélection',
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: _selected.isEmpty ? null : _confirmSelection,
            ),
            IconButton(
              tooltip: 'Annuler',
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selected.clear();
              }),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Filtres de catégorie
          const CategoryFilter(),

          // Recherche par ingrédients
          Padding(
            padding: AppSpacing.horizontalMd,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ingredientsController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onSearchIngredients(),
                    decoration: InputDecoration(
                      hintText: 'Chercher par ingrédients (ex: tomate, carotte)',
                      prefixIcon: const Icon(Icons.kitchen, color: Colors.green),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Rechercher',
                  onPressed: _onSearchIngredients,
                  icon: const Icon(Icons.search, color: Colors.blue),
                ),
                IconButton(
                  tooltip: 'Réinitialiser',
                  onPressed: _resetSearch,
                  icon: const Icon(Icons.clear, color: Colors.red),
                ),
              ],
            ),
          ),
          // Bouton "Mes restes" retiré (dorénavant tout se passe dans l'onglet Restes)

          // Liste des recettes
          Expanded(
            child: recipes.isEmpty
                ? _buildEmptyState()
                : _buildRecipeList(recipes),
          ),
        ],
      ),
      // Bottom navigation includes Scan; no FAB needed here.
      floatingActionButton: null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📸', style: TextStyle(fontSize: 80)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Aucune recette',
              style: context.textStyles.headlineSmall?.bold,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Scannez votre première recette pour commencer',
              style: context.textStyles.bodyLarge?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeList(List<Recipe> recipes) {
    return ListView.builder(
      padding: AppSpacing.paddingMd,
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final selected = recipe.id != null && _selected.contains(recipe.id);
        return RecipeCard(
          recipe: recipe,
          onTap: () => context.push('/recipe/${recipe.id}'),
          selectable: _selectionMode,
          selected: selected,
          onSelectChanged: (v) {
            setState(() {
              if (recipe.id == null) return;
              if (v) {
                _selected.add(recipe.id!);
              } else {
                _selected.remove(recipe.id!);
              }
            });
          },
        );
      },
    );
  }

  Future<void> _confirmSelection() async {
    // Build per-recipe persons map with defaults
    final all = context.read<RecipeProvider>().recipes;
    final selected = all.where((r) => r.id != null && _selected.contains(r.id)).toList();
    if (selected.isEmpty) return;

    Map<String, int> personsByRecipe = {
      for (final r in selected)
        r.id!: (r.servings ?? 4).clamp(1, 24),
    };

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Personnes par recette', style: Theme.of(ctx).textTheme.titleLarge),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: selected.length,
                      itemBuilder: (context, index) {
                        final r = selected[index];
                        final id = r.id!;
                        final current = personsByRecipe[id] ?? (r.servings ?? 4);
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(r.title, style: Theme.of(context).textTheme.titleMedium)),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                                onPressed: () => setModalState(() => personsByRecipe[id] = max(1, current - 1)),
                              ),
                              Text('${personsByRecipe[id]}', style: Theme.of(context).textTheme.titleMedium?.bold),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                onPressed: () => setModalState(() => personsByRecipe[id] = current + 1),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
            ),
          );
        });
      },
    );

    if (confirmed == true && mounted) {
      final allRecipes = context.read<RecipeProvider>().recipes;
      final selectedRecipes = allRecipes.where((r) => r.id != null && _selected.contains(r.id)).toList();
      setState(() {
        _selectionMode = false;
        _selected.clear();
      });
      context.push('/shopping', extra: ShoppingListArgs(recipes: selectedRecipes, personsByRecipe: personsByRecipe));
    }
  }

  @override
  void dispose() {
    final authProvider = context.read<AuthProvider>();
    if (_authStateListener != null) {
      authProvider.removeListener(_authStateListener!);
      _authStateListener = null;
    }
    _ingredientsController.dispose();
    super.dispose();
  }
}

