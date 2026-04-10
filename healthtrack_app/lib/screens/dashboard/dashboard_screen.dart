import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/food_provider.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/health_score_ring.dart';
import '../food/food_log_screen.dart';
import '../weight/weight_track_screen.dart';
import '../../services/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final foodProvider = context.watch<FoodProvider>();
    final user = userProvider.user;

    if (userProvider.loading || user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final caloriesLeft = (user.dailyCalorieGoal - foodProvider.totalCalories)
        .clamp(0, user.dailyCalorieGoal);
    final caloriePct = (foodProvider.totalCalories / user.dailyCalorieGoal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hello, ${user.name.split(' ').first} 👋',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                   color: AppColors.textPrimary)),
          Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () async {
              context.read<UserProvider>().clear();
              context.read<FoodProvider>().clear();
              await AuthService().logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Tip
            if (userProvider.aiTip.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.2),
                             AppColors.primary.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Text('🤖', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(userProvider.aiTip,
                    style: const TextStyle(color: AppColors.textPrimary,
                                           fontSize: 13, height: 1.5))),
                ]),
              ),

            // Health Score Ring (centre piece)
            Center(
              child: HealthScoreRing(
                score:  user.healthScore,
                streak: user.streak,
                goal:   user.goal,
              ),
            ),
            const SizedBox(height: 24),

            // Stat cards row
            Row(children: [
              Expanded(child: StatCard(
                icon:  Icons.monitor_weight_outlined,
                label: 'Current Weight',
                value: '${user.currentWeight.toStringAsFixed(1)} kg',
                sub:   'Target: ${user.targetWeight} kg',
              )),
              const SizedBox(width: 12),
              Expanded(child: StatCard(
                icon:  Icons.local_fire_department,
                label: 'Streak',
                value: '${user.streak} days 🔥',
                sub:   'Keep it up!',
                iconColor: AppColors.warning,
              )),
            ]),
            const SizedBox(height: 12),

            // Calorie progress card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Today\'s Calories',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text('${foodProvider.totalCalories.toStringAsFixed(0)} /'
                           ' ${user.dailyCalorieGoal.toStringAsFixed(0)} kcal',
                        style: const TextStyle(color: AppColors.textPrimary,
                                               fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value:           caloriePct,
                      minHeight:       10,
                      backgroundColor: AppColors.surface,
                      valueColor: AlwaysStoppedAnimation(
                        caloriePct > 1.0 ? AppColors.danger : AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caloriePct >= 1.0
                      ? '⚠️ Daily goal reached'
                      : '${caloriesLeft.toStringAsFixed(0)} kcal remaining',
                    style: TextStyle(
                      color: caloriePct >= 1.0 ? AppColors.danger : AppColors.textSecondary,
                      fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            const Text('Quick Actions',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              _ActionBtn(
                icon:  Icons.restaurant_menu,
                label: 'Log Food',
                color: AppColors.primary,
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FoodLogScreen())),
              ),
              const SizedBox(width: 12),
              _ActionBtn(
                icon:  Icons.monitor_weight,
                label: 'Log Weight',
                color: AppColors.caloriePurple,
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WeightTrackScreen())),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _ActionBtn(
    {required this.icon, required this.label,
     required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4))),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}