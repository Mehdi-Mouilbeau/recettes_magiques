import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:recette_magique/models/user_model.dart';

/// Service d'authentification Firebase
/// Gère l'inscription, la connexion et l'authentification email
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Utilisateur actuel
  User? get currentUser => _auth.currentUser;

  /// Stream de l'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Inscription avec email et mot de passe
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Créer le document utilisateur dans Firestore
      if (credential.user != null) {
        await _createUserDocument(credential.user!);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Erreur inscription: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Erreur inscription: $e');
      rethrow;
    }
  }

  /// Connexion avec email et mot de passe
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Erreur connexion: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Erreur connexion: $e');
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Erreur déconnexion: $e');
      rethrow;
    }
  }

  /// Créer ou mettre à jour le document utilisateur dans Firestore
  Future<void> _createUserDocument(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      final now = DateTime.now();

      if (!docSnapshot.exists) {
        // Nouveau utilisateur
        final userModel = UserModel(
          uid: user.uid,
          email: user.email!,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          createdAt: now,
          updatedAt: now,
        );
        await userDoc.set(userModel.toJson());
      } else {
        // Mise à jour de l'utilisateur existant
        await userDoc.update({
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    } catch (e) {
      debugPrint('Erreur création document utilisateur: $e');
    }
  }

  /// Récupérer le modèle utilisateur depuis Firestore
  Future<UserModel?> getUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur récupération utilisateur: $e');
      return null;
    }
  }
}
