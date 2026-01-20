import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const String _legalRoute = '/legal';

  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _acceptedCgu = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _openLegal() => context.push(_legalRoute);

  void _toggleCgu() => setState(() => _acceptedCgu = !_acceptedCgu);

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  Widget _eyeButton({
    required bool value,
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
            value ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
          onPressed: onTap,
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (_loading) return;

    // ✅ Ne pas griser le bouton : on laisse cliquer
    // mais on bloque ici si CGU non acceptées.
    if (!_acceptedCgu) {
      _showSnack('Vous devez accepter les CGU pour continuer.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final auth = context.read<AuthProvider>();
      auth.clearError();

      final ok = await auth.signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (!mounted) return;

      if (ok) {
        context.go('/home');
      } else {
        _showSnack(auth.errorMessage ?? 'Inscription impossible.');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Inscription impossible.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

                  // Title (2 fonts)
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
                        // Illustration top-right
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

                            Text('Inscription', style: AppTextStyles.sheetTitle()),
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
                                      controller: _emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.email],
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
                                      controller: _passwordCtrl,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.newPassword],
                                      decoration: _pillDecoration(
                                        hint: '',
                                        prefixIcon: Icons.lock_outline,
                                        suffix: _eyeButton(
                                          value: _obscurePassword,
                                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Mot de passe requis';
                                        if (value.length < 6) return 'Minimum 6 caractères';
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  Text('Confirmer le mot de passe', style: AppTextStyles.fieldLabel()),
                                  const SizedBox(height: 8),
                                  _ShadowField(
                                    child: TextFormField(
                                      controller: _confirmCtrl,
                                      obscureText: _obscureConfirm,
                                      textInputAction: TextInputAction.done,
                                      decoration: _pillDecoration(
                                        hint: '',
                                        prefixIcon: Icons.lock_outline,
                                        suffix: _eyeButton(
                                          value: _obscureConfirm,
                                          onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Confirmation requise';
                                        if (value != _passwordCtrl.text) return 'Les mots de passe ne correspondent pas';
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _register(),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // ✅ CGU discrète
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: _loading ? null : _toggleCgu,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            color: _acceptedCgu
                                                ? AppColors.roundButton.withValues(alpha: 0.25)
                                                : Colors.white.withValues(alpha: 0.55),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _acceptedCgu ? AppColors.roundButton : AppColors.border,
                                              width: 1,
                                            ),
                                          ),
                                          child: _acceptedCgu
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
                                              "J’accepte les ",
                                              style: AppTextStyles.muted().copyWith(fontSize: 12),
                                            ),
                                            GestureDetector(
                                              onTap: _openLegal,
                                              child: Text("CGU", style: AppTextStyles.link().copyWith(fontSize: 12)),
                                            ),
                                            Text(
                                              " et la ",
                                              style: AppTextStyles.muted().copyWith(fontSize: 12),
                                            ),
                                            GestureDetector(
                                              onTap: _openLegal,
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
                                  ),

                                  const SizedBox(height: 14),

                                  // Button (toujours cliquable, mais bloque si CGU non cochée)
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _register,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.black,
                                        shape: const StadiumBorder(),
                                        elevation: 8,
                                        shadowColor: Colors.black26,
                                      ),
                                      child: _loading
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
                                          onTap: () => context.go('/login'),
                                          child: Text('Se connecter', style: AppTextStyles.link()),
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
