import 'package:flutter/material.dart';
import 'package:recette_magique/theme.dart';

class HeartButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  const HeartButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
    this.size = 34,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            size: size * 0.53,
            color: iconColor ?? AppColors.text,
          ),
        ),
      ),
    );
  }
}
