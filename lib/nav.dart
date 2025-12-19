import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recette_magique/services/backend_config.dart';
import 'package:recette_magique/screens/auth/login_screen.dart';
import 'package:recette_magique/screens/auth/register_screen.dart';
import 'package:recette_magique/screens/home/home_screen.dart';
import 'package:recette_magique/screens/scan/scan_screen.dart';
import 'package:recette_magique/screens/recipe/recipe_detail_screen.dart';
import 'package:recette_magique/services/recipe_service.dart';

/// Configuration de la navigation avec go_router
class AppRouter {
  /// Construit dynamiquement le routeur afin de lire l'état backend.
  static GoRouter buildRouter() {
    final hasBackend = BackendConfig.firebaseReady;

    return GoRouter(
      initialLocation: hasBackend ? AppRoutes.login : AppRoutes.home,
      redirect: (context, state) {
        if (!hasBackend) return null; // Pas de checks d'auth sans backend

        final user = FirebaseAuth.instance.currentUser;
        final isLoggedIn = user != null;
        final isLoginPage = state.matchedLocation == AppRoutes.login;
        final isRegisterPage = state.matchedLocation == AppRoutes.register;

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
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const LoginScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.register,
          name: 'register',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const RegisterScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.scan,
          name: 'scan',
          pageBuilder: (context, state) => const MaterialPage(
            child: ScanScreen(),
          ),
        ),
        GoRoute(
          path: '${AppRoutes.recipeDetail}/:id',
          name: 'recipe-detail',
          pageBuilder: (context, state) {
            final recipeId = state.pathParameters['id']!;
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
                      body: const Center(child: Text('Recette non trouvée')),
                    );
                  }
                  return RecipeDetailScreen(recipe: snapshot.data!);
                },
              ),
            );
          },
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
  static const String recipeDetail = '/recipe';
}
