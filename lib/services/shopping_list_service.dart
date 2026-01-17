import 'package:flutter/foundation.dart';
import 'package:recette_magique/models/recipe_model.dart';

/// Représente un ingrédient analysé depuis une ligne de texte
/// Exemple: "200 g de farine" -> amount=200, unit=g, name=farine
@immutable
class ParsedIngredient {
  final String name; // nom normalisé pour l'agrégation (sans articles, accents)
  final String displayName; // nom pour affichage
  final double? amount;
  final String?
      unit; // unités de base: g, ml, pcs (ou null si non quantifiable)
  final bool approximated;
  const ParsedIngredient({
    required this.name,
    required this.displayName,
    this.amount,
    this.unit,
    this.approximated = false,
  });
}

/// Élément agrégé pour la liste de courses
@immutable
class AggregatedIngredient {
  final String name; // nom d'affichage (propre)
  final double? totalAmount; // somme dans l'unité normalisée
  final String? unit; // g | ml | pcs | null
  final int occurrences; // nombre de lignes agrégées
  const AggregatedIngredient({
    required this.name,
    required this.totalAmount,
    required this.unit,
    required this.occurrences,
  });
}

/// Modèles et service pour générer une liste de courses à partir de recettes
class ShoppingListService {
  /// Génère la liste de courses agrégée
  /// - [recipes] recettes sélectionnées
  /// - [personsByRecipe] nombre de personnes souhaité par recette (par id)
  /// Si recipe.servings est connu, on applique un facteur d'échelle spécifique, sinon on garde tel quel
  List<AggregatedIngredient> buildShoppingList({
    required List<Recipe> recipes,
    required Map<String, int> personsByRecipe,
  }) {
    final Map<String, _AggBucket> buckets = {};

    for (final r in recipes) {
      final id = r.id;
      final desiredPersons = id != null ? personsByRecipe[id] : null;
      final factor =
          (desiredPersons != null && r.servings != null && r.servings! > 0)
              ? desiredPersons / r.servings!.toDouble()
              : 1.0;
      for (final line in r.ingredients) {
        final parsed = _parseLine(line);
        if (parsed == null) {
          // Utiliser la ligne brute non quantifiable
          final key = _normalize(line);
          final b = buckets.putIfAbsent(
              key, () => _AggBucket(name: _cleanDisplay(line)));
          b.occurrences += 1;
          continue;
        }

        double? amount = parsed.amount != null ? parsed.amount! * factor : null;
        String? unit = parsed.unit;

        final key = _normalize(
            parsed.name.isNotEmpty ? parsed.name : parsed.displayName);
        final b = buckets.putIfAbsent(
            key, () => _AggBucket(name: parsed.displayName, unit: unit));

        // Unifier unités si déjà existantes
        if (b.unit != null && unit != null && b.unit != unit) {
          // Tenter une conversion simple entre g/kg/ml/l/cl
          final converted = _tryConvert(amount, unit, b.unit!);
          if (converted.converted) {
            amount = converted.amount;
            unit = converted.toUnit;
          } else {
            // Conflit d'unités non convertible -> on perd l'agrégation quantitative, garder occurrences
            amount = null;
            unit = null;
            b.unit = null;
          }
        }

        if (amount != null) b.totalAmount = (b.totalAmount ?? 0) + amount;
        b.unit ??= unit; // peut rester null volontairement
        b.occurrences += 1;
      }
    }

    final list = buckets.values.map((b) => AggregatedIngredient(
          name: b.name,
          totalAmount: b.totalAmount != null
              ? _roundQuantity(b.totalAmount!, b.unit)
              : null,
          unit: b.unit,
          occurrences: b.occurrences,
        ));

    final sorted = list.toList()..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  // --- Internals ---

  static double _roundQuantity(double v, String? unit) {
    final u = unit?.toLowerCase().trim();

    if (u == 'pcs' || u == 'l' || u == 'kg') {
      return v.ceilToDouble();
    }

    if (v < 1) return double.parse(v.toStringAsFixed(2));
    if (v < 10) return double.parse(v.toStringAsFixed(1));
    return v.roundToDouble();
  }

  static String _cleanDisplay(String line) {
    return line.trim().replaceAll(RegExp(r'^[•\-\s]+'), '');
  }

  static String _normalize(String input) {
    final lower = input.toLowerCase().trim();
    final deacc = lower
        .replaceAll(RegExp('[àáâäãå]'), 'a')
        .replaceAll(RegExp('[ç]'), 'c')
        .replaceAll(RegExp('[èéêë]'), 'e')
        .replaceAll(RegExp('[ìíîï]'), 'i')
        .replaceAll(RegExp('[ñ]'), 'n')
        .replaceAll(RegExp('[òóôöõ]'), 'o')
        .replaceAll(RegExp('[ùúûü]'), 'u')
        .replaceAll(RegExp('[ýÿ]'), 'y');
    final noArticles = deacc
        .replaceAll(RegExp(r"\b(d'|d’|de|du|des|la|le|les)\b"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Retirer parenthèses et contenu
    final noParen = noArticles.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    return noParen;
  }

  static String _normalizeUnit(String unit) {
    final u = unit.toLowerCase().replaceAll('.', '').trim();
    switch (u) {
      case 'kg':
      case 'kilogramme':
      case 'kilogrammes':
        return 'kg';
      case 'g':
      case 'gr':
      case 'gramme':
      case 'grammes':
        return 'g';
      case 'l':
      case 'litre':
      case 'litres':
        return 'l';
      case 'cl':
        return 'cl';
      case 'ml':
        return 'ml';
      case 'cas':
      case 'cs':
      case 'càs':
      case 'cuillereasoupe':
      case 'cuillereasoupes':
      case 'cuillereasoups':
      case 'cuillere':
      case 'cuilleres':
      case 'cuilleresoupe':
        return 'càs';
      case 'cac':
      case 'cc':
      case 'càc':
      case 'cuillereacafe':
      case 'cuilleresacafe':
        return 'càc';
      case 'tasse':
      case 'tasses':
      case 'cup':
      case 'cups':
        return 'tasse';
      case 'pincee':
      case 'pincees':
        return 'pincée';
      case 'gousse':
      case 'gousses':
      case 'piece':
      case 'pieces':
      case 'pcs':
      case 'oeuf':
      case 'oeufs':
      case 'unite':
      case 'unites':
        return 'pcs';
      default:
        return u; // inconnu
    }
  }

  static (_Conv, {bool converted, double? amount, String? toUnit}) _tryConvert(
      double? amount, String? from, String to) {
    if (amount == null || from == null) {
      return (_Conv(), converted: false, amount: amount, toUnit: to);
    }
    final f = _normalizeUnit(from);
    final t = _normalizeUnit(to);
    double a = amount;
    if (f == t) return (_Conv(), converted: true, amount: a, toUnit: t);
    // Poids
    if (f == 'kg' && t == 'g')
      return (_Conv(), converted: true, amount: a * 1000, toUnit: 'g');
    if (f == 'g' && t == 'kg')
      return (_Conv(), converted: true, amount: a / 1000, toUnit: 'kg');
    // Volume
    if (f == 'l' && t == 'ml')
      return (_Conv(), converted: true, amount: a * 1000, toUnit: 'ml');
    if (f == 'ml' && t == 'l')
      return (_Conv(), converted: true, amount: a / 1000, toUnit: 'l');
    if (f == 'cl' && t == 'ml')
      return (_Conv(), converted: true, amount: a * 10, toUnit: 'ml');
    if (f == 'ml' && t == 'cl')
      return (_Conv(), converted: true, amount: a / 10, toUnit: 'cl');
    // Cuillères (approximation vers ml)
    if (f == 'càs' && t == 'ml')
      return (_Conv(), converted: true, amount: a * 15, toUnit: 'ml');
    if (f == 'càc' && t == 'ml')
      return (_Conv(), converted: true, amount: a * 5, toUnit: 'ml');
    if (f == 'tasse' && t == 'ml')
      return (_Conv(), converted: true, amount: a * 240, toUnit: 'ml');
    // Réciproque
    if (f == 'ml' && t == 'càs')
      return (_Conv(), converted: true, amount: a / 15, toUnit: 'càs');
    if (f == 'ml' && t == 'càc')
      return (_Conv(), converted: true, amount: a / 5, toUnit: 'càc');
    if (f == 'ml' && t == 'tasse')
      return (_Conv(), converted: true, amount: a / 240, toUnit: 'tasse');
    // Pièces ne sont pas convertibles
    return (_Conv(), converted: false, amount: a, toUnit: t);
  }

  static double? _parseNumber(String s) {
    s = s.trim();
    // fractions Unicode
    s = s
        .replaceAll('½', '1/2')
        .replaceAll('¼', '1/4')
        .replaceAll('¾', '3/4')
        .replaceAll('⅓', '1/3')
        .replaceAll('⅔', '2/3')
        .replaceAll('⅛', '1/8')
        .replaceAll('⅜', '3/8')
        .replaceAll('⅝', '5/8')
        .replaceAll('⅞', '7/8');
    // 1/2 -> 0.5
    final frac = RegExp(r'^(\d+)\/(\d+)?').firstMatch(s);
    final fm = RegExp(r'^(\d+)/(\d+)').firstMatch(s);
    if (fm != null) {
      final num = double.tryParse(fm.group(1)!);
      final den = double.tryParse(fm.group(2)!);
      if (num != null && den != null && den != 0) return num / den;
    }
    // nombres décimaux (virgule ou point)
    s = s.replaceAll(',', '.');
    return double.tryParse(RegExp(r'^(\d+(?:\.\d+)?)').stringMatch(s) ?? '');
  }

  static ParsedIngredient? _parseLine(String line) {
    final raw = line.trim();
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'^[•\-\s]+'), '');
    // Chercher un nombre au début
    final numMatch =
        RegExp(r'^(environ\s+|env\.\s+|~\s+)?([^a-zA-Z]*)').firstMatch(cleaned);
    double? qty;
    String rest = cleaned;
    if (numMatch != null) {
      final prefix = numMatch.group(2) ?? '';
      final num = _parseNumber(prefix.trim());
      if (num != null) {
        qty = num;
        rest = cleaned.substring(prefix.length).trim();
      }
    }

    // Unité potentielle (le premier token)
    String? unit;
    if (qty != null) {
      final unitMatch =
          RegExp(r'^(\w+|[a-zA-Zéèàêëîïôöûüç]+\.?)').firstMatch(rest);
      if (unitMatch != null) {
        final u = unitMatch.group(0) ?? '';
        final normalizedU = _normalizeUnit(u);
        // si c'est une unité plausible, la garder et retirer du reste
        if ({'kg', 'g', 'l', 'ml', 'cl', 'càs', 'càc', 'tasse', 'pcs', 'pincée'}
            .contains(normalizedU)) {
          unit = normalizedU;
          rest = rest.substring(u.length).trim();
        }
      }
    }

    // supprimer articles de liaison
    rest = rest.replaceAll(RegExp(r"^(d'|d’|de|du|des|la|le|les)\s+"), '');
    // retirer parenthèses explicatives
    rest = rest.replaceAll(RegExp(r'\(.*?\)'), '').trim();

    // Si aucune quantité trouvée, essayez formats "2 tomates"
    if (qty == null) {
      final fm = RegExp(r'^(\d+(?:[\.,]\d+)?|\d+/\d+)\s+(.*)').firstMatch(rest);
      if (fm != null) {
        qty = _parseNumber(fm.group(1)!.replaceAll(',', '.'));
        rest = (fm.group(2) ?? '').trim();
        unit ??= 'pcs';
      }
    }

    // rest est le nom d'ingrédient pour affichage
    final display = _toDisplayCase(rest);
    final name = _normalize(rest);

    return ParsedIngredient(
      name: name,
      displayName: display.isEmpty ? _cleanDisplay(line) : display,
      amount: qty,
      unit: unit,
      approximated: false,
    );
  }

  static String _toDisplayCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _AggBucket {
  final String name;
  double? totalAmount;
  String? unit;
  int occurrences = 0;
  _AggBucket({required this.name, this.unit});
}

class _Conv {}
