import 'package:flutter/material.dart';
import 'package:recette_magique/theme.dart';

class CategoryTile extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool active;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.text : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.card : AppColors.tile,
          borderRadius: BorderRadius.circular(14),
          border: const BorderSide(color: AppColors.border).toBorder(),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 6),
              color: AppColors.shadow,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(
                color: color,
                size: 24,
              ),
              child: icon, // Image OU Icon
            ),

            const SizedBox(height: 4),

            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on BorderSide {
  BoxBorder toBorder() => Border.all(color: color, width: width);
}
