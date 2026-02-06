import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recette_magique/models/recipe_model.dart';
import 'package:recette_magique/theme.dart';
import 'agenda_controller.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late final AgendaController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AgendaController(notify: () {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.init(context);
    });
  }

  Future<void> _handleOpenPlanner(DateTime day) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlannerPickerSheet(
        controller: _controller,
        initialDay: day,
      ),
    );
  }

  Future<void> _handleExportToCourses() async {
    if (!_controller.canExport) return;
    await _controller.exportToCourses(context);
    if (!mounted) return;
    context.go('/courses');
  }

  void _handleOpenRecipe(PlannedMeal meal) {
    final id = meal.recipe.id;
    if (id != null) context.push('/recipe/$id');
  }

  @override
  Widget build(BuildContext context) {
    final days = _controller.weekDays;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.bgGradient,
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 24,
                  bottom: 24,
                  left: 16,
                  right: 16,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primaryHeader,
                ),
                child: Column(
                  children: [
                    Text(
                      'Planificateur de repas',
                      style: AppTextStyles.sheetTitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organise tes repas de la semaine',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.text.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _HeaderCard(
                    subtitle: _controller.weekRangeLabel(),
                    onPrev: _controller.prevWeek,
                    onNext: _controller.nextWeek,
                    onToday: _controller.goToCurrentWeek,
                    onExport:
                        _controller.canExport ? _handleExportToCourses : null,
                  ),
                  const SizedBox(height: 14),
                  for (final d in days) ...[
                    _DayCard(
                      dayName: _controller.dayNameFr(d),
                      dateLabel: _controller.dayShortDateFr(d),
                      lunch: _controller.mealFor(d, MealType.lunch),
                      dinner: _controller.mealFor(d, MealType.dinner),
                      onOpenPlanner: () => _handleOpenPlanner(d),
                      onOpenRecipe: _handleOpenRecipe,
                      onRemove: (type) => _controller.removeMeal(d, type),
                    ),
                    const SizedBox(height: 12),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String subtitle;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback? onExport;

  const _HeaderCard({
    required this.subtitle,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: AppColors.primaryHeader,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.secondaryHeader,
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x22000000),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.text.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
                tooltip: 'Semaine précédente',
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
                tooltip: 'Semaine suivante',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.black, size: 20),
                  label: const Text(
                    'liste de course',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black),
                  ),
                  style: buttonStyle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onToday,
                  style: buttonStyle,
                  child: const Text(
                    'Cette semaine',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String dayName;
  final String dateLabel;
  final PlannedMeal? lunch;
  final PlannedMeal? dinner;
  final VoidCallback onOpenPlanner;
  final ValueChanged<PlannedMeal> onOpenRecipe;
  final ValueChanged<MealType> onRemove;

  const _DayCard({
    required this.dayName,
    required this.dateLabel,
    required this.lunch,
    required this.dinner,
    required this.onOpenPlanner,
    required this.onOpenRecipe,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryHeader,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpenPlanner,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Planifier',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SlotTile(
            title: 'Midi',
            meal: lunch,
            bg: AppColors.control,
            onTap: lunch == null ? onOpenPlanner : () => onOpenRecipe(lunch!),
            onRemove: lunch == null ? null : () => onRemove(MealType.lunch),
          ),
          const SizedBox(height: 10),
          _SlotTile(
            title: 'Soir',
            meal: dinner,
            bg: const Color(0xFFF6EAA4),
            onTap: dinner == null ? onOpenPlanner : () => onOpenRecipe(dinner!),
            onRemove: dinner == null ? null : () => onRemove(MealType.dinner),
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final String title;
  final PlannedMeal? meal;
  final Color bg;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _SlotTile({
    required this.title,
    required this.meal,
    required this.bg,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasMeal = meal != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: bg,
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Color(0xFF475569)),
            const SizedBox(width: 10),
            Expanded(
              child: hasMeal
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$title • ${meal!.persons} pers.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF475569),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meal!.recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ],
                    )
                  : Text(
                      'Ajouter $title',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ),
            if (hasMeal)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                color: const Color(0xFF475569),
              )
            else
              const Icon(Icons.add, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

class _PlannerPickerSheet extends StatefulWidget {
  final AgendaController controller;
  final DateTime initialDay;

  const _PlannerPickerSheet({
    required this.controller,
    required this.initialDay,
  });

  @override
  State<_PlannerPickerSheet> createState() => _PlannerPickerSheetState();
}

class _PlannerPickerSheetState extends State<_PlannerPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  RecipeCategory? _selectedCategory;
  late DateTime _selectedDay;
  MealType _selectedMealType = MealType.lunch;
  int _personsCount = 4;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleAdvanceToNextSlot() {
    if (_selectedMealType == MealType.lunch) {
      setState(() => _selectedMealType = MealType.dinner);
      return;
    }

    final nextDay = widget.controller.getNextSlot(_selectedDay, _selectedMealType);
    setState(() {
      _selectedDay = nextDay;
      _selectedMealType = MealType.lunch;
    });
  }

  Future<void> _handleRecipeSelected(Recipe recipe) async {
    await widget.controller.setMeal(
      context,
      day: _selectedDay,
      type: _selectedMealType,
      recipe: recipe,
      persons: _personsCount,
    );

    if (!mounted) return;

    final confirmationMessage = widget.controller.formatMealConfirmation(
      recipe,
      _selectedDay,
      _selectedMealType,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(confirmationMessage),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 850),
      ),
    );

    _handleAdvanceToNextSlot();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filteredRecipes = widget.controller.getFilteredRecipes(
      context,
      category: _selectedCategory,
      query: _searchController.text.trim(),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.90,
            minChildSize: 0.60,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(8),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildCategorySelector(),
                  const SizedBox(height: 14),
                  _buildDaySelector(),
                  const SizedBox(height: 12),
                  _buildMealTypeSelector(),
                  const SizedBox(height: 10),
                  _buildPersonsCounter(),
                  const SizedBox(height: 12),
                  _buildTargetInfo(),
                  const SizedBox(height: 10),
                  _buildRecipesList(filteredRecipes),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.restaurant_menu),
        const SizedBox(width: 8),
        Text(
          'Choisir une recette',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Terminer'),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Entrée'),
          selected: _selectedCategory == RecipeCategory.entree,
          onSelected: (_) =>
              setState(() => _selectedCategory = RecipeCategory.entree),
        ),
        ChoiceChip(
          label: const Text('Plat'),
          selected: _selectedCategory == RecipeCategory.plat,
          onSelected: (_) =>
              setState(() => _selectedCategory = RecipeCategory.plat),
        ),
        ChoiceChip(
          label: const Text('Dessert'),
          selected: _selectedCategory == RecipeCategory.dessert,
          onSelected: (_) =>
              setState(() => _selectedCategory = RecipeCategory.dessert),
        ),
        ChoiceChip(
          label: const Text('Boisson'),
          selected: _selectedCategory == RecipeCategory.boisson,
          onSelected: (_) =>
              setState(() => _selectedCategory = RecipeCategory.boisson),
        ),
      ],
    );
  }

  Widget _buildDaySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final day in widget.controller.weekDays) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(widget.controller.dayChipLabel(day)),
                selected: day.year == _selectedDay.year &&
                    day.month == _selectedDay.month &&
                    day.day == _selectedDay.day,
                onSelected: (_) => setState(() => _selectedDay = day),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Midi'),
          selected: _selectedMealType == MealType.lunch,
          onSelected: (_) =>
              setState(() => _selectedMealType = MealType.lunch),
        ),
        ChoiceChip(
          label: const Text('Soir'),
          selected: _selectedMealType == MealType.dinner,
          onSelected: (_) =>
              setState(() => _selectedMealType = MealType.dinner),
        ),
      ],
    );
  }

  Widget _buildPersonsCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_outlined),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Nombre de personnes',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _personsCount <= 1
                ? null
                : () => setState(() => _personsCount -= 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$_personsCount',
              style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            onPressed: _personsCount >= 24
                ? null
                : () => setState(() => _personsCount += 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetInfo() {
    final targetLabel =
        'Cible : ${widget.controller.dayHumanReadable(_selectedDay)} • ${widget.controller.mealTypeLabel(_selectedMealType)}';

    return Text(
      targetLabel,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _buildRecipesList(List<Recipe> recipes) {
    if (_selectedCategory == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'Choisis une catégorie (Entrée / Plat / Dessert / Boisson) pour afficher les recettes.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (recipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'Aucune recette trouvée',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: recipes.map((recipe) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.restaurant),
            title: Text(recipe.title),
            subtitle: Text(recipe.category.toString().split('.').last),
            trailing: const Icon(Icons.add),
            onTap: () => _handleRecipeSelected(recipe),
          ),
        );
      }).toList(),
    );
  }
}