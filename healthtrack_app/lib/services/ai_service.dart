import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/food_entry.dart';

class AiService {
  // Replace with your Railway URL after deployment
  static const _baseUrl = 'https://your-app.railway.app';
  static const _timeout = Duration(seconds: 15);

  // ── Predict nutrition + get food advice ─────────────────
  static Future<Map<String, dynamic>?> predictNutrition({
    required String    foodName,
    required double    servingGrams,
    required UserModel user,
    required double    caloriesToday,
    required int       mealsToday,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'food_name':          foodName,
          'serving_g':          servingGrams,
          'user_name':          user.name,
          'user_goal':          user.goal,
          'user_streak':        user.streak,
          'user_weight':        user.currentWeight,
          'user_target_weight': user.targetWeight,
          'calories_today':     caloriesToday,
          'daily_calorie_goal': user.dailyCalorieGoal,
          'meals_today':        mealsToday,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Get meal suggestions ─────────────────────────────────
  static Future<Map<String, dynamic>?> getMealSuggestions({
    required UserModel user,
    required double    caloriesRemaining,
    required double    proteinToday,
    required double    carbsToday,
    required double    fatToday,
    required String    mealType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/meal-suggestions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_name':          user.name,
          'user_goal':          user.goal,
          'calories_remaining': caloriesRemaining,
          'protein_today':      proteinToday,
          'carbs_today':        carbsToday,
          'fat_today':          fatToday,
          'meal_type':          mealType,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Get daily coaching message ───────────────────────────
  static Future<Map<String, dynamic>?> getDailyCoaching({
    required UserModel user,
    required double    caloriesToday,
    required int       mealsLogged,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/daily-coach'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_name':          user.name,
          'user_goal':          user.goal,
          'streak':             user.streak,
          'health_score':       user.healthScore,
          'calories_today':     caloriesToday,
          'daily_calorie_goal': user.dailyCalorieGoal,
          'current_weight':     user.currentWeight,
          'target_weight':      user.targetWeight,
          'meals_logged':       mealsLogged,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Fallback insight (no API needed) ────────────────────
  static String getFallbackInsight(UserModel user) {
    if (user.streak >= 7) {
      return '${user.streak} day streak! Your consistency '
             'is building real results. Keep it up!';
    } else if (user.healthScore >= 70) {
      return 'Great health score of '
             '${user.healthScore.toStringAsFixed(0)}%! '
             'You are on track for your ${user.goal} goal.';
    } else if (user.healthScore >= 40) {
      return 'You are making progress! Log your meals daily '
             'to boost your health score higher.';
    }
    return 'Start your journey today — log your first meal '
           'and build your streak!';
  }
}