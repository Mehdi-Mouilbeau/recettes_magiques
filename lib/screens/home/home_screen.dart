// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:recette_magique/providers/ingredients_provider.dart';

import 'home_controller.dart';
import 'widgets/home_background.dart';
import 'widgets/home_top_panel.dart';
import 'widgets/ingredients_chips.dart';
import 'widgets/recipes_section.dart';

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
    final ingProv = context.watch<IngredientsProvider>();
    final recipes = c.visibleRecipes(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const HomeBackground(),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                    child: SizedBox(height: HomeTopPanel.height)),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: IngredientsChips(
                    onDelete: (it) => c.removeItem(context, it),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                RecipesSection(
                  controller: c,
                  recipes: recipes,
                  ingProv: ingProv,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          ),

          HomeTopPanel(controller: c),
        ],
      ),
    );
  }
}
