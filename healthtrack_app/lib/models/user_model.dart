class UserModel {
  final String uid;
  final String name;
  final String email;
  final String goal;                // "Lose Weight", "Stay Fit", "Build Muscle"
  final double currentWeight;       // in kg
  final double targetWeight;
  final double heightCm;
  final int age;
  final String gender;              // "male" | "female"
  final double dailyCalorieGoal;
  final int streak;
  final DateTime lastActiveDate;
  final double healthScore;         // 0–100

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.goal,
    required this.currentWeight,
    required this.targetWeight,
    required this.heightCm,
    required this.age,
    required this.gender,
    required this.dailyCalorieGoal,
    required this.streak,
    required this.lastActiveDate,
    required this.healthScore,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid:              map['uid']              ?? '',
      name:             map['name']             ?? '',
      email:            map['email']            ?? '',
      goal:             map['goal']             ?? 'Stay Fit',
      currentWeight:    (map['currentWeight']   ?? 70).toDouble(),
      targetWeight:     (map['targetWeight']    ?? 65).toDouble(),
      heightCm:         (map['heightCm']        ?? 170).toDouble(),
      age:              map['age']              ?? 25,
      gender:           map['gender']           ?? 'male',
      dailyCalorieGoal: (map['dailyCalorieGoal']?? 2000).toDouble(),
      streak:           map['streak']           ?? 0,
      lastActiveDate:   DateTime.parse(
                          map['lastActiveDate'] ?? DateTime.now().toIso8601String()),
      healthScore:      (map['healthScore']     ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':              uid,
    'name':             name,
    'email':            email,
    'goal':             goal,
    'currentWeight':    currentWeight,
    'targetWeight':     targetWeight,
    'heightCm':         heightCm,
    'age':              age,
    'gender':           gender,
    'dailyCalorieGoal': dailyCalorieGoal,
    'streak':           streak,
    'lastActiveDate':   lastActiveDate.toIso8601String(),
    'healthScore':      healthScore,
  };

  // Helper — Body Mass Index
  double get bmi => currentWeight / ((heightCm / 100) * (heightCm / 100));

  UserModel copyWith({
    double? currentWeight, int? streak,
    DateTime? lastActiveDate, double? healthScore,
  }) {
    return UserModel(
      uid: uid, name: name, email: email, goal: goal,
      targetWeight: targetWeight, heightCm: heightCm, age: age,
      gender: gender, dailyCalorieGoal: dailyCalorieGoal,
      currentWeight:  currentWeight  ?? this.currentWeight,
      streak:         streak         ?? this.streak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      healthScore:    healthScore    ?? this.healthScore,
    );
  }
}