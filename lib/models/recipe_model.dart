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
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// Crée un modèle depuis les données Firestore
  factory Recipe.fromJson(Map<String, dynamic> json, String id) => Recipe(
    id: id,
    userId: json['userId'] as String,
    title: json['title'] as String,
    category: RecipeCategory.fromString(json['category'] as String),
    ingredients: List<String>.from(json['ingredients'] as List),
    steps: List<String>.from(json['steps'] as List),
    tags: List<String>.from(json['tags'] as List),
    source: json['source'] as String,
    estimatedTime: json['estimatedTime'] as String,
    imageUrl: json['imageUrl'] as String?,
    scannedImageUrl: json['scannedImageUrl'] as String?,
    createdAt: (json['createdAt'] as Timestamp).toDate(),
    updatedAt: (json['updatedAt'] as Timestamp).toDate(),
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
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
