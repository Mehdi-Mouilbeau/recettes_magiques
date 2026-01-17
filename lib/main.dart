import 'package:flutter/foundation.dart';
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
import 'package:recette_magique/firebase_options.dart';
import 'package:recette_magique/theme.dart';

import 'nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }

    firebaseReady = true;
    await FirebaseAnalytics.instance.logEvent(name: 'app_started');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    firebaseReady = false;
  }

  BackendConfig.firebaseReady = firebaseReady;

  runApp(const MyApp());
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => IngredientsProvider()),
        ChangeNotifierProvider(create: (_) => ShoppingProvider()),
        ChangeNotifierProvider(create: (_) => AgendaProvider()),
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
