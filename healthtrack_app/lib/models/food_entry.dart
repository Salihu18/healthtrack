import 'package:uuid/uuid.dart';

class FoodEntry {
  final String id;
  final String name;
  final double calories;
  final double protein;   // grams
  final double carbs;     // grams
  final double fat;       // grams
  final DateTime date;

  FoodEntry({
    String? id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.date,
  }) : id = id ?? const Uuid().v4();

  factory FoodEntry.fromMap(Map<String, dynamic> map) => FoodEntry(
    id:       map['id']       ?? '',
    name:     map['name']     ?? '',
    calories: (map['calories']?? 0).toDouble(),
    protein:  (map['protein'] ?? 0).toDouble(),
    carbs:    (map['carbs']   ?? 0).toDouble(),
    fat:      (map['fat']     ?? 0).toDouble(),
    date:     DateTime.parse(map['date']),
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'calories': calories,
    'protein': protein, 'carbs': carbs, 'fat': fat,
    'date': date.toIso8601String(),
  };
}