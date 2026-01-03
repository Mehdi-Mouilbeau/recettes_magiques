import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/shooping_profider.dart';
import 'package:recette_magique/theme.dart';

/// Écran de détail d'une recette
class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _people;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _people = (widget.recipe.servings ?? 4).clamp(1, 24);
    _noteController = TextEditingController(text: widget.recipe.note ?? '');
  }

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
      final recipeProvider = context.read<RecipeProvider>();
      final success = await recipeProvider.deleteRecipe(widget.recipe);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recette supprimée')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar avec image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: (recipe.imageUrl ?? recipe.scannedImageUrl) != null
                  ? CachedNetworkImage(
                      imageUrl: (recipe.imageUrl ?? recipe.scannedImageUrl)!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.restaurant_menu, size: 80),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Center(
                        child: Text(
                          recipe.category.displayName[0],
                          style: context.textStyles.displayLarge?.bold.withColor(
                            Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.paddingXl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et catégorie
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: context.textStyles.headlineMedium?.bold,
                        ),
                      ),
                      _CategoryChip(category: recipe.category),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Informations
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        recipe.estimatedTime,
                        style: context.textStyles.bodyMedium?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Icon(
                        Icons.book_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          recipe.source,
                          style: context.textStyles.bodyMedium?.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Tags
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: recipe.tags
                          .map((tag) => Chip(
                                label: Text(tag, style: context.textStyles.labelSmall),
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  // Notes
                  Text('Note', style: context.textStyles.titleLarge?.bold),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () async {
                              if (recipe.id == null) return;
                              final ok = await context.read<RecipeProvider>().updateNote(recipe.id!, _noteController.text.trim());
                              if (!mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note enregistrée')));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'enregistrement')));
                              }
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Sélecteur de personnes
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Personnes', style: context.textStyles.titleMedium?.semiBold),
                      const Spacer(),
                      _PeopleCounter(
                        value: _people,
                        onChanged: (v) => setState(() => _people = v.clamp(1, 24)),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Ajouter à la liste de courses
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final prov = context.read<ShoppingProvider>();
                        prov.addRecipe(recipe, _people);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Ajouté à la liste de courses'),
                          behavior: SnackBarBehavior.floating,
                        ));
                        context.go('/courses');
                      },
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('Liste'),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Ingrédients
                  Text('Ingrédients', style: context.textStyles.titleLarge?.bold),
                  const SizedBox(height: AppSpacing.md),
                  ...recipe.ingredients.map((ingredient) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                _scaleIngredientLine(ingredient, (widget.recipe.servings ?? 4), _people),
                                style: context.textStyles.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: AppSpacing.xl),

                  // Étapes
                  Text('Préparation', style: context.textStyles.titleLarge?.bold),
                  const SizedBox(height: AppSpacing.md),
                  ...recipe.steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: context.textStyles.labelLarge?.bold.withColor(
                                      Theme.of(context).colorScheme.onPrimary,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(step, style: context.textStyles.bodyLarge)),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.xl),

                  // Bouton supprimer
                  OutlinedButton.icon(
                    onPressed: () => _deleteRecipe(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer cette recette'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Met à l'échelle la 1ère quantité trouvée dans la ligne d'ingrédient
  String _scaleIngredientLine(String line, int basePeople, int targetPeople) {
    final ratio = targetPeople / (basePeople <= 0 ? 1 : basePeople);
    if (ratio == 1) return line;

    // Gère fractions (1/2), nombres décimaux (1.5) et entiers
    final fractionRegex = RegExp(r'(\d+)\s*/\s*(\d+)');
    final numberRegex = RegExp(r'(\d+[\.,]?\d*)');

    String updated = line;

    // Priorité: fraction explicite
    final fMatch = fractionRegex.firstMatch(line);
    if (fMatch != null) {
      final num = double.parse(fMatch.group(1)!);
      final den = double.parse(fMatch.group(2)!);
      final val = (num / den) * ratio;
      final repl = _formatNumber(val);
      return updated.replaceFirst(fMatch.group(0)!, repl);
    }

    // Sinon 1er nombre trouvé
    final nMatch = numberRegex.firstMatch(line);
    if (nMatch != null) {
      final raw = nMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(raw);
      if (val != null) {
        final scaled = val * ratio;
        final repl = _formatNumber(scaled);
        updated = updated.replaceFirst(nMatch.group(0)!, repl);
      }
    }
    return updated;
  }

  String _formatNumber(double v) {
    // Arrondi au 0.5 le plus proche
    final half = (v * 2).round() / 2.0;
    if ((half - half.round()).abs() < 0.001) {
      return half.round().toString();
    }
    // remplacer point par virgule pour FR
    return half.toStringAsFixed(1).replaceAll('.', ',');
  }
}

/// Widget de chip de catégorie
class _CategoryChip extends StatelessWidget {
  final RecipeCategory category;

  const _CategoryChip({required this.category});

  Color _getCategoryColor(BuildContext context) {
    switch (category) {
      case RecipeCategory.entree:
        return Colors.green;
      case RecipeCategory.plat:
        return Colors.orange;
      case RecipeCategory.dessert:
        return Colors.pink;
      case RecipeCategory.boisson:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _getCategoryColor(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        category.displayName,
        style: context.textStyles.labelMedium?.bold.withColor(
          _getCategoryColor(context),
        ),
      ),
    );
  }
}

class _PeopleCounter extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PeopleCounter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
            tooltip: 'Moins',
          ),
          Text('$value', style: context.textStyles.titleMedium?.bold),
          IconButton(
            onPressed: value < 24 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
            tooltip: 'Plus',
          ),
        ],
      ),
    );
  }
}
