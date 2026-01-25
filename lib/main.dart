import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:recette_magique/providers/agenda_provider.dart';
import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/ingredients_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/shopping_profider.dart';

import 'package:recette_magique/services/backend_config.dart';
import 'package:recette_magique/theme.dart';

import 'nav.dart';

void main() {
  // Lancement ultra-rapide sans initialisation
  runApp(const AppInitializer());
}

/// Widget qui gère l'initialisation asynchrone
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialisation Firebase
      await Firebase.initializeApp();
      BackendConfig.firebaseReady = true;

      // Analytics en arrière-plan (non bloquant)
      FirebaseAnalytics.instance.logEvent(name: 'app_started').catchError((e) {
        debugPrint('Analytics error: $e');
      });

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      BackendConfig.firebaseReady = false;
      setState(() {
        _error = true;
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _SplashScreen(),
      );
    }

    return const MyApp();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.bgGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/mascotte.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              Text(
                'Recettes',
                style: AppTextStyles.brandRecettes(),
              ),
              const SizedBox(height: 8),
              Text(
                'dans ma poche',
                style: AppTextStyles.brandSubtitle(),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final analytics = FirebaseAnalytics.instance;
    final FirebaseAnalyticsObserver analyticsObserver =
        FirebaseAnalyticsObserver(analytics: analytics);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => RecipeProvider(), lazy: true),
        ChangeNotifierProvider(
            create: (_) => IngredientsProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => ShoppingProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => AgendaProvider(), lazy: true),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: 'RECETTES Dans Ta Poche',
            debugShowCheckedModeBanner: false,
            routerConfig: AppRouter.buildRouter(
              analyticsObserver: analyticsObserver,
            ),
            builder: (context, child) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.bgGradient,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: child!,
                ),
              );
            },
          );
        },
      ),
    );
  }
}