# Configuration Firebase pour Recette Magique

## 📋 Prérequis

- Un compte Google
- Flutter installé sur votre machine
- Node.js installé (pour les Cloud Functions)

## 🔧 Étapes de configuration

### 1. Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Cliquez sur "Ajouter un projet"
3. Nommez votre projet (ex: "recette-magique")
4. Activez Google Analytics (optionnel)
5. Créez le projet

### 2. Activer les services Firebase

Dans la console Firebase, activez les services suivants :

#### Authentication
1. Allez dans "Authentication" > "Sign-in method"
2. Activez "Email/Password"
3. Activez "Google" (optionnel)

#### Cloud Firestore
1. Allez dans "Firestore Database"
2. Cliquez sur "Créer une base de données"
3. Choisissez "Commencer en mode test" (nous configurerons les règles plus tard)
4. Sélectionnez une région (ex: europe-west1)

#### Storage
1. Allez dans "Storage"
2. Cliquez sur "Commencer"
3. Choisissez "Commencer en mode test"

### 3. Configurer Firebase pour Flutter

#### Installation de FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

#### Configuration automatique

À la racine du projet Flutter, exécutez :

```bash
flutterfire configure
```

- Sélectionnez votre projet Firebase
- Choisissez les plateformes : Android, iOS, Web
- Les fichiers de configuration seront générés automatiquement

### 4. Règles de sécurité Firestore

Dans Firebase Console > Firestore Database > Règles, copiez ces règles :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Fonction pour vérifier si l'utilisateur est authentifié
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Fonction pour vérifier si l'utilisateur est le propriétaire
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Collection users - l'utilisateur peut seulement lire/écrire son propre document
    match /users/{userId} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId);
    }
    
    // Collection recipes - l'utilisateur peut seulement gérer ses propres recettes
    match /recipes/{recipeId} {
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
  }
}
```

Publiez les règles.

### 5. Règles de sécurité Storage

Dans Firebase Console > Storage > Règles, copiez ces règles :

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Fonction pour vérifier si l'utilisateur est authentifié
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Images de recettes - structure: recipes/{userId}/{recipeId}/{fileName}
    match /recipes/{userId}/{recipeId}/{fileName} {
      // Lecture: seulement si l'utilisateur est le propriétaire
      allow read: if isAuthenticated() && request.auth.uid == userId;
      
      // Écriture: seulement si l'utilisateur est le propriétaire et c'est une image
      allow write: if isAuthenticated() 
                   && request.auth.uid == userId
                   && request.resource.contentType.matches('image/.*')
                   && request.resource.size < 10 * 1024 * 1024; // Max 10MB
    }
  }
}
```

Publiez les règles.

### 6. Cloud Functions pour l'IA

#### Installer Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

#### Initialiser les Functions

À la racine du projet :

```bash
firebase init functions
```

- Sélectionnez votre projet
- Choisissez JavaScript ou TypeScript
- Installez les dépendances

#### Créer la fonction de traitement IA

Dans `functions/index.js` (ou `index.ts`), ajoutez :

```javascript
const functions = require('firebase-functions');
const { Configuration, OpenAIApi } = require('openai');

// Configuration OpenAI (stockez la clé de manière sécurisée)
const configuration = new Configuration({
  apiKey: functions.config().openai.key,
});
const openai = new OpenAIApi(configuration);

exports.processRecipe = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  const { text } = req.body;

  try {
    const completion = await openai.createChatCompletion({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: `Tu es un assistant qui transforme des textes de recettes en JSON structuré.
          
          Format de sortie requis (JSON uniquement, sans markdown) :
          {
            "title": "Nom de la recette",
            "category": "entrée | plat | dessert | boisson",
            "ingredients": ["ingrédient 1", "ingrédient 2"],
            "steps": ["étape 1", "étape 2"],
            "tags": ["tag1", "tag2"],
            "source": "Source de la recette",
            "estimatedTime": "30 min"
          }
          
          Instructions :
          - Extrais UNIQUEMENT les informations présentes dans le texte
          - Si certaines informations manquent, utilise des valeurs par défaut raisonnables
          - Catégorise correctement la recette
          - Sépare clairement les ingrédients et les étapes
          - Estime le temps de préparation si non mentionné`
        },
        {
          role: "user",
          content: text
        }
      ],
      response_format: { type: "json_object" }
    });

    const result = JSON.parse(completion.data.choices[0].message.content);
    res.json(result);
  } catch (error) {
    console.error('Erreur:', error);
    res.status(500).json({ error: 'Erreur lors du traitement' });
  }
});
```

#### Configurer la clé API

```bash
firebase functions:config:set openai.key="votre_clé_openai"
```

#### Déployer les Functions

```bash
firebase deploy --only functions
```

#### Mettre à jour l'app Flutter

Dans `lib/services/ai_service.dart`, remplacez `VOTRE_CLOUD_FUNCTION_URL` par l'URL de votre fonction (affichée après le déploiement).

### 7. Créer des index Firestore

Pour les requêtes complexes, vous devrez peut-être créer des index. Firebase vous alertera automatiquement avec des liens pour créer les index nécessaires lors des premières requêtes.

## 🧪 Tester l'application

1. Lancez l'application : `flutter run`
2. Créez un compte
3. Scannez une recette (ou utilisez une image de test)
4. Vérifiez que la recette est correctement sauvegardée

## 🔍 Dépannage

### Erreur Firebase non initialisé
- Vérifiez que `flutterfire configure` a été exécuté
- Vérifiez que `firebase_options.dart` existe

### Erreur d'authentification
- Vérifiez que Email/Password est activé dans Firebase Console
- Vérifiez les règles de sécurité Firestore

### Erreur Cloud Function
- Vérifiez que la fonction est déployée : `firebase functions:list`
- Vérifiez les logs : `firebase functions:log`
- Vérifiez que la clé OpenAI est configurée

### Erreur OCR
- Vérifiez que l'image est bien chargée
- Assurez-vous que l'image contient du texte lisible
- Sur iOS, vérifiez les permissions caméra dans Info.plist

## 📱 Permissions requises

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>Cette app a besoin d'accéder à la caméra pour scanner les recettes</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Cette app a besoin d'accéder à vos photos pour importer des recettes</string>
```

## 🎯 Prochaines étapes

Une fois l'app configurée :

1. Testez avec différentes recettes
2. Ajustez le prompt IA pour améliorer l'extraction
3. Ajoutez plus de fonctionnalités (favoris, partage, etc.)
4. Optimisez les performances
5. Préparez pour le déploiement en production

## 📚 Ressources

- [Documentation Firebase](https://firebase.google.com/docs)
- [FlutterFire](https://firebase.flutter.dev/)
- [OpenAI API](https://platform.openai.com/docs)
- [Google ML Kit](https://developers.google.com/ml-kit)
