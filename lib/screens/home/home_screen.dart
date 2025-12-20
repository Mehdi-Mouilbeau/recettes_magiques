import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/theme.dart';
import 'package:recette_magique/widgets/recipe_card.dart';
import 'package:recette_magique/widgets/category_filter.dart';
import 'package:recette_magique/providers/leftovers_provider.dart';
import 'package:recette_magique/widgets/leftovers_sheet.dart';

/// Écran principal - Liste des recettes
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VoidCallback? _authStateListener;
  final TextEditingController _ingredientsController = TextEditingController();
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

  Future<void> _openLeftovers() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUser == null) return;
    final leftoversProv = context.read<LeftoversProvider>();
    final initial = leftoversProv.leftovers;
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: LeftoversSheet(initialItems: initial),
      ),
    );
    if (result != null && mounted) {
      final uid = authProvider.currentUser!.uid;
      final ok = await leftoversProv.save(uid, result);
      if (ok && mounted) {
        await context.read<RecipeProvider>().searchByIngredients(uid, result);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Recettes proposées selon vos restes'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
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
          'Mes Recettes',
          style: context.textStyles.titleLarge?.bold,
        ),
        actions: [
          IconButton(
            tooltip: 'Mes restes',
            icon: const Icon(Icons.kitchen),
            onPressed: _openLeftovers,
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: _signOut,
          ),
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
          // Bouton Mes restes (option visible)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _openLeftovers,
                icon: const Icon(Icons.kitchen),
                label: const Text('Mes restes'),
              ),
            ),
          ),

          // Liste des recettes
          Expanded(
            child: recipes.isEmpty
                ? _buildEmptyState()
                : _buildRecipeList(recipes),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scan'),
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Scanner'),
      ),
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
        return RecipeCard(
          recipe: recipe,
          onTap: () => context.push('/recipe/${recipe.id}'),
        );
      },
    );
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
