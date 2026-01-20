import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:recette_magique/models/recipe_model.dart';

@immutable
class ParsedIngredient {
  final String name;
  final String displayName;
  final double? amount;
  final String? unit;
  const ParsedIngredient({
    required this.name,
    required this.displayName,
    this.amount,
    this.unit,
  });
}

@immutable
class AggregatedIngredient {
  final String name;
  final double? totalAmount;
  final String? unit;
  final int occurrences;
  const AggregatedIngredient({
    required this.name,
    required this.totalAmount,
    required this.unit,
    required this.occurrences,
  });
}

class ShoppingListService {
  List<AggregatedIngredient> buildShoppingList({
    required List<Recipe> recipes,
    required Map<String, int> personsByRecipe,
  }) {
    final Map<String, _AggBucket> buckets = {};

    for (final r in recipes) {
      final id = r.id;
      final desiredPersons = id != null ? personsByRecipe[id] : null;
      final factor = (desiredPersons != null && r.servings != null && r.servings! > 0)
          ? desiredPersons / r.servings!.toDouble()
          : 1.0;

      for (final line in r.ingredients) {
        final parsed = _parseLine(line);
        if (parsed == null) {
          final key = _normalize(line);
          final b = buckets.putIfAbsent(key, () => _AggBucket(name: _cleanDisplay(line)));
          b.occurrences += 1;
          continue;
        }

        final key = _normalize(parsed.name.isNotEmpty ? parsed.name : parsed.displayName);
        final b = buckets.putIfAbsent(
          key,
          () => _AggBucket(name: parsed.displayName, unit: parsed.unit),
        );

        final isApproxUnit = _isApproxUnit(parsed.unit);
        if (isApproxUnit) {
          b.unit = null;
          b.totalAmount = null;
          b.occurrences += 1;
          continue;
        }

        double? amount = parsed.amount != null ? parsed.amount! * factor : null;
        String? unit = parsed.unit;

        if (b.unit != null && unit != null && b.unit != unit) {
          final converted = _tryConvert(amount, unit, b.unit!);
          if (converted.converted) {
            amount = converted.amount;
            unit = converted.toUnit;
          } else {
            amount = null;
            unit = null;
            b.unit = null;
            b.totalAmount = null;
          }
        }

        if (amount != null && unit != null && b.unit != null) {
          b.totalAmount = (b.totalAmount ?? 0) + amount;
        } else {
          b.totalAmount = null;
          b.unit = null;
        }

        b.occurrences += 1;
      }
    }

    final list = buckets.values.map(
      (b) => AggregatedIngredient(
        name: b.name,
        totalAmount: b.totalAmount != null ? _roundQuantity(b.totalAmount!, b.unit) : null,
        unit: b.unit,
        occurrences: b.occurrences,
      ),
    );

    final sorted = list.toList()..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  static bool _isApproxUnit(String? unit) {
    final u = unit?.toLowerCase().trim();
    return u == 'càs' || u == 'càc' || u == 'tasse' || u == 'pincée';
  }

  static double _roundQuantity(double v, String? unit) {
    final u = unit?.toLowerCase().trim();
    if (u == 'pcs' || u == 'l' || u == 'kg') return v.ceilToDouble();
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

    var s = deacc
        .replaceAll(RegExp(r'\(.*?\)'), ' ')
        .replaceAll(RegExp(r"\b(d'|d’|de|du|des|la|le|les|un|une)\b"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    s = s.replaceAll(RegExp(r'\b(rouge|rouges|vert|verts|verte|vertes|jaune|jaunes|noir|noirs|blanc|blancs)\b'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    final words = s.split(' ');
    final normalizedWords = <String>[];

    for (final w in words) {
      var t = w.trim();
      if (t.isEmpty) continue;
      if (t.length > 3 && t.endsWith('s')) t = t.substring(0, t.length - 1);
      normalizedWords.add(t);
    }

    return normalizedWords.join(' ').trim();
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
      case 'brin':
      case 'brins':
        return 'pcs';
      default:
        return u;
    }
  }

  static (_Conv, {bool converted, double? amount, String? toUnit}) _tryConvert(
    double? amount,
    String? from,
    String to,
  ) {
    if (amount == null || from == null) {
      return (_Conv(), converted: false, amount: amount, toUnit: to);
    }
    final f = _normalizeUnit(from);
    final t = _normalizeUnit(to);
    double a = amount;
    if (f == t) return (_Conv(), converted: true, amount: a, toUnit: t);

    if (f == 'kg' && t == 'g') return (_Conv(), converted: true, amount: a * 1000, toUnit: 'g');
    if (f == 'g' && t == 'kg') return (_Conv(), converted: true, amount: a / 1000, toUnit: 'kg');

    if (f == 'l' && t == 'ml') return (_Conv(), converted: true, amount: a * 1000, toUnit: 'ml');
    if (f == 'ml' && t == 'l') return (_Conv(), converted: true, amount: a / 1000, toUnit: 'l');
    if (f == 'cl' && t == 'ml') return (_Conv(), converted: true, amount: a * 10, toUnit: 'ml');
    if (f == 'ml' && t == 'cl') return (_Conv(), converted: true, amount: a / 10, toUnit: 'cl');

    return (_Conv(), converted: false, amount: a, toUnit: t);
  }

  static double? _parseNumber(String s) {
    var x = s.trim();
    x = x
        .replaceAll('½', '1/2')
        .replaceAll('¼', '1/4')
        .replaceAll('¾', '3/4')
        .replaceAll('⅓', '1/3')
        .replaceAll('⅔', '2/3')
        .replaceAll('⅛', '1/8')
        .replaceAll('⅜', '3/8')
        .replaceAll('⅝', '5/8')
        .replaceAll('⅞', '7/8');

    final fm = RegExp(r'^(\d+)\/(\d+)$').firstMatch(x);
    if (fm != null) {
      final num = double.tryParse(fm.group(1)!);
      final den = double.tryParse(fm.group(2)!);
      if (num != null && den != null && den != 0) return num / den;
    }

    x = x.replaceAll(',', '.');
    return double.tryParse(x);
  }

  static ParsedIngredient? _parseLine(String line) {
    final raw = line.trim();
    if (raw.isEmpty) return null;

    var cleaned = raw.replaceAll(RegExp(r'^[•\-\s]+'), '').trim();

    final xForm = RegExp(r'^(.*?)\s+x\s+(\d+(?:[.,]\d+)?)\s*(\w+)?$', caseSensitive: false).firstMatch(cleaned);
    if (xForm != null) {
      final namePart = (xForm.group(1) ?? '').trim();
      final qty = _parseNumber((xForm.group(2) ?? '').trim());
      final unitToken = (xForm.group(3) ?? '').trim();
      final unit = unitToken.isEmpty ? 'pcs' : _normalizeUnit(unitToken);

      final name = _normalize(namePart);
      final display = _toDisplayCase(_stripArticles(namePart));
      if (display.isEmpty) return null;

      return ParsedIngredient(
        name: name,
        displayName: display,
        amount: qty,
        unit: unit.isEmpty ? 'pcs' : unit,
      );
    }

    final tailQty = RegExp(r'^(.*)\s(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|cl)$', caseSensitive: false).firstMatch(cleaned);
    if (tailQty != null) {
      final namePart = (tailQty.group(1) ?? '').trim();
      final qty = _parseNumber((tailQty.group(2) ?? '').trim());
      final unit = _normalizeUnit(tailQty.group(3) ?? '');

      final name = _normalize(namePart);
      final display = _toDisplayCase(_stripArticles(namePart));
      if (display.isEmpty) return null;

      return ParsedIngredient(
        name: name,
        displayName: display,
        amount: qty,
        unit: unit,
      );
    }

    final leadQty = RegExp(r'^(?:environ|env\.|~)?\s*(\d+(?:[.,]\d+)?|\d+/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])\s+(.*)$', caseSensitive: false)
        .firstMatch(cleaned);

    double? qty;
    String rest = cleaned;

    if (leadQty != null) {
      qty = _parseNumber((leadQty.group(1) ?? '').trim());
      rest = (leadQty.group(2) ?? '').trim();
    }

    String? unit;
    if (qty != null) {
      final unitMatch = RegExp(r'^([a-zA-Zéèàêëîïôöûüç\.]+)\s+(.*)$').firstMatch(rest);
      if (unitMatch != null) {
        final u = unitMatch.group(1) ?? '';
        final possible = _normalizeUnit(u);
        final after = (unitMatch.group(2) ?? '').trim();

        if ({
          'kg', 'g', 'l', 'ml', 'cl', 'càs', 'càc', 'tasse', 'pcs', 'pincée'
        }.contains(possible)) {
          unit = possible;
          rest = after;
        } else {
          unit = 'pcs';
        }
      } else {
        unit = 'pcs';
      }
    }

    rest = _stripArticles(rest);
    rest = rest.replaceAll(RegExp(r'\(.*?\)'), '').trim();

    if (rest.isEmpty) return null;

    final display = _toDisplayCase(rest);
    final name = _normalize(rest);

    if (display.isEmpty) return null;

    return ParsedIngredient(
      name: name,
      displayName: display,
      amount: qty,
      unit: unit,
    );
  }

  static String _stripArticles(String s) {
    var x = s.trim();
    x = x.replaceAll(RegExp(r"^(d'|d’|de|du|des|la|le|les)\s+"), '');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  static String _toDisplayCase(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
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
