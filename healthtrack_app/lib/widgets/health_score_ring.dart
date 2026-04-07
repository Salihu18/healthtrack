import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../core/constants/app_colors.dart';

class HealthScoreRing extends StatelessWidget {
  final double score;
  final int    streak;
  final String goal;
  const HealthScoreRing(
    {super.key, required this.score,
     required this.streak, required this.goal});

  Color get _color {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CircularPercentIndicator(
        radius:           90,
        lineWidth:        12,
        percent:          (score / 100).clamp(0.0, 1.0),
        animation:        true,
        animationDuration: 1200,
        backgroundColor:  AppColors.card,
        progressColor:    _color,
        circularStrokeCap: CircularStrokeCap.round,
        center: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${score.toStringAsFixed(0)}%',
              style: TextStyle(color: _color, fontSize: 32,
                               fontWeight: FontWeight.bold)),
            const Text('Health Score',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text('Goal: $goal',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]);
  }
}