import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// --------------------
/// Spacing / Radius
/// --------------------
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;

  // spécifiques maquette
  static const double pill = 999.0;
  static const double sheet = 40.0;
}

/// --------------------
/// Extensions texte
/// --------------------
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

/// --------------------
/// Couleurs du design (nouvelle charte)
/// --------------------
class AppColors {
  // Fonds
  static const Color bgTop1 = Color(0xFFCFE2B8);
  static const Color bg = Color(0xFFC6D9AE);

  static const Color bgTop = Color(0xFFBAD4AA);
  static const Color bgBottom = Color(0xFFE0E0C7);

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      bgTop,
      bgBottom,
    ],
  );

  // Surfaces
  static const Color card = Color(0xFFF1F5CF);
  static const Color tile = Color(0xFFE7EFD7);
  static const Color pill = Color(0xFFF7F9DE);

  // Texte
  static const Color text = Color(0xFF1E2D14);
  static const Color textMuted = Color(0xFF5B6B45);

  // Accents
  static const Color accent = Color(0xFFFFA000); // bouton orange
  static const Color control = Color(0xFFFFE07A); // boutons +/-
  static const Color chipIngredients = Color(0xFFFFD68A);
  static const Color chipTime = Color(0xFFEACBFF);

  // Boutons ronds sur image
  static const Color roundButton = Color(0xFF8AA06B);

  // Utilitaires
  static const Color shadow = Color(0x22000000);
  static const Color border = Color(0x1A000000);
}

/// --------------------
/// Typo (centralisée)
/// --------------------
class AppTextStyles {
  // “CACA COOK / RECETTE MAGIQUE” style (fin + letter spacing)
  static TextStyle brandTitle() => GoogleFonts.inter(
        fontSize: 34,
        letterSpacing: 2,
        fontWeight: FontWeight.w300,
        color: AppColors.text,
      );

  static TextStyle sectionTitle() => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: AppColors.text,
      );

  static TextStyle cardTitle() => GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      );

  static TextStyle chip() => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      );

  static TextStyle body() => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
      );

  static TextStyle muted() => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      );
}

/// --------------------
/// ThemeData unique (pas de dark mode)
/// --------------------
ThemeData get appTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,

      colorScheme: const ColorScheme.light(
        primary: AppColors.roundButton, // utilisé pour certains widgets M3
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: AppColors.text,
        surface: AppColors.card,
        onSurface: AppColors.text,
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
      ),

      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.text,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),

      // Card global
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      // Champs / inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.tile,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),

      // Boutons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
          elevation: 8,
          shadowColor: Colors.black26,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
        ),
      ),

      // NavigationBar (si tu utilises NavigationBar M3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.tile.withOpacity(0.70),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
