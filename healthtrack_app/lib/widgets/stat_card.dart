import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final String   sub;
  final Color    iconColor;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(value,
            style: const TextStyle(color: AppColors.textPrimary,
                                   fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          Text(sub,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}