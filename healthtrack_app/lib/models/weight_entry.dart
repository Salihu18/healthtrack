import 'package:uuid/uuid.dart';

class WeightEntry {
  final String id;
  final double weight;   // kg
  final DateTime date;

  WeightEntry({String? id, required this.weight, required this.date})
    : id = id ?? const Uuid().v4();

  factory WeightEntry.fromMap(Map<String, dynamic> map) => WeightEntry(
    id:     map['id']     ?? '',
    weight: (map['weight']?? 0).toDouble(),
    date:   DateTime.parse(map['date']),
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'weight': weight, 'date': date.toIso8601String(),
  };
}