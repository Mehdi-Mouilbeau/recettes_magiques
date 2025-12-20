import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/providers/leftovers_provider.dart';
import 'package:recette_magique/services/backend_config.dart';
import 'package:recette_magique/firebase_options.dart';
import 'theme.dart';
import 'nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
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
    // Configuration des providers pour la gestion d'état
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => LeftoversProvider()),
      ],
      child: MaterialApp.router(
        title: 'Recette Magique',
        debugShowCheckedModeBanner: false,

        // Configuration du thème
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,

        // Configuration de la navigation
        routerConfig: AppRouter.buildRouter(),
      ),
    );
  }
}
