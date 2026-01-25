import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/recipe_provider.dart';
import 'package:recette_magique/screens/account/account_controller.dart';
import 'package:recette_magique/theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _showImagePickerOptions(
    BuildContext context,
    AccountController controller,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                controller.pickProfileImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                controller.pickProfileImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Cette action est définitive.\n'
          'Toutes vos recettes et données seront supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final controller = context.read<AccountController>();
    controller.setLoading(true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.deleteAccountAndData();

    if (!context.mounted) return;
    controller.setLoading(false);

    if (ok) {
      context.go('/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Suppression impossible.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final recipeProvider = context.watch<RecipeProvider>();
    final user = authProvider.currentUser;

    return ChangeNotifierProvider(
      create: (_) => AccountController(),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.bgGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text(
              'Mon compte',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: Consumer<AccountController>(
            builder: (context, controller, _) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile section
                    _ProfileSection(
                      user: user,
                      profileImageBytes: controller.profileImageBytes,
                      recipeCount: recipeProvider.recipes.length,
                      onImageTap: () => _showImagePickerOptions(
                        context,
                        controller,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Delete account section
                    _DeleteAccountSection(
                      isLoading: controller.isLoading,
                      onDelete: () => _confirmDelete(context),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final dynamic user;
  final Uint8List? profileImageBytes;
  final int recipeCount;
  final VoidCallback onImageTap;

  const _ProfileSection({
    required this.user,
    required this.profileImageBytes,
    required this.recipeCount,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile picture
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: profileImageBytes == null
                      ? LinearGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.3),
                            AppColors.roundButton.withOpacity(0.3),
                          ],
                        )
                      : null,
                  image: profileImageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(profileImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profileImageBytes == null
                    ? Center(
                        child: Text(
                          _getInitials(user?.email ?? ''),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onImageTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Email
          Text(
            user?.email ?? 'Non connecté',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Stats
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.restaurant_menu,
                  color: AppColors.accent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '$recipeCount recette${recipeCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String email) {
    if (email.isEmpty) return '?';
    final parts = email.split('@');
    if (parts.isEmpty) return '?';
    final name = parts[0];
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _DeleteAccountSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onDelete;

  const _DeleteAccountSection({
    required this.isLoading,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Zone de danger',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Supprimer mon compte',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Supprime aussi toutes vos données'),
            onTap: isLoading ? null : onDelete,
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: Colors.red),
          ],
        ],
      ),
    );
  }
}