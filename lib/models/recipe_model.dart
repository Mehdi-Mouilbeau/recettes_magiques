import 'package:cloud_firestore/cloud_firestore.dart';

/// Catégories de recettes
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
    return RecipeCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RecipeCategory.plat,
    );
  }
}

/// Modèle de données pour une recette
/// Structure retournée par l'IA après traitement OCR
class Recipe {
  final String? id;
  final String userId;
  final String title;
  final RecipeCategory category;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> tags;
  final String source;
  final String estimatedTime;
  final String? imageUrl;
  final String? scannedImageUrl;
  final bool isFavorite;
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
    required this.estimatedTime,
    this.imageUrl,
    this.scannedImageUrl,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convertit le modèle en Map pour Firestore
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'title': title,
    'category': category.name,
    'ingredients': ingredients,
    'steps': steps,
    'tags': tags,
    'source': source,
    'estimatedTime': estimatedTime,
    'imageUrl': imageUrl,
    'scannedImageUrl': scannedImageUrl,
    'favorite': isFavorite,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// Crée un modèle depuis les données Firestore
  factory Recipe.fromJson(Map<String, dynamic> json, String id) => Recipe(
    id: id,
    userId: (json['userId'] ?? '') as String,
    title: (json['title'] ?? '') as String,
    category: _parseCategory(json['category']),
    ingredients: _parseStringList(json['ingredients']),
    steps: _parseStringList(json['steps']),
    tags: _parseStringList(json['tags']),
    source: (json['source'] ?? '') as String,
    estimatedTime: (json['estimatedTime'] ?? '') as String,
    imageUrl: json['imageUrl'] as String?,
    scannedImageUrl: json['scannedImageUrl'] as String?,
    isFavorite: (json['favorite'] ?? json['isFavorite'] ?? false) as bool,
    createdAt: _parseDate(json['createdAt']),
    updatedAt: _parseDate(json['updatedAt']),
  );

  /// Crée une copie modifiée du modèle
  Recipe copyWith({
    String? id,
    String? userId,
    String? title,
    RecipeCategory? category,
    List<String>? ingredients,
    List<String>? steps,
    List<String>? tags,
    String? source,
    String? estimatedTime,
    String? imageUrl,
    String? scannedImageUrl,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Recipe(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    category: category ?? this.category,
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    tags: tags ?? this.tags,
    source: source ?? this.source,
    estimatedTime: estimatedTime ?? this.estimatedTime,
    imageUrl: imageUrl ?? this.imageUrl,
    scannedImageUrl: scannedImageUrl ?? this.scannedImageUrl,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      // Essayez ISO 8601, sinon retour epoch
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
    // Si chaîne séparée par des virgules
    if (value is String) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return <String>[];
  }

  static RecipeCategory _parseCategory(dynamic value) {
    if (value == null) return RecipeCategory.plat;
    final v = value.toString().toLowerCase().trim();
    // Gérer noms localisés
    if (v == 'entrée' || v == 'entree') return RecipeCategory.entree;
    if (v == 'plat' || v == 'plats') return RecipeCategory.plat;
    if (v == 'dessert' || v == 'desserts') return RecipeCategory.dessert;
    if (v == 'boisson' || v == 'boissons' || v == 'drink') return RecipeCategory.boisson;
    // Fallback sur enum names
    return RecipeCategory.fromString(v);
  }
}
