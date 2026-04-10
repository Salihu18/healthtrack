import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/food_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String name, email, password;
  const ProfileSetupScreen(
    {super.key, required this.name, required this.email, required this.password});
  @override State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _weightCtrl  = TextEditingController(text: '70');
  final _targetCtrl  = TextEditingController(text: '65');
  final _heightCtrl  = TextEditingController(text: '170');
  final _ageCtrl     = TextEditingController(text: '25');
  final _calorieCtrl = TextEditingController(text: '2000');
  String _goal   = 'Lose Weight';
  String _gender = 'male';
  bool   _loading = false;
  final  _auth    = AuthService();

  final _goals = ['Lose Weight', 'Stay Fit', 'Build Muscle'];

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.register(
        email:            widget.email,
        password:         widget.password,
        name:             widget.name,
        goal:             _goal,
        currentWeight:    double.parse(_weightCtrl.text),
        targetWeight:     double.parse(_targetCtrl.text),
        heightCm:         double.parse(_heightCtrl.text),
        age:              int.parse(_ageCtrl.text),
        gender:           _gender,
        dailyCalorieGoal: double.parse(_calorieCtrl.text),
      );
      if (!mounted) return;
      context.read<UserProvider>().setUser(user);
      context.read<FoodProvider>().listenToToday(user.uid);
      // Navigate to dashboard — clear all previous routes
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()),
                 backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.number}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl, keyboardType: type,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent,
                     foregroundColor: AppColors.textPrimary,
                     title: const Text('Step 2 of 2 — Your Health Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tell us about yourself',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                                 color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text(
                'This helps calculate your BMI, calorie needs, and Health Score.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),

              // Goal selector
              const Text('Your goal',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: _goals.map((g) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _goal = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _goal == g ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(g, textAlign: TextAlign.center,
                        style: TextStyle(
                          color:      _goal == g ? Colors.black : AppColors.textSecondary,
                          fontWeight: _goal == g ? FontWeight.bold : FontWeight.normal,
                          fontSize:   12)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),

              // Gender
              const Text('Gender',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: ['male', 'female'].map((g) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _gender = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _gender == g ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(g[0].toUpperCase() + g.substring(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:      _gender == g ? Colors.black : AppColors.textSecondary,
                          fontWeight: _gender == g ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),

              _field('Age (years)',           _ageCtrl),
              _field('Height (cm)',           _heightCtrl),
              _field('Current weight (kg)',   _weightCtrl),
              _field('Target weight (kg)',    _targetCtrl),
              _field('Daily calorie goal (kcal)', _calorieCtrl),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Not sure about calories? A common starting point is 2000 kcal '
                    'for women and 2500 kcal for men.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                ]),
              ),
              const SizedBox(height: 32),

              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                  child: _loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Start My Journey 🚀',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  }
}