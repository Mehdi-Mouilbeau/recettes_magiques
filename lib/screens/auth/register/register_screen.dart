import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/screens/auth/register/register_controller.dart';
import 'package:recette_magique/theme.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  static const String _legalRoute = '/legal';

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleRegister(
    BuildContext context,
    RegisterController controller,
    GlobalKey<FormState> formKey,
  ) async {
    if (controller.isLoading) return;

    if (!controller.acceptedCgu) {
      _showSnackBar(context, 'Vous devez accepter les CGU pour continuer.');
      return;
    }

    if (!formKey.currentState!.validate()) return;

    controller.setLoading(true);

    try {
      final authProvider = context.read<AuthProvider>();
      authProvider.clearError();

      final success = await authProvider.signUp(
        controller.email,
        controller.password,
      );

      if (!context.mounted) return;

      if (success) {
        context.go('/home');
      } else {
        _showSnackBar(
          context,
          authProvider.errorMessage ?? 'Inscription impossible.',
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Inscription impossible.');
    } finally {
      if (context.mounted) {
        controller.setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterController(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(gradient: AppColors.bgGradient),
              ),
            ),

            SafeArea(
              child: Consumer<RegisterController>(
                builder: (context, controller, _) {
                  return _RegisterContent(
                    controller: controller,
                    onRegister: (formKey) => _handleRegister(
                      context,
                      controller,
                      formKey,
                    ),
                    onOpenLegal: () => context.push(_legalRoute),
                    onNavigateToLogin: () => context.go('/login'),
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

class _RegisterContent extends StatelessWidget {
  final RegisterController controller;
  final Function(GlobalKey<FormState>) onRegister;
  final VoidCallback onOpenLegal;
  final VoidCallback onNavigateToLogin;

  const _RegisterContent({
    required this.controller,
    required this.onRegister,
    required this.onOpenLegal,
    required this.onNavigateToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const SizedBox(height: 70),

          // Title
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                Text('Inscription', style: AppTextStyles.sheetTitle()),
                const SizedBox(height: 18),
                _RegisterForm(
                  formKey: formKey,
                  controller: controller,
                  onRegister: () => onRegister(formKey),
                  onOpenLegal: onOpenLegal,
                  onNavigateToLogin: onNavigateToLogin,
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

class _RegisterForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final RegisterController controller;
  final VoidCallback onRegister;
  final VoidCallback onOpenLegal;
  final VoidCallback onNavigateToLogin;

  const _RegisterForm({
    required this.formKey,
    required this.controller,
    required this.onRegister,
    required this.onOpenLegal,
    required this.onNavigateToLogin,
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

  Widget _eyeButton({
    required bool isObscured,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(
            isObscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
          onPressed: onTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
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
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: _pillDecoration(
                hint: '',
                prefixIcon: Icons.lock_outline,
                suffix: _eyeButton(
                  isObscured: controller.obscurePassword,
                  onTap: controller.togglePasswordVisibility,
                ),
              ),
              validator: controller.validatePassword,
            ),
          ),

          const SizedBox(height: 18),

          // Confirm password field
          Text('Confirmer le mot de passe', style: AppTextStyles.fieldLabel()),
          const SizedBox(height: 8),
          _ShadowField(
            child: TextFormField(
              controller: controller.confirmPasswordController,
              obscureText: controller.obscureConfirm,
              textInputAction: TextInputAction.done,
              decoration: _pillDecoration(
                hint: '',
                prefixIcon: Icons.lock_outline,
                suffix: _eyeButton(
                  isObscured: controller.obscureConfirm,
                  onTap: controller.toggleConfirmVisibility,
                ),
              ),
              validator: controller.validateConfirmPassword,
              onFieldSubmitted: (_) => onRegister(),
            ),
          ),

          const SizedBox(height: 10),

          // CGU checkbox
          _CguCheckbox(
            accepted: controller.acceptedCgu,
            isLoading: controller.isLoading,
            onToggle: controller.toggleCgu,
            onOpenLegal: onOpenLegal,
          ),

          const SizedBox(height: 14),

          // Register button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: controller.isLoading ? null : onRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
                elevation: 8,
                shadowColor: Colors.black26,
              ),
              child: controller.isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      "S'inscrire",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Login link
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Déjà un compte ? ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                GestureDetector(
                  onTap: onNavigateToLogin,
                  child: Text('Se connecter', style: AppTextStyles.link()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CguCheckbox extends StatelessWidget {
  final bool accepted;
  final bool isLoading;
  final VoidCallback onToggle;
  final VoidCallback onOpenLegal;

  const _CguCheckbox({
    required this.accepted,
    required this.isLoading,
    required this.onToggle,
    required this.onOpenLegal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isLoading ? null : onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: accepted
                  ? AppColors.roundButton.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accepted ? AppColors.roundButton : AppColors.border,
                width: 1,
              ),
            ),
            child: accepted
                ? const Icon(Icons.check, size: 14, color: AppColors.text)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "J'accepte les ",
                style: AppTextStyles.muted().copyWith(fontSize: 12),
              ),
              GestureDetector(
                onTap: onOpenLegal,
                child: Text("CGU",
                    style: AppTextStyles.link().copyWith(fontSize: 12)),
              ),
              Text(
                " et la ",
                style: AppTextStyles.muted().copyWith(fontSize: 12),
              ),
              GestureDetector(
                onTap: onOpenLegal,
                child: Text(
                  "Politique de confidentialité",
                  style: AppTextStyles.link().copyWith(fontSize: 12),
                ),
              ),
              Text(
                ".",
                style: AppTextStyles.muted().copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
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
