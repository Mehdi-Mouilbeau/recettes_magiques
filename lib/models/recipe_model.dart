import 'package:cloud_firestore/cloud_firestore.dart';

enum RecipeCategory {
  entree,
  plat,
  dessert,
  boisson;

  String get displayName {
    switch (this) {
      case RecipeCategory.entree:
        return 'Entrée';
      case RecipeCategory.plat:
        return 'Plat';
      case RecipeCategory.dessert:
        return 'Dessert';
      case RecipeCategory.boisson:
        return 'Boisson';
    }
  }

  static RecipeCategory fromString(String value) {
    String normalize(String s) {
      return s
          .toLowerCase()
          .trim()
          .replaceAll('é', 'e')
          .replaceAll('è', 'e')
          .replaceAll('ê', 'e')
          .replaceAll('à', 'a')
          .replaceAll('â', 'a')
          .replaceAll('ô', 'o')
          .replaceAll('î', 'i')
          .replaceAll('û', 'u')
          .replaceAll('ù', 'u')
          .replaceAll('ç', 'c');
    }

    final normalized = normalize(value);

    return RecipeCategory.values.firstWhere(
      (e) => normalize(e.name) == normalized,
      orElse: () => RecipeCategory.plat,
    );
  }
}

class Recipe {
  final String? id;
  final String userId;
  final String title;
  final RecipeCategory category;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> tags;
  final String source;
  final String? preparationTime;
  final String? cookingTime;
  final String estimatedTime;
  final String? imageUrl;
  final String? scannedImageUrl;
  final bool isFavorite;
  final int? servings;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe({
    this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.source,
    this.preparationTime,
    this.cookingTime,
    this.estimatedTime = '',
    this.imageUrl,
    this.scannedImageUrl,
    this.isFavorite = false,
    this.servings,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'title': title,
        'category': category.name,
        'ingredients': ingredients,
        'steps': steps,
        'tags': tags,
        'source': source,
        if (preparationTime != null) 'preparationTime': preparationTime,
        if (cookingTime != null) 'cookingTime': cookingTime,
        'estimatedTime': estimatedTime,
        'imageUrl': imageUrl,
        'scannedImageUrl': scannedImageUrl,
        'favorite': isFavorite,
        if (servings != null) 'servings': servings,
        if (note != null) 'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory Recipe.fromJson(Map<String, dynamic> json, String id) => Recipe(
        id: id,
        userId: (json['userId'] ?? '') as String,
        title: (json['title'] ?? '') as String,
        category: _parseCategory(json['category']),
        ingredients: _parseStringList(json['ingredients']),
        steps: _parseStringList(json['steps']),
        tags: _parseStringList(json['tags']),
        source: (json['source'] ?? '') as String,
        preparationTime: json['preparationTime'] as String?,
        cookingTime: json['cookingTime'] as String?,
        estimatedTime: (json['estimatedTime'] ?? '') as String,
        imageUrl: json['imageUrl'] as String?,
        scannedImageUrl: json['scannedImageUrl'] as String?,
        isFavorite: (json['favorite'] ?? json['isFavorite'] ?? false) as bool,
        servings:
            _parseServings(json['servings'] ?? json['persons'] ?? json['serves']),
        note: (json['note'] as String?)?.trim(),
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  Recipe copyWith({
    String? id,
    String? userId,
    String? title,
    RecipeCategory? category,
    List<String>? ingredients,
    List<String>? steps,
    List<String>? tags,
    String? source,
    String? preparationTime,
    String? cookingTime,
    String? estimatedTime,
    String? imageUrl,
    String? scannedImageUrl,
    bool? isFavorite,
    int? servings,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Recipe(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        category: category ?? this.category,
        ingredients: ingredients ?? this.ingredients,
        steps: steps ?? this.steps,
        tags: tags ?? this.tags,
        source: source ?? this.source,
        preparationTime: preparationTime ?? this.preparationTime,
        cookingTime: cookingTime ?? this.cookingTime,
        estimatedTime: estimatedTime ?? this.estimatedTime,
        imageUrl: imageUrl ?? this.imageUrl,
        scannedImageUrl: scannedImageUrl ?? this.scannedImageUrl,
        isFavorite: isFavorite ?? this.isFavorite,
        servings: servings ?? this.servings,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return <String>[];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  static RecipeCategory _parseCategory(dynamic value) {
    if (value == null) return RecipeCategory.plat;

    String normalize(String s) {
      return s
          .toLowerCase()
          .trim()
          .replaceAll('é', 'e')
          .replaceAll('è', 'e')
          .replaceAll('ê', 'e')
          .replaceAll('à', 'a')
          .replaceAll('â', 'a')
          .replaceAll('ô', 'o')
          .replaceAll('î', 'i')
          .replaceAll('û', 'u')
          .replaceAll('ù', 'u')
          .replaceAll('ç', 'c');
    }

    final normalized = normalize(value.toString());

    if (normalized == 'entree') return RecipeCategory.entree;
    if (normalized == 'plat' || normalized == 'plats')
      return RecipeCategory.plat;
    if (normalized == 'dessert' || normalized == 'desserts')
      return RecipeCategory.dessert;
    if (normalized == 'boisson' ||
        normalized == 'boissons' ||
        normalized == 'drink') return RecipeCategory.boisson;

    return RecipeCategory.values.firstWhere(
      (e) => normalize(e.name) == normalized,
      orElse: () => RecipeCategory.plat,
    );
  }

  static int? _parseServings(dynamic value) {
    if (value == null) return null;
    try {
      if (value is int) return value;
      if (value is double) return value.round();
      final match = RegExp(r"(\d+)").firstMatch(value.toString());
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    } catch (_) {}
    return null;
  }
}