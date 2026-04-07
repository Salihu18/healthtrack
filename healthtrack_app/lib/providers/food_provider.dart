import 'dart:async';
import 'package:flutter/material.dart';
import '../models/food_entry.dart';
import '../services/firestore_service.dart';

class FoodProvider extends ChangeNotifier {
  List<FoodEntry>  _entries    = [];
  StreamSubscription? _sub;
  final _fs = FirestoreService();

  List<FoodEntry> get entries       => _entries;
  double          get totalCalories =>
    _entries.fold(0, (sum, e) => sum + e.calories);
  double          get totalProtein  =>
    _entries.fold(0, (sum, e) => sum + e.protein);

  void listenToToday(String uid) {
    _sub?.cancel();
    _sub = _fs.todayFoodStream(uid).listen((entries) {
      _entries = entries;
      notifyListeners();
    });
  }

  Future<void> addEntry(String uid, FoodEntry entry) =>
    _fs.addFoodEntry(uid, entry);

  Future<void> deleteEntry(String uid, String id) =>
    _fs.deleteFoodEntry(uid, id);

  void clear() {
    _sub?.cancel();
    _entries = [];
    notifyListeners();
  }
}