# Configuration Firebase — Recettes Magiques

Ce document explique comment configurer l’environnement Firebase et les Cloud Functions pour l’application Recettes Magiques.

---

# Prérequis

- Compte Google
- Flutter installé
- Node.js 18+ installé
- Firebase CLI installé
- Projet Google Cloud actif (lié à Firebase)

---

# 1️⃣ Création du projet Firebase

1. Aller sur https://console.firebase.google.com
2. Créer un nouveau projet
3. Activer Google Analytics (optionnel)
4. Associer le projet à Google Cloud

---

# 2️⃣ Activation des services Firebase

## Authentication

Activer :
- Email / Password
- Google Sign-In (optionnel)

---

## Firestore

1. Créer la base de données
2. Mode production
3. Choisir une région (ex: europe-west1)

---

## Storage

1. Activer Firebase Storage
2. Même région que Firestore

---

# 3️⃣ Configuration Flutter (FlutterFire)

Installer FlutterFire CLI :

```bash
dart pub global activate flutterfire_cli
```

Puis à la racine du projet Flutter :

```bash
flutterfire configure
```

Sélectionner :
- Android
- iOS
- Web (optionnel)

Le fichier `firebase_options.dart` sera généré automatiquement.

---

# 4️⃣ Règles de sécurité Firestore

Dans Firebase Console > Firestore > Règles :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    match /users/{userId} {
      allow read, write: if isOwner(userId);
    }

    match /recipes/{recipeId} {
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
  }
}
```

Publier les règles.

---

# 5️⃣ Règles de sécurité Storage

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    function isAuthenticated() {
      return request.auth != null;
    }

    match /recipes/{userId}/{recipeId}/{fileName} {
      allow read: if isAuthenticated() && request.auth.uid == userId;
      allow write: if isAuthenticated()
                   && request.auth.uid == userId
                   && request.resource.contentType.matches('image/.*')
                   && request.resource.size < 10 * 1024 * 1024;
    }
  }
}
```

---

# 6️⃣ Cloud Functions (Gemini + Vertex AI)

## Installation

```bash
npm install -g firebase-tools
firebase login
firebase init functions
```

Choisir :
- Functions v2
- Node.js 18+
- TypeScript recommandé

---

# 7️⃣ Configuration des APIs Google Cloud

Dans Google Cloud Console :

Activer :

- Vertex AI API
- Generative Language API

---

# 8️⃣ Variables d’environnement

Configurer les variables pour Gemini :

```bash
firebase functions:config:set gemini.key="VOTRE_CLE_GEMINI"
```

Si Vertex AI nécessite configuration région :

```bash
firebase functions:config:set vertex.project_id="VOTRE_PROJECT_ID"
firebase functions:config:set vertex.location="europe-west1"
```

---

# 9️⃣ Déploiement

```bash
firebase deploy --only functions
```

---

# Sécurité IA

- Les clés API sont stockées côté serveur uniquement
- Aucun secret dans l’application Flutter
- Vérification du token Firebase avant traitement
- Gestion des erreurs et retry en cas de rate limit

---

# Test de l’application

1. `flutter run`
2. Connexion utilisateur
3. Scanner une recette
4. Vérifier :
   - Création document Firestore
   - Upload image Storage
   - Traitement IA correct

---

# Dépannage

## Erreur fonction IA

```bash
firebase functions:log
```

## Vérifier fonctions déployées

```bash
firebase functions:list
```

## Problème d’authentification

- Vérifier activation Email/Password
- Vérifier règles Firestore

---

# Mode Production

Avant déploiement production :

- Vérifier règles strictes
- Vérifier quotas Vertex AI
- Vérifier limites Firestore
- Activer monitoring (Cloud Logging)

---

# Résumé

Cette configuration permet :

- Une architecture sécurisée
- Une intégration IA server-side
- Une séparation stricte mobile / backend
- Une base scalable prête pour production