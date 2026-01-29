import 'package:flutter/material.dart';
import 'package:recette_magique/theme.dart';

class SmallPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? background;

  const SmallPill({
    super.key,
    required this.text,
    required this.icon,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background ?? AppColors.control.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.text),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
          ),
        ],
      ),
    );
  }
}
