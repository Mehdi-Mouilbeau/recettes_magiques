import 'package:flutter/material.dart';

class LoginController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword = true;

  bool get obscurePassword => _obscurePassword;

  String get email => emailController.text.trim();
  String get password => passwordController.text;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void reset() {
    emailController.clear();
    passwordController.clear();
    _obscurePassword = true;
    notifyListeners();
  }
}