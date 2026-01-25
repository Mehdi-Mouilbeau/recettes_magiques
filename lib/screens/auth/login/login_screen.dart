import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/screens/auth/login/login_controller.dart';
import 'package:recette_magique/theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _handleSignIn(
    BuildContext context,
    LoginController controller,
    GlobalKey<FormState> formKey,
  ) async {
    if (!formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      controller.email,
      controller.password,
    );

    if (success && context.mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(gradient: AppColors.bgGradient),
              ),
            ),

            SafeArea(
              child: Consumer<LoginController>(
                builder: (context, controller, _) {
                  return _LoginContent(
                    controller: controller,
                    onSignIn: (formKey) => _handleSignIn(
                      context,
                      controller,
                      formKey,
                    ),
                    onNavigateToRegister: () => context.push('/register'),
                    onForgotPassword: () {
                      // TODO route mot de passe oublié
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginContent extends StatelessWidget {
  final LoginController controller;
  final Function(GlobalKey<FormState>) onSignIn;
  final VoidCallback onNavigateToRegister;
  final VoidCallback onForgotPassword;

  const _LoginContent({
    required this.controller,
    required this.onSignIn,
    required this.onNavigateToRegister,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const SizedBox(height: 70),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    'Recettes',
                    style: AppTextStyles.brandRecettes(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'dans ma poche',
                    style: AppTextStyles.brandSubtitle(),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Image.asset(
                'assets/icons/mascotte.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
              ),
            ],
          ),

          const SizedBox(height: 90),

          // Sheet
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(56),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 26,
                  offset: Offset(0, 14),
                  color: AppColors.shadow,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 2,
                  top: 8,
                  child: Opacity(
                    opacity: 0.95,
                    child: Image.asset(
                      'assets/icons/image_saladier.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    Text('Connexion', style: AppTextStyles.sheetTitle()),
                    const SizedBox(height: 18),

                    _LoginForm(
                      formKey: formKey,
                      controller: controller,
                      onSignIn: () => onSignIn(formKey),
                      onForgotPassword: onForgotPassword,
                      onNavigateToRegister: onNavigateToRegister,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final LoginController controller;
  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onNavigateToRegister;

  const _LoginForm({
    required this.formKey,
    required this.controller,
    required this.onSignIn,
    required this.onForgotPassword,
    required this.onNavigateToRegister,
  });

  InputDecoration _pillDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.hint(),
      filled: true,
      fillColor: AppColors.pill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.roundButton, width: 1.2),
      ),
      prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.textMuted),
      suffixIcon: suffix,
    );
  }

  Widget _eyeButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(
            controller.obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
          onPressed: controller.togglePasswordVisibility,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email field
          Text('Email', style: AppTextStyles.fieldLabel()),
          const SizedBox(height: 8),
          _ShadowField(
            child: TextFormField(
              controller: controller.emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _pillDecoration(
                hint: 'votre@email.com',
                prefixIcon: Icons.mail_outline,
              ),
              validator: controller.validateEmail,
            ),
          ),

          const SizedBox(height: 18),

          // Password field
          Text('Mot de passe', style: AppTextStyles.fieldLabel()),
          const SizedBox(height: 8),
          _ShadowField(
            child: TextFormField(
              controller: controller.passwordController,
              obscureText: controller.obscurePassword,
              decoration: _pillDecoration(
                hint: '',
                prefixIcon: Icons.lock_outline,
                suffix: _eyeButton(),
              ),
              validator: controller.validatePassword,
            ),
          ),

          const SizedBox(height: 4),

          // Forgot password
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: EdgeInsets.zero,
              ),
              onPressed: onForgotPassword,
              child: Text('Mot de passe oublié ?', style: AppTextStyles.link()),
            ),
          ),

          // Error message
          if (authProvider.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE1E1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                authProvider.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFF7A1E1E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Sign in button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: authProvider.isLoading ? null : onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
                elevation: 8,
                shadowColor: Colors.black26,
              ),
              child: authProvider.isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Se connecter',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Register link
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Pas encore de compte ? ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                GestureDetector(
                  onTap: onNavigateToRegister,
                  child: Text("S'inscrire", style: AppTextStyles.link()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShadowField extends StatelessWidget {
  final Widget child;
  const _ShadowField({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: AppColors.shadow,
          )
        ],
      ),
      child: child,
    );
  }
}