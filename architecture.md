# Architecture de Recette Magique

## 📱 Vue d'ensemble

Application Flutter de scan et organisation de recettes utilisant OCR et IA générative.

## 🏗️ Architecture MVVM

```
lib/
├── main.dart                    # Point d'entrée, configuration Firebase et Providers
├── nav.dart                     # Configuration go_router et redirections auth
├── theme.dart                   # Thème personnalisé, couleurs, espacements
│
├── models/                      # Modèles de données
│   ├── user_model.dart         # Modèle utilisateur (uid, email, displayName)
│   └── recipe_model.dart       # Modèle recette (title, category, ingredients, steps)
│
├── services/                    # Services métier (logique Firebase et APIs)
│   ├── auth_service.dart       # Authentification (email, Google)
│   ├── recipe_service.dart     # CRUD recettes Firestore
│   ├── storage_service.dart    # Upload/suppression images Firebase Storage
│   ├── ocr_service.dart        # Extraction texte via Google ML Kit
│   └── ai_service.dart         # Appel Cloud Function pour traitement IA
│
├── providers/                   # Gestion d'état avec Provider
│   ├── auth_provider.dart      # État authentification
│   └── recipe_provider.dart    # État liste recettes, filtres
│
├── screens/                     # Écrans de l'application
│   ├── auth/
│   │   ├── login_screen.dart   # Connexion email/Google
│   │   └── register_screen.dart # Inscription
│   ├── home/
│   │   └── home_screen.dart    # Liste recettes + filtres catégorie
│   ├── scan/
│   │   └── scan_screen.dart    # Scan photo + OCR + traitement IA
│   └── recipe/
│       └── recipe_detail_screen.dart # Détail recette + suppression
│
└── widgets/                     # Widgets réutilisables
    ├── recipe_card.dart        # Carte recette pour la liste
    └── category_filter.dart    # Filtres de catégorie horizontaux
```

## 🔄 Flux de données

### 1. Authentification
```
LoginScreen → AuthProvider → AuthService → Firebase Auth → Redirect vers Home
```

### 2. Scan de recette
```
ScanScreen → Image Picker → OCRService (ML Kit) → AIService (Cloud Function)
→ RecipeProvider → RecipeService (Firestore) + StorageService (Storage)
→ Retour Home avec liste actualisée
```

### 3. Affichage des recettes
```
HomeScreen → RecipeProvider (écoute Stream Firestore) → Liste avec filtres
→ Tap sur RecipeCard → RecipeDetailScreen
```

### 4. Suppression
```
RecipeDetailScreen → RecipeProvider → RecipeService + StorageService
→ Suppression Firestore + images Storage → Retour Home
```

## 🎨 Design System

### Couleurs
- **Primary**: Bleu-gris doux (#5B7C99) - moderne et professionnel
- **Surface**: Gris très clair (#FBFCFD) - fond épuré
- **Catégories**: Vert (entrée), Orange (plat), Rose (dessert), Bleu (boisson)

### Typographie
- **Police**: Google Fonts Inter - élégante et lisible
- **Hiérarchie**: Headline (titres), Title (sous-titres), Body (texte)
- **Poids**: Bold pour titres, Regular/Medium pour corps

### Espacements
- xs: 4px, sm: 8px, md: 16px, lg: 24px, xl: 32px, xxl: 48px
- Utilisation cohérente via `AppSpacing`

### Bordures
- sm: 8px, md: 12px, lg: 16px, xl: 24px
- Coins arrondis pour cartes, boutons, inputs

## 🔐 Sécurité Firebase

### Firestore Rules
```javascript
// Les utilisateurs ne peuvent lire/écrire que leurs propres données
match /recipes/{recipeId} {
  allow read, write: if request.auth.uid == resource.data.userId;
}
```

### Storage Rules
```javascript
// Les utilisateurs ne peuvent accéder qu'à leurs images
match /recipes/{userId}/{recipeId}/{fileName} {
  allow read, write: if request.auth.uid == userId;
}
```

### Cloud Functions
- Clé API OpenAI protégée côté serveur
- Pas d'exposition de secrets dans l'app Flutter

## 📊 Structure des données

### Collection `users`
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

### Collection `recipes`
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

### Storage Structure
```
recipes/
  {userId}/
    {recipeId}/
      {timestamp}.jpg
```

## 🔌 Intégrations externes

### Google ML Kit Text Recognition
- OCR sur device (pas d'appel réseau)
- Supporte plusieurs langues
- Gratuit et performant

### OpenAI API (via Cloud Function)
- Modèle: GPT-4o-mini (économique et rapide)
- Format de sortie: JSON structuré
- Prompt optimisé pour extraction de recettes

### Firebase Services
- **Auth**: Email/Password + Google Sign-In
- **Firestore**: Base de données NoSQL en temps réel
- **Storage**: Stockage d'images
- **Cloud Functions**: Endpoint sécurisé pour l'IA

## 🚀 Navigation (go_router)

```
/login           → LoginScreen (initial si non connecté)
/register        → RegisterScreen
/home            → HomeScreen (initial si connecté)
/scan            → ScanScreen
/recipe/:id      → RecipeDetailScreen (avec FutureBuilder)
```

### Redirections
- Non connecté + route privée → /login
- Connecté + route auth → /home

## 📱 Gestion d'état (Provider)

### AuthProvider
- `currentUser`: User actuel Firebase
- `isAuthenticated`: Booléen connexion
- `signIn()`, `signUp()`, `signOut()`: Méthodes auth
- Écoute `authStateChanges` pour mise à jour auto

### RecipeProvider
- `recipes`: Liste des recettes de l'utilisateur
- `selectedCategory`: Filtre actuel
- `filteredRecipes`: Recettes filtrées
- `loadUserRecipes()`: Écoute Stream Firestore
- `createRecipe()`, `updateRecipe()`, `deleteRecipe()`: CRUD

## 🎯 Fonctionnalités principales

1. **Authentification sécurisée** (Email/Google)
2. **Scan OCR** (caméra ou galerie)
3. **Traitement IA** (structuration automatique)
4. **Stockage Cloud** (Firestore + Storage)
5. **Filtres par catégorie** (4 catégories)
6. **Détail recette** (ingrédients + étapes numérotées)
7. **Suppression** (avec confirmation)

## 🔧 Configuration requise

1. **Firebase Project** (voir FIREBASE_SETUP.md)
2. **FlutterFire CLI** pour génération config
3. **OpenAI API Key** (configurée dans Cloud Functions)
4. **Permissions** caméra/galerie (Android/iOS)

## 📝 Bonnes pratiques appliquées

- ✅ Séparation claire UI / Logique / Services
- ✅ Gestion d'erreurs avec debugPrint()
- ✅ Validation formulaires
- ✅ Loading states et feedback utilisateur
- ✅ Règles de sécurité Firebase strictes
- ✅ Code commenté en français pour débutants
- ✅ Design épuré et moderne (pas Material Design basique)
- ✅ Espacement généreux et polices élégantes
- ✅ Architecture scalable et maintenable

## 🐛 Points d'attention

### Mode test vs Production
- L'app utilise `mockProcessRecipeText()` par défaut pour les tests
- Remplacer par `processRecipeText()` après configuration Cloud Function

### OCR
- Qualité dépend de la photo (lumière, angle, résolution)
- Mieux fonctionne avec texte imprimé

### IA
- Résultats dépendent du prompt et du modèle
- Peut nécessiter ajustements selon vos besoins

### Performances
- Stream Firestore se met à jour en temps réel
- Images mises en cache (CachedNetworkImage)
- Considérer pagination si > 100 recettes

## 🚀 Évolutions futures possibles

1. Recherche full-text (Algolia)
2. Favoris et collections
3. Partage de recettes entre utilisateurs
4. Mode hors-ligne (local storage)
5. Export PDF
6. Timer de cuisine
7. Liste de courses
8. Nutrition (intégration API)
9. Traductions multilingues
10. Reconnaissance d'images (plats)
