import 'package:flutter/material.dart';
import 'package:recette_magique/theme.dart';

class StepNumberCircle extends StatelessWidget {
  final int number;

  const StepNumberCircle({super.key, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.text,
        ),
      ),
    );
  }
}
