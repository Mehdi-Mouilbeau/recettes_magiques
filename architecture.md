# Architecture — Recettes Magiques

Ce document décrit l’architecture technique, les choix de conception et les flux de données de l’application mobile Recettes Magiques.

---

# 1. Vue d’ensemble

Recettes Magiques est une application mobile développée en Flutter permettant de :

- Scanner des recettes depuis des livres de cuisine (OCR)
- Structurer automatiquement les données via IA
- Stocker les recettes dans le cloud
- Organiser les recettes par catégorie
- Afficher les détails avec image générée

L’application repose sur une architecture MVVM claire, intégrant Firebase et un traitement IA via Cloud Functions.

---

# 2. Architecture générale — MVVM

L’application suit le pattern **MVVM (Model–View–ViewModel)** avec Provider pour la gestion d’état.

## Structure du projet

```
lib/
├── main.dart
├── nav.dart
├── theme.dart
│
├── models/
├── services/
├── providers/
├── screens/
└── widgets/
```

## Répartition des responsabilités

### 🔹 Models

Contiennent uniquement les structures de données :

- `UserModel`
- `RecipeModel`

Aucune logique métier.

---

### 🔹 Services

Couche métier et intégration externe :

- Authentification Firebase
- CRUD Firestore
- Gestion Firebase Storage
- OCR via Google ML Kit
- Appel Cloud Function pour traitement IA

Les services encapsulent toute communication externe.

---

### 🔹 Providers (ViewModels)

Couche intermédiaire entre UI et services :

- Gestion de l’état d’authentification
- Gestion de la liste des recettes
- Filtres par catégorie
- Orchestration des opérations CRUD

Les Providers exposent des données réactives à l’interface.

---

### 🔹 Screens (Vues)

Couche UI uniquement :

- Aucune logique Firebase directe
- Aucune logique API
- Interaction uniquement via les Providers

---

# 3. Flux de données

## 3.1 Authentification

```
LoginScreen
   ↓
AuthProvider
   ↓
AuthService
   ↓
Firebase Authentication
   ↓
Redirection via go_router
```

Le `AuthProvider` écoute `authStateChanges` pour mettre à jour automatiquement l’interface.

---

## 3.2 Scan d’une recette

```
ScanScreen
   ↓
Image Picker
   ↓
OCRService (ML Kit – local)
   ↓
AIService (Cloud Function)
   ↓
RecipeProvider
   ↓
RecipeService (Firestore)
   ↓
StorageService (upload image)
   ↓
Retour Home (mise à jour temps réel)
```

### Choix techniques importants :

- OCR exécuté localement (pas de coût serveur)
- Traitement IA exécuté côté serveur (clé API protégée)
- Firestore en temps réel pour synchronisation automatique UI
- Séparation stricte entre métadonnées (Firestore) et fichiers (Storage)

---

## 3.3 Suppression d’une recette

```
RecipeDetailScreen
   ↓
RecipeProvider
   ↓
RecipeService + StorageService
   ↓
Suppression Firestore + Storage
   ↓
Actualisation Home
```

---

# 4. Backend Firebase

## Services utilisés

- **Firebase Authentication** — Email / Password + Google Sign-In
- **Firestore** — Base de données NoSQL temps réel
- **Firebase Storage** — Stockage des images
- **Cloud Functions (Node.js)** — Endpoint sécurisé pour traitement IA

---

## Modèle de sécurité

### Règles Firestore

Chaque utilisateur ne peut accéder qu’à ses propres recettes :

```javascript
match /recipes/{recipeId} {
  allow read, write: if request.auth.uid == resource.data.userId;
}
```

### Règles Storage

Chaque utilisateur ne peut accéder qu’à ses propres images :

```javascript
match /recipes/{userId}/{recipeId}/{fileName} {
  allow read, write: if request.auth.uid == userId;
}
```

### Sécurité IA

- Clé API stockée uniquement dans Cloud Functions
- Aucun secret exposé côté Flutter
- Vérification du token Firebase avant traitement

---

# 5. Modèle de données

## Collection `users`

```json
{
  "uid": "string",
  "email": "string",
  "displayName": "string?",
  "photoUrl": "string?",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

## Collection `recipes`

```json
{
  "userId": "string",
  "title": "string",
  "category": "entrée|plat|dessert|boisson",
  "ingredients": ["string"],
  "steps": ["string"],
  "tags": ["string"],
  "source": "string",
  "estimatedTime": "string",
  "imageUrl": "string?",
  "scannedImageUrl": "string?",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

## Structure Storage

```
recipes/
  {userId}/
    {recipeId}/
      {timestamp}.jpg
```

---

# 6. Design System

## Principes

- Interface minimaliste
- Couleurs neutres et modernes
- Espacements généreux
- Coins arrondis
- Typographie Google Fonts Inter

## Système d’espacement centralisé

- xs → 4px
- sm → 8px
- md → 16px
- lg → 24px
- xl → 32px

Garantit cohérence visuelle et maintenabilité.

---

# 7. Intégrations externes

## Google ML Kit (OCR local)

- Traitement sur device
- Rapide
- Pas de coût réseau
- Fonctionne hors ligne

## Google Gemini 2.0 Flash (via Cloud Function)

- Extraction et structuration des recettes
- Classification automatique
- Génération de JSON strict
- Validation et fallback côté serveur

## Vertex AI — Imagen 3

- Génération d’images réalistes
- Prompt engineering dynamique
- Contraintes visuelles strictes
- Conversion et optimisation WebP

---

# 8. Navigation

Gestion via `go_router`.

## Routes principales

```
/login
/register
/home
/scan
/recipe/:id
```

## Logique de redirection

- Non connecté → /login
- Connecté → /home
- Protection des routes privées

---

# 9. Gestion d’état

## AuthProvider

- Utilisateur courant
- Méthodes signIn / signUp / signOut
- Écoute automatique des changements d’authentification

## RecipeProvider

- Stream Firestore temps réel
- Filtres par catégorie
- CRUD complet
- Synchronisation UI

---

# 10. Considérations production

- Mise à jour temps réel Firestore
- Cache images
- Gestion des erreurs
- États de chargement
- Séparation claire des responsabilités
- Règles Firebase strictes
- Secrets protégés côté serveur

---

# 11. Évolutions possibles

- Recherche full-text (Algolia)
- Mode hors ligne
- Favoris et collections
- Pagination
- Partage entre utilisateurs
- Export PDF
- API nutrition
- Reconnaissance d’image avancée

---

# Résumé architectural

Recettes Magiques démontre :

- Une architecture MVVM claire et maintenable
- Une séparation stricte UI / logique métier / services
- Une intégration sécurisée d’IA
- Une base cloud scalable
- Une application pensée pour évoluer
