import 'package:flutter/material.dart';

class RegisterController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedCgu = false;
  bool _isLoading = false;

  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirm => _obscureConfirm;
  bool get acceptedCgu => _acceptedCgu;
  bool get isLoading => _isLoading;

  String get email => emailController.text.trim();
  String get password => passwordController.text;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleConfirmVisibility() {
    _obscureConfirm = !_obscureConfirm;
    notifyListeners();
  }

  void toggleCgu() {
    _acceptedCgu = !_acceptedCgu;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email requis';
    if (!value.contains('@')) return 'Email invalide';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Mot de passe requis';
    if (value.length < 6) return 'Minimum 6 caractères';
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirmation requise';
    if (value != passwordController.text) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  bool canRegister() {
    return _acceptedCgu && !_isLoading;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void reset() {
    emailController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    _obscurePassword = true;
    _obscureConfirm = true;
    _acceptedCgu = false;
    _isLoading = false;
    notifyListeners();
  }
}