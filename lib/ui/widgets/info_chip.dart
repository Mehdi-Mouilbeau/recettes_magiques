import 'package:flutter/material.dart';
import 'package:recette_magique/theme.dart';

class InfoChip extends StatelessWidget {
  final Color background;
  final IconData icon;
  final String label;
  final Color? textColor;
  final Color? iconColor;

  const InfoChip({
    super.key,
    required this.background,
    required this.icon,
    required this.label,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor ?? AppColors.text),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: textColor ?? AppColors.text,
                ),
          ),
        ],
      ),
    );
  }
}
