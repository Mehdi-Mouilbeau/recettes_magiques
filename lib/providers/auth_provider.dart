import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recette_magique/services/auth_service.dart';
import 'package:recette_magique/models/user_model.dart';
import 'package:recette_magique/services/backend_config.dart';

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
        _userModel = await _authService.getUserModel(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  /// Inscription avec email et mot de passe
  Future<bool> signUp(String email, String password) async {
    if (!BackendConfig.firebaseReady) {
      _errorMessage = 'Backend non configuré. Ouvrez le panneau Firebase dans Dreamflow et complétez la configuration.';
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
      _errorMessage = 'Backend non configuré. Ouvrez le panneau Firebase dans Dreamflow et complétez la configuration.';
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
      default:
        return 'Une erreur est survenue';
    }
  }
}
