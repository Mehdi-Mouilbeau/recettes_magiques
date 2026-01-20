// lib/screens/home/widgets/home_background.dart
import 'package:flutter/material.dart';
import 'package:recette_magique/theme.dart';

class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    // ton theme met déjà scaffoldBackgroundColor, mais on garde le stack propre
    return const Positioned.fill(
      child: ColoredBox(color: AppColors.bg),
    );
  }
}
