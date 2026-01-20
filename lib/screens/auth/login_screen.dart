import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    }
  }

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

  Widget _suffixEyeButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  const SizedBox(height: 70),

                  // Title (2 lines / 2 fonts)
                  Column(
                    children: [
                      Text('Recettes', style: AppTextStyles.brandRecettes(), textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text('dans ma poche', style: AppTextStyles.brandSubtitle(), textAlign: TextAlign.center),
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
                        // Illustration top-right (whisk)
                        // Positioned(
                        //   right: 2,
                        //   top: 8,
                        //   child: Opacity(
                        //     opacity: 0.95,
                        //     child: Image.asset(
                        //       'assets/images/whisk.png',
                        //       width: 90,
                        //       height: 90,
                        //       fit: BoxFit.contain,
                        //     ),
                        //   ),
                        // ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 6),
                            Text('Connexion', style: AppTextStyles.sheetTitle()),
                            const SizedBox(height: 18),

                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Email', style: AppTextStyles.fieldLabel()),
                                  const SizedBox(height: 8),
                                  _ShadowField(
                                    child: TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _pillDecoration(
                                        hint: 'votre@email.com',
                                        prefixIcon: Icons.mail_outline,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Email requis';
                                        if (!value.contains('@')) return 'Email invalide';
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  Text('Mot de passe', style: AppTextStyles.fieldLabel()),
                                  const SizedBox(height: 8),
                                  _ShadowField(
                                    child: TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: _pillDecoration(
                                        hint: '',
                                        prefixIcon: Icons.lock_outline,
                                        suffix: _suffixEyeButton(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Mot de passe requis';
                                        if (value.length < 6) return 'Minimum 6 caractères';
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Forgot password (orange)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: () {
                                        // TODO route mdp oublié
                                      },
                                      child: Text('Mot de passe oublié ?', style: AppTextStyles.link()),
                                    ),
                                  ),

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

                                  // Main button
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: authProvider.isLoading ? null : _signIn,
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
                                          : const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // Bottom text + link (no second big button)
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
                                          onTap: () => context.push('/register'),
                                          child: Text("S'inscrire", style: AppTextStyles.link()),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
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
