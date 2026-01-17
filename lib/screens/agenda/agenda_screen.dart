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
  late final AgendaController c;

  @override
  void initState() {
    super.initState();
    c = AgendaController(notify: () {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await c.init(context);
    });
  }

  Future<void> _openWeekEditor(DateTime day) async {
    final all = c.allRecipes(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecipePickerSheet(
        recipes: all,
        weekDays: c.weekDays,
        initialDay: day,
        onAdd: (selectedDay, meal) => c.addMeal(context, selectedDay, meal),
      ),
    );
  }

  Future<void> _exportToCourses() async {
    if (!c.canExport) return;
    await c.exportToCourses(context);
    if (!mounted) return;
    context.go('/courses');
  }

  @override
  Widget build(BuildContext context) {
    final days = c.weekDays;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: false,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _HeaderCard(
              title: 'Planificateur de repas',
              subtitle: c.weekRangeLabel(),
              onPrev: c.prevWeek,
              onNext: c.nextWeek,
              onToday: c.goToCurrentWeek,
              onExport: c.canExport ? _exportToCourses : null,
            ),
            const SizedBox(height: 14),
            for (final d in days) ...[
              _DayCard(
                dayName: c.dayNameFr(d),
                dateLabel: c.dayShortDateFr(d),
                meals: c.mealsFor(d),
                onAdd: () => _openWeekEditor(d),
                onRemove: (index) => c.removeMeal(d, index),
                onOpen: (index) {
                  final meal = c.mealsFor(d)[index];
                  final id = meal.recipe.id;
                  if (id != null) context.push('/recipe/$id');
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback? onExport;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6EDB6),
            Color(0xFFECE6A2),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x22000000),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month, color: AppColors.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.text.withOpacity(0.8),
                      ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Exporter la liste de courses'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
                  IconButton(
                      onPressed: onNext, icon: const Icon(Icons.chevron_right)),
                ],
              ),
              TextButton(
                  onPressed: onToday, child: const Text('Cette semaine')),
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
  final List<PlannedMeal> meals;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onOpen;

  const _DayCard({
    required this.dayName,
    required this.dateLabel,
    required this.meals,
    required this.onAdd,
    required this.onRemove,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
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
            ],
          ),
          const SizedBox(height: 10),
          if (meals.isNotEmpty)
            for (int i = 0; i < meals.length; i++) ...[
              _MealLine(
                meal: meals[i],
                onRemove: () => onRemove(i),
                onOpen: () => onOpen(i),
              ),
              const SizedBox(height: 10),
            ],
          _AddDashed(onTap: onAdd),
        ],
      ),
    );
  }
}

class _MealLine extends StatelessWidget {
  final PlannedMeal meal;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  const _MealLine({
    required this.meal,
    required this.onRemove,
    required this.onOpen,
  });

  Color _bg() {
    switch (meal.type) {
      case MealType.lunch:
        return const Color(0xFFEAF6DF);
      case MealType.dinner:
        return const Color(0xFFF6EAA4);
      case MealType.dessert:
        return const Color(0xFFEDE7FF);
      case MealType.snack:
        return const Color(0xFFE6F4FF);
      case MealType.other:
        return const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _bg(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.schedule, color: Color(0xFF475569)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${meal.label} • ${meal.persons} pers.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meal.recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              color: const Color(0xFF475569),
              tooltip: 'Retirer',
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDashed extends StatelessWidget {
  final VoidCallback onTap;
  const _AddDashed({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD5D9E2), width: 1.2),
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline, color: Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Text(
              'Ajouter un repas',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipePickerSheet extends StatefulWidget {
  final List<Recipe> recipes;
  final List<DateTime> weekDays;
  final DateTime initialDay;
  final Future<void> Function(DateTime day, PlannedMeal meal) onAdd;

  const _RecipePickerSheet({
    required this.recipes,
    required this.weekDays,
    required this.initialDay,
    required this.onAdd,
  });

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  final TextEditingController _q = TextEditingController();

  RecipeCategory? _cat;
  MealType _type = MealType.lunch;
  int _persons = 4;

  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
        widget.initialDay.year, widget.initialDay.month, widget.initialDay.day);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _dayChipLabel(DateTime d) {
    const names = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final idx = (d.weekday - 1) % 7;
    return names[idx];
  }

  String _dayHuman(DateTime d) => '${_dayChipLabel(d)} ${d.day}/${d.month}';

  void _validateDay() {
    final idx = widget.weekDays.indexWhere((x) =>
        x.year == _selectedDay.year &&
        x.month == _selectedDay.month &&
        x.day == _selectedDay.day);
    if (idx == -1) return;

    final next = widget.weekDays[(idx + 1) % widget.weekDays.length];
    setState(() {
      _selectedDay = next;
      _type = MealType.lunch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final query = _q.text.trim().toLowerCase();

    final mustChooseCategory = _cat == null;

    final filtered = mustChooseCategory
        ? <Recipe>[]
        : widget.recipes.where((r) {
            if (r.category != _cat) return false;
            if (query.isEmpty) return true;
            return r.title.toLowerCase().contains(query);
          }).toList();

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
            initialChildSize: 0.88,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(8),
                children: [
                  Row(
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
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Entrée'),
                        selected: _cat == RecipeCategory.entree,
                        onSelected: (_) =>
                            setState(() => _cat = RecipeCategory.entree),
                      ),
                      ChoiceChip(
                        label: const Text('Plat'),
                        selected: _cat == RecipeCategory.plat,
                        onSelected: (_) =>
                            setState(() => _cat = RecipeCategory.plat),
                      ),
                      ChoiceChip(
                        label: const Text('Dessert'),
                        selected: _cat == RecipeCategory.dessert,
                        onSelected: (_) =>
                            setState(() => _cat = RecipeCategory.dessert),
                      ),
                      ChoiceChip(
                        label: const Text('Boisson'),
                        selected: _cat == RecipeCategory.boisson,
                        onSelected: (_) =>
                            setState(() => _cat = RecipeCategory.boisson),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final d in widget.weekDays) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_dayChipLabel(d)),
                              selected: d.year == _selectedDay.year &&
                                  d.month == _selectedDay.month &&
                                  d.day == _selectedDay.day,
                              onSelected: (_) =>
                                  setState(() => _selectedDay = d),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Déjeuner'),
                        selected: _type == MealType.lunch,
                        onSelected: (_) =>
                            setState(() => _type = MealType.lunch),
                      ),
                      ChoiceChip(
                        label: const Text('Dîner'),
                        selected: _type == MealType.dinner,
                        onSelected: (_) =>
                            setState(() => _type = MealType.dinner),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
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
                          onPressed: _persons <= 1
                              ? null
                              : () => setState(() => _persons -= 1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_persons',
                            style: Theme.of(context).textTheme.titleMedium),
                        IconButton(
                          onPressed: _persons >= 24
                              ? null
                              : () => setState(() => _persons += 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ajout sur : ${_dayHuman(_selectedDay)} • ${_type == MealType.lunch ? 'Déjeuner' : 'Dîner'}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _validateDay,
                        child: const Text('Valider la journée'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (mustChooseCategory)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Choisis une catégorie (Entrée / Plat / Dessert / Boisson) pour afficher les recettes.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Aucune recette trouvée',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...filtered.map(
                      (r) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.restaurant),
                          title: Text(r.title),
                          subtitle: r.category == null
                              ? null
                              : Text(r.category.toString().split('.').last),
                          trailing: const Icon(Icons.add),
                          onTap: () async {
                            await widget.onAdd(
                              _selectedDay,
                              PlannedMeal(
                                recipe: r,
                                persons: _persons,
                                type: _type,
                                customLabel: null,
                              ),
                            );

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Ajouté : ${r.title} • ${_dayHuman(_selectedDay)}'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(milliseconds: 900),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
