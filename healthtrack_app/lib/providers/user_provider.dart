import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  String     _aiTip   = '';
  bool       _loading = false;
  String     _error   = '';

  UserModel? get user    => _user;
  String     get aiTip   => _aiTip;
  bool       get loading => _loading;
  String     get error   => _error;

  final _fs = FirestoreService();

  Future<void> loadUser(String uid) async {
    _loading = true;
    _error   = '';
    notifyListeners();

    try {
      _user = await _fs.getUser(uid);

      if (_user != null) {
        // Update streak and health score on every session
        _user = await _fs.refreshUserSession(_user!);

        // Fetch AI tip — if it fails, show a default. Never crash the app.
        try {
          _aiTip = await AiService.getHealthInsight(_user!);
        } catch (_) {
          _aiTip = 'Stay consistent — every healthy choice adds up!';
        }
      }
    } catch (e) {
      _error = 'Failed to load profile. Please check your connection.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setUser(UserModel user) {
    _user  = user;
    _aiTip = '';
    notifyListeners();
  }

  // Called after logging a new weight so dashboard updates instantly
  void updateWeight(double newWeight) {
    if (_user == null) return;
    _user = _user!.copyWith(currentWeight: newWeight);
    notifyListeners();
  }

  void clear() {
    _user   = null;
    _aiTip  = '';
    _error  = '';
    notifyListeners();
  }
}