import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:recette_magique/screens/shopping/shooping_home_screen.dart';

import 'package:recette_magique/services/backend_config.dart';
import 'package:recette_magique/screens/auth/login_screen.dart';
import 'package:recette_magique/screens/auth/register_screen.dart';
import 'package:recette_magique/screens/home/home_screen.dart';
import 'package:recette_magique/screens/scan/scan_screen.dart';
import 'package:recette_magique/screens/recipe/recipe_detail_screen.dart';
import 'package:recette_magique/services/recipe_service.dart';
import 'package:recette_magique/screens/shopping/shopping_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/providers/leftovers_provider.dart';
import 'package:recette_magique/providers/auth_provider.dart' as app_auth;
import 'package:recette_magique/theme.dart';
import 'package:recette_magique/widgets/recipe_card.dart';

/// Configuration de la navigation avec go_router
class AppRouter {
  /// Construit dynamiquement le routeur afin de lire l'état backend.
  /// On accepte un [FirebaseAnalyticsObserver] optionnel pour tracker les screens.
  static GoRouter buildRouter({FirebaseAnalyticsObserver? analyticsObserver}) {
    final hasBackend = BackendConfig.firebaseReady;

    return GoRouter(
      // ✅ Injecte l'observer Analytics si fourni
      observers: [
        if (analyticsObserver != null) analyticsObserver,
      ],

      initialLocation: hasBackend ? AppRoutes.login : AppRoutes.home,

      redirect: (context, state) {
        if (!hasBackend) return null; // Pas de checks d'auth sans backend

        final user = FirebaseAuth.instance.currentUser;
        final isLoggedIn = user != null;

        final loc = state.matchedLocation;
        final isLoginPage = loc == AppRoutes.login;
        final isRegisterPage = loc == AppRoutes.register;

        // Rediriger vers login si non connecté
        if (!isLoggedIn && !isLoginPage && !isRegisterPage) {
          return AppRoutes.login;
        }

        // Rediriger vers home si déjà connecté
        if (isLoggedIn && (isLoginPage || isRegisterPage)) {
          return AppRoutes.home;
        }

        return null;
      },

      routes: [
        // Auth routes (no bottom navigation)
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen()),
        ),
        GoRoute(
          path: AppRoutes.register,
          name: 'register',
          pageBuilder: (context, state) => const NoTransitionPage(child: RegisterScreen()),
        ),

        // Shell with BottomNavigationBar
        ShellRoute(
          builder: (context, state, child) => _RootShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
            ),
            GoRoute(
              path: AppRoutes.scan,
              name: 'scan',
              pageBuilder: (context, state) => const NoTransitionPage(child: ScanScreen()),
            ),
            GoRoute(
              path: AppRoutes.courses,
              name: 'courses',
              pageBuilder: (context, state) => const NoTransitionPage(child: ShoppingHomeScreen()),
            ),
            GoRoute(
              path: AppRoutes.leftovers,
              name: 'leftovers',
              pageBuilder: (context, state) => NoTransitionPage(child: _LeftoversPage()),
            ),
            // Detail pages inside shell (keep bottom nav visible)
            GoRoute(
              path: '${AppRoutes.recipeDetail}/:id',
              name: 'recipe-detail',
              pageBuilder: (context, state) {
                final recipeId = state.pathParameters['id'];
                if (recipeId == null || recipeId.isEmpty) {
                  return const MaterialPage(
                    child: Scaffold(body: Center(child: Text('ID de recette manquant'))),
                  );
                }
                if (!hasBackend) {
                  return const MaterialPage(
                    child: Scaffold(
                      body: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Connectez Firebase via le panneau Dreamflow pour accéder aux recettes.', textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  );
                }
                return MaterialPage(
                  child: FutureBuilder(
                    future: RecipeService().getRecipe(recipeId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(body: Center(child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return Scaffold(appBar: AppBar(), body: const Center(child: Text('Recette non trouvée')));
                      }
                      return RecipeDetailScreen(recipe: snapshot.data!);
                    },
                  ),
                );
              },
            ),
            GoRoute(
              path: AppRoutes.shopping,
              name: 'shopping',
              pageBuilder: (context, state) {
                final extra = state.extra;
                if (extra is! ShoppingListArgs) {
                  return const MaterialPage(
                    child: Scaffold(body: Center(child: Text('Arguments invalides'))),
                  );
                }
                return MaterialPage(child: ShoppingListScreen(args: extra));
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Constantes de routes
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String scan = '/scan';
  static const String shopping = '/shopping';
  static const String recipeDetail = '/recipe';
  static const String courses = '/courses';
  static const String leftovers = '/leftovers';
}

/// Root shell scaffold with BottomNavigationBar
class _RootShell extends StatelessWidget {
  final Widget child;
  const _RootShell({required this.child});

  int _indexForLocation(String loc) {
    if (loc.startsWith(AppRoutes.scan)) return 1;
    if (loc.startsWith(AppRoutes.courses)) return 2;
    if (loc.startsWith(AppRoutes.leftovers)) return 3;
    return 0; // home
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.scan);
        break;
      case 2:
        context.go(AppRoutes.courses);
        break;
      case 3:
        context.go(AppRoutes.leftovers);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final current = _indexForLocation(loc);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Recettes'),
          NavigationDestination(icon: Icon(Icons.document_scanner_outlined), selectedIcon: Icon(Icons.document_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.kitchen_outlined), selectedIcon: Icon(Icons.kitchen), label: 'Restes'),
        ],
      ),
    );
  }
}

// Inline leftovers page to avoid import issues
class _LeftoversPage extends StatefulWidget {
  @override
  State<_LeftoversPage> createState() => _LeftoversPageState();
}

class _LeftoversPageState extends State<_LeftoversPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<app_auth.AuthProvider?>();
    if (auth?.currentUser != null) {
      final prov = context.read<LeftoversProvider>();
      prov.load(auth!.currentUser!.uid).then((_) => prov.fetchSuggestions(auth.currentUser!.uid));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addItem() {
    final prov = context.read<LeftoversProvider>();
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final list = [...prov.leftovers];
    for (final token in raw.split(RegExp(r'[;,\n]'))) {
      final t = token.trim();
      if (t.isNotEmpty && !list.contains(t)) list.add(t);
    }
    prov.setLocal(list);
    _controller.clear();
  }

  Future<void> _save() async {
    final auth = context.read<app_auth.AuthProvider?>();
    if (auth?.currentUser == null) return;
    final ok = await context.read<LeftoversProvider>().save(auth!.currentUser!.uid, context.read<LeftoversProvider>().leftovers);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restes enregistrés')));
      await context.read<LeftoversProvider>().fetchSuggestions(auth.currentUser!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LeftoversProvider>();
    final items = prov.leftovers;
    final suggested = prov.suggestions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes restes'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.save_alt, color: Colors.blue))],
      ),
      body: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ajouter un ingrédient (tomates, carottes...)',
                prefixIcon: const Icon(Icons.add),
                suffixIcon: IconButton(onPressed: _addItem, icon: const Icon(Icons.check_circle, color: Colors.green)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
              onSubmitted: (_) => _addItem(),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final it in items)
                  Chip(
                    label: Text(it),
                    onDeleted: () {
                      final list = [...items]..remove(it);
                      prov.setLocal(list);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Recettes suggérées', style: Theme.of(context).textTheme.titleLarge?.bold),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: prov.isLoadingSuggestions
                  ? const Center(child: CircularProgressIndicator())
                  : suggested.isEmpty
                      ? Center(
                          child: Text(
                            'Aucune suggestion pour l’instant',
                            style: Theme.of(context).textTheme.bodyMedium?.withColor(
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: suggested.length,
                          padding: const EdgeInsets.only(top: 0),
                          itemBuilder: (context, index) {
                            final r = suggested[index];
                            return RecipeCard(
                              recipe: r,
                              onTap: () => context.push('${AppRoutes.recipeDetail}/${r.id}'),
                            );
                          },
                        ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
