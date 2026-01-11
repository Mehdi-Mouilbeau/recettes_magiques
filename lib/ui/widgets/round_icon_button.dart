import 'package:flutter/material.dart';
import 'package:recette_magique/theme.dart';

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final double elevation;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 46,
    this.backgroundColor,
    this.iconColor,
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppColors.roundButton,
      shape: const CircleBorder(),
      elevation: elevation,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
          ),
        ),
      ),
    );
  }
}
