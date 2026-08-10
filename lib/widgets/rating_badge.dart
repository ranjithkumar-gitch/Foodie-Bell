import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.dark = false});

  final double rating;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? Colors.black.withValues(alpha: 0.55) : AppColors.accentGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: dark ? AppColors.accentYellow : AppColors.accentGreen),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : AppColors.accentGreen,
            ),
          ),
        ],
      ),
    );
  }
}
