import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User?         get currentUser      => _auth.currentUser;

  // ── REGISTER ─────────────────────────────────────────────
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String goal,
    required double currentWeight,
    required double targetWeight,
    required double heightCm,
    required int    age,
    required String gender,
    required double dailyCalorieGoal,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );

      final user = UserModel(
        uid:              credential.user!.uid,
        name:             name,
        email:            email,
        goal:             goal,
        currentWeight:    currentWeight,
        targetWeight:     targetWeight,
        heightCm:         heightCm,
        age:              age,
        gender:           gender,
        dailyCalorieGoal: dailyCalorieGoal,
        streak:           1,
        lastActiveDate:   DateTime.now(),
        healthScore:      0,
      );

      await _db.collection('users').doc(user.uid).set(user.toMap());
      return user;
    } on FirebaseAuthException catch (e) {
      throw _friendlyError(e.code);
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _friendlyError(e.code);
    }
  }

  Future<void> logout() => _auth.signOut();

  String _friendlyError(String code) => switch (code) {
    'email-already-in-use' => 'This email is already registered.',
    'wrong-password'       => 'Incorrect password.',
    'user-not-found'       => 'No account found with this email.',
    'weak-password'        => 'Password must be at least 6 characters.',
    _                      => 'Something went wrong. Please try again.',
  };
}