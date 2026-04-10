import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/food_entry.dart';
import '../models/weight_entry.dart';
import '../core/utils/health_score_calculator.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ── USER ──────────────────────────────────────────────────
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // Called every time the app opens — handles streak & health score
 Future<UserModel> refreshUserSession(UserModel user) async {
  final now    = DateTime.now();
  final today  = DateTime(now.year,  now.month,  now.day);
  final last   = user.lastActiveDate;
  final lastDay = DateTime(last.year, last.month, last.day);

  // Only calculate difference in whole calendar days (no time component)
  final daysDiff = today.difference(lastDay).inDays;

  int newStreak = user.streak;

  if      (daysDiff == 0) { /* Same day — no change */ }
  else if (daysDiff == 1) { newStreak++; }          // Consecutive day
  else if (daysDiff >  1) { newStreak = 1; }        // Missed day(s) — reset

  // Guard: streak should never be 0 (first open = 1)
  if (newStreak < 1) newStreak = 1;

  final weights = await getWeightHistory(user.uid);
  final score   = HealthScoreCalculator.calculate(
    streak:        newStreak,
    startWeight:   weights.isNotEmpty ? weights.last.weight  : user.currentWeight,
    currentWeight: weights.isNotEmpty ? weights.first.weight : user.currentWeight,
    targetWeight:  user.targetWeight,
    goal:          user.goal,
  );

  // Only write to Firestore if something actually changed
  if (daysDiff > 0) {
    await _db.collection('users').doc(user.uid).update({
      'streak':         newStreak,
      'lastActiveDate': now.toIso8601String(),
      'healthScore':    score,
    });
  }

  return user.copyWith(
    streak:         newStreak,
    lastActiveDate: now,
    healthScore:    score,
  );
}

  Future<void> updateCurrentWeight(String uid, double weight) async {
    await _db.collection('users').doc(uid).update({'currentWeight': weight});
  }

  // ── FOOD ──────────────────────────────────────────────────
  Future<void> addFoodEntry(String uid, FoodEntry entry) =>
    _db.collection('users').doc(uid)
       .collection('food_entries').doc(entry.id).set(entry.toMap());

  Future<void> deleteFoodEntry(String uid, String entryId) =>
    _db.collection('users').doc(uid)
       .collection('food_entries').doc(entryId).delete();

  // Real-time stream of today's food entries
  Stream<List<FoodEntry>> todayFoodStream(String uid) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));

    return _db.collection('users').doc(uid)
      .collection('food_entries')
      .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
      .where('date', isLessThan:             end.toIso8601String())
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => FoodEntry.fromMap(d.data())).toList());
  }

  // ── WEIGHT ────────────────────────────────────────────────
  Future<void> addWeightEntry(String uid, WeightEntry entry) async {
    await _db.collection('users').doc(uid)
       .collection('weight_history').doc(entry.id).set(entry.toMap());
    await updateCurrentWeight(uid, entry.weight);
  }

  Future<List<WeightEntry>> getWeightHistory(String uid) async {
    final snap = await _db.collection('users').doc(uid)
      .collection('weight_history')
      .orderBy('date', descending: true)
      .limit(30)
      .get();
    return snap.docs.map((d) => WeightEntry.fromMap(d.data())).toList();
  }

  Future<void> updateUserProfile(UserModel user) async {
  await _db.collection('users').doc(user.uid).update({
    'name':             user.name,
    'goal':             user.goal,
    'currentWeight':    user.currentWeight,
    'targetWeight':     user.targetWeight,
    'dailyCalorieGoal': user.dailyCalorieGoal,
  });
}
}