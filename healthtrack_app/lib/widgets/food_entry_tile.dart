import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/food_entry.dart';

class FoodEntryTile extends StatelessWidget {
  final FoodEntry  entry;
  final VoidCallback onDelete;
  const FoodEntryTile({super.key, required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.restaurant, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.name,
              style: const TextStyle(color: AppColors.textPrimary,
                                     fontWeight: FontWeight.w600)),
            Text('P: ${entry.protein.toStringAsFixed(0)}g  '
                 'C: ${entry.carbs.toStringAsFixed(0)}g  '
                 'F: ${entry.fat.toStringAsFixed(0)}g  •  '
                 '${DateFormat.jm().format(entry.date)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        )),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${entry.calories.toStringAsFixed(0)} kcal',
            style: const TextStyle(color: AppColors.primary,
                                   fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDelete,
          ),
        ]),
      ]),
    );
  }
}