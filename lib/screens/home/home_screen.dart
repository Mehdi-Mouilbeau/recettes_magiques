import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/theme.dart';
import 'package:recette_magique/widgets/recipe_card.dart';
import 'package:recette_magique/widgets/category_filter.dart';

/// Écran principal - Liste des recettes
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  void _loadRecipes() {
    final authProvider = context.read<AuthProvider>();
    final recipeProvider = context.read<RecipeProvider>();

    if (authProvider.currentUser != null) {
      recipeProvider.loadUserRecipes(authProvider.currentUser!.uid);
    }
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
            icon: const Icon(Icons.logout_outlined),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres de catégorie
          const CategoryFilter(),

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
}
