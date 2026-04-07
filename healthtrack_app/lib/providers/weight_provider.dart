import 'package:flutter/material.dart';
import '../models/weight_entry.dart';
import '../services/firestore_service.dart';

class WeightProvider extends ChangeNotifier {
  List<WeightEntry> _history  = [];
  bool              _loading  = false;
  final _fs = FirestoreService();

  List<WeightEntry> get history => _history;
  bool              get loading => _loading;

  // Most recent weight, or null if no entries yet
  double? get latestWeight =>
    _history.isNotEmpty ? _history.first.weight : null;

  Future<void> loadHistory(String uid) async {
    _loading = true;
    notifyListeners();
    _history = await _fs.getWeightHistory(uid);
    _loading = false;
    notifyListeners();
  }

  Future<void> addEntry(String uid, WeightEntry entry) async {
    await _fs.addWeightEntry(uid, entry);
    // Insert at front (newest first) without re-fetching
    _history.insert(0, entry);
    notifyListeners();
  }

  void clear() {
    _history = [];
    notifyListeners();
  }
}