// Calculates a 0–100 health score from streak + weight progress.
// This is a rule-based formula — the AI service (ai_service.dart)
// can later call an LLM to enrich or explain this score.
class HealthScoreCalculator {
  static double calculate({
    required int    streak,
    required double startWeight,
    required double currentWeight,
    required double targetWeight,
    required String goal,
  }) {
    // 1. Consistency score (50% of total)
    //    Streaks up to 30 days give full marks
    final consistencyScore = (streak.clamp(0, 30) / 30) * 50;

    // 2. Weight progress score (50% of total)
    double weightScore = 0;
    final totalNeeded = (startWeight - targetWeight).abs();

    if (totalNeeded < 0.1) {
      // Already at goal — full marks
      weightScore = 50;
    } else {
      final progress = (startWeight - currentWeight) / totalNeeded;
      if (goal == 'Lose Weight') {
        // Progress > 0 means weight went down → good
        weightScore = (progress.clamp(0.0, 1.0)) * 50;
      } else if (goal == 'Build Muscle') {
        // Progress > 0 means weight went up → good
        weightScore = (progress.clamp(0.0, 1.0)) * 50;
      } else {
        // Stay Fit — reward staying within ±2 kg of start
        final deviation = (currentWeight - startWeight).abs();
        weightScore = (1 - (deviation / 2).clamp(0.0, 1.0)) * 50;
      }
    }

    return (consistencyScore + weightScore).clamp(0, 100);
  }
}