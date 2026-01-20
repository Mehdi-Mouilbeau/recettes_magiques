import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recette_magique/services/auth_service.dart';
import 'package:recette_magique/models/user_model.dart';
import 'package:recette_magique/services/backend_config.dart';

// ✅ Ajouts pour suppression compte + données
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Provider pour gérer l'état d'authentification
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    if (BackendConfig.firebaseReady) {
      _initAuthListener();
    }
  }

  /// Écoute les changements d'état d'authentification
  void _initAuthListener() {
    _authService.authStateChanges.listen((user) async {
      _currentUser = user;
      if (user != null) {
        try {
          _userModel = await _authService.getUserModel(user.uid);
        } catch (e) {
          // évite de casser l'app si la lecture userModel échoue
          _userModel = null;
        }
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  /// Inscription avec email et mot de passe
  Future<bool> signUp(String email, String password) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage =
          'Backend non configuré. Ouvrez le panneau Firebase dans Dreamflow et complétez la configuration.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signUpWithEmail(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Une erreur est survenue';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Connexion avec email et mot de passe
  Future<bool> signIn(String email, String password) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage =
          'Backend non configuré. Ouvrez le panneau Firebase dans Dreamflow et complétez la configuration.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithEmail(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Une erreur est survenue';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    if (BackendConfig.firebaseReady) {
      await _authService.signOut();
    }
    _currentUser = null;
    _userModel = null;
    notifyListeners();
  }

  /// ✅ SUPPRESSION COMPTE (obligatoire iOS)
  /// - supprime les recettes Firestore (recipes où userId == uid)
  /// - supprime les fichiers Storage dans recipes/{uid}/...
  /// - supprime le compte Firebase Auth
  ///
  /// Retourne true si OK, false sinon (message dans errorMessage)
  Future<bool> deleteAccountAndData() async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage =
          'Backend non configuré. Ouvrez le panneau Firebase dans Dreamflow et complétez la configuration.';
      notifyListeners();
      return false;
    }

    final user = _currentUser;
    if (user == null) {
      _errorMessage = 'Aucun utilisateur connecté.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final uid = user.uid;

    try {
      // 1) Supprimer toutes les recettes Firestore de l'utilisateur
      final recipesCol = FirebaseFirestore.instance.collection('recipes');
      final snap = await recipesCol.where('userId', isEqualTo: uid).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }

      // 2) Supprimer tous les fichiers dans Storage recipes/{uid}/...
      // (Storage ne supprime pas un "dossier" d’un coup => on liste tout)
      final rootRef = FirebaseStorage.instance.ref().child('recipes/$uid');
      await _deleteStorageFolderRecursive(rootRef);

      // 3) (optionnel) Supprimer aussi un doc "users/{uid}" si tu en as un
      // -> décommente si tu utilises une collection users
      // await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // 4) Supprimer le compte Auth
      await user.delete();

      // local cleanup
      _currentUser = null;
      _userModel = null;
      _isLoading = false;
      notifyListeners();

      return true;
    } on FirebaseAuthException catch (e) {
      // cas fréquent : re-login requis
      if (e.code == 'requires-recent-login') {
        _errorMessage =
            "Pour des raisons de sécurité, veuillez vous reconnecter puis réessayer.";
      } else {
        _errorMessage = _getErrorMessage(e.code);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// ✅ Supprime récursivement les fichiers d'un "dossier" Storage
  Future<void> _deleteStorageFolderRecursive(Reference ref) async {
    try {
      final list = await ref.listAll();

      // delete files
      for (final item in list.items) {
        await item.delete();
      }

      // recurse subfolders
      for (final prefix in list.prefixes) {
        await _deleteStorageFolderRecursive(prefix);
      }
    } catch (e) {
      // Si le dossier n'existe pas ou si permissions => on log et on continue
      debugPrint('Storage delete skip/error: $e');
    }
  }

  /// Réinitialiser le message d'erreur
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Convertir les codes d'erreur Firebase en messages lisibles
  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'invalid-email':
        return 'Email invalide';
      case 'user-not-found':
        return 'Utilisateur non trouvé';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';

      // Suppression compte
      case 'requires-recent-login':
        return "Veuillez vous reconnecter puis réessayer.";

      default:
        return 'Une erreur est survenue';
    }
  }
}
