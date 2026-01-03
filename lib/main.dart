import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/leftovers_provider.dart';
import 'package:recette_magique/providers/shooping_profider.dart';
import 'package:recette_magique/providers/theme_provider.dart';
import 'package:recette_magique/services/backend_config.dart';
import 'package:recette_magique/firebase_options.dart';

import 'theme.dart';
import 'nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;

    //  event test pour vérifier que ça remonte
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
    final FirebaseAnalyticsObserver analyticsObserver =
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => LeftoversProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ShoppingProvider()),
      ],
      child: Builder(builder: (context) {
        final themeMode = context.watch<ThemeProvider>().mode;
        return MaterialApp.router(
          title: 'Recette Magique',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          routerConfig: AppRouter.buildRouter(analyticsObserver: analyticsObserver),
        );
      }),
    );
  }
}
