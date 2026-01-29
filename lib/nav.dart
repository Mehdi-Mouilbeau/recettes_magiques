import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/observer.dart';

import 'package:recette_magique/services/backend_config.dart';
import 'package:recette_magique/services/recipe_service.dart';
import 'package:recette_magique/theme.dart';

import 'package:recette_magique/screens/auth/login/login_screen.dart';
import 'package:recette_magique/screens/auth/register/register_screen.dart';
import 'package:recette_magique/screens/home/home_screen.dart';
import 'package:recette_magique/screens/scan/scan_screen.dart';
import 'package:recette_magique/screens/recipe/recipe_detail_screen.dart';
import 'package:recette_magique/screens/shopping/shopping_home_screen.dart';
import 'package:recette_magique/screens/shopping/shopping_list_screen.dart';
import 'package:recette_magique/screens/agenda/agenda_screen.dart';
import 'package:recette_magique/screens/account/account_screen.dart';

import 'package:recette_magique/screens/cgu/legal_screen.dart';

class AppRouter {
  static GoRouter buildRouter({FirebaseAnalyticsObserver? analyticsObserver}) {
    final hasBackend = BackendConfig.firebaseReady;
    final rootNavigatorKey = GlobalKey<NavigatorState>();

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: hasBackend ? AppRoutes.login : AppRoutes.home,
      observers: [
        if (analyticsObserver != null) analyticsObserver,
      ],
      redirect: (context, state) {
        if (!hasBackend) return null;

        final user = FirebaseAuth.instance.currentUser;
        final isLoggedIn = user != null;

        final loc = state.matchedLocation;
        final isLoginPage = loc == AppRoutes.login;
        final isRegisterPage = loc == AppRoutes.register;

        final isLegalPage = loc == AppRoutes.legal;

        if (!isLoggedIn && !isLoginPage && !isRegisterPage && !isLegalPage) {
          return AppRoutes.login;
        }

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
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LoginScreen()),
        ),
        GoRoute(
          path: AppRoutes.register,
          name: 'register',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: RegisterScreen()),
        ),

        // Route CGU / Mentions / Privacy (accessible avant login)
        GoRoute(
          path: AppRoutes.legal,
          name: 'legal',
          pageBuilder: (context, state) =>
              const MaterialPage(child: LegalScreen()),
        ),

        // Shell with BottomNavigationBar
        ShellRoute(
          builder: (context, state, child) => _RootShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
            GoRoute(
              path: AppRoutes.scan,
              name: 'scan',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ScanScreen()),
            ),
            GoRoute(
              path: AppRoutes.courses,
              name: 'courses',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ShoppingHomeScreen()),
            ),
            GoRoute(
              path: AppRoutes.agenda,
              name: 'agenda',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AgendaScreen()),
            ),

            // Account dans le shell (garde la bottom bar)
            GoRoute(
              path: AppRoutes.account,
              name: 'account',
              pageBuilder: (context, state) =>
                  const MaterialPage(child: AccountScreen()),
            ),

            GoRoute(
              path: '${AppRoutes.recipeDetail}/:id',
              name: 'recipe-detail',
              pageBuilder: (context, state) {
                final recipeId = state.pathParameters['id'];
                if (recipeId == null || recipeId.isEmpty) {
                  return const MaterialPage(
                    child: Scaffold(
                      body: Center(child: Text('ID de recette manquant')),
                    ),
                  );
                }

                if (!hasBackend) {
                  return const MaterialPage(
                    child: Scaffold(
                      body: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Connectez Firebase via le panneau Dreamflow pour accéder aux recettes.',
                            textAlign: TextAlign.center,
                          ),
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
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return Scaffold(
                          appBar: AppBar(),
                          body:
                              const Center(child: Text('Recette non trouvée')),
                        );
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
                    child: Scaffold(
                      body: Center(child: Text('Arguments invalides')),
                    ),
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

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';

  static const String home = '/home';
  static const String scan = '/scan';
  static const String shopping = '/shopping';
  static const String recipeDetail = '/recipe';
  static const String courses = '/courses';
  static const String agenda = '/agenda';

  static const String account = '/account';

  static const String legal = '/legal';
}

class _RootShell extends StatelessWidget {
  final Widget child;
  const _RootShell({required this.child});

  int _indexForLocation(String loc) {
    if (loc.startsWith(AppRoutes.scan)) return 1;
    if (loc.startsWith(AppRoutes.courses)) return 2;
    if (loc.startsWith(AppRoutes.agenda)) return 3;
    return 0;
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
        context.go(AppRoutes.agenda);
        break;
    }
  }

  /// Chip icône + texte avec fond quand sélectionné
  Widget _navItem({
  required BuildContext context,
  required String asset,
  required String label,
  required bool selected,
}) {
  final bg = selected
      ? AppColors.primaryHeader
      : Colors.transparent;

  final fg = Colors.black;
      

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          asset,
          width: 22,
          height: 22,
          // si icônes monochromes :
          // color: fg,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: fg,
              ),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final current = _indexForLocation(loc);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,

                    selectedIndex: current,
                    onDestinationSelected: (i) => _onTap(context, i),

                    // IMPORTANT : on coupe l'indicator qui ne couvre que l'icône
                    indicatorColor: Colors.transparent,

                    // On affiche nous-mêmes le label dans le chip
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,

                    destinations: [
                      NavigationDestination(
                        icon: _navItem(
                          context: context,
                          asset: 'assets/icons/navicons/icon_toque.png',
                          label: 'Recettes',
                          selected: current == 0,
                        ),
                        label: 'Recettes',
                      ),
                      NavigationDestination(
                        icon: _navItem(
                          context: context,
                          asset: 'assets/icons/navicons/icon_scan.png',
                          label: 'Scan',
                          selected: current == 1,
                        ),
                        label: 'Scan',
                      ),
                      NavigationDestination(
                        icon: _navItem(
                          context: context,
                          asset: 'assets/icons/navicons/icon_courses.png',
                          label: 'Courses',
                          selected: current == 2,
                        ),
                        label: 'Courses',
                      ),
                      NavigationDestination(
                        icon: _navItem(
                          context: context,
                          asset: 'assets/icons/navicons/icon_agenda.png',
                          label: 'Agenda',
                          selected: current == 3,
                        ),
                        label: 'Agenda',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
