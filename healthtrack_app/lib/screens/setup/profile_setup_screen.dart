import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/food_provider.dart';
import '../../screens/dashboard/dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String name, email, password;
  const ProfileSetupScreen({
    super.key,
    required this.name,
    required this.email,
    required this.password,
  });
  @override State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _weightCtrl = TextEditingController(text: '70');
  final _targetCtrl = TextEditingController(text: '65');
  final _heightCtrl = TextEditingController(text: '170');
  final _ageCtrl    = TextEditingController(text: '25');

  String _goal            = 'Lose Weight';
  String _gender          = 'male';
  double _activityFactor  = 1.2;
  bool   _loading         = false;
  final  _auth            = AuthService();

  final _goals = ['Lose Weight', 'Stay Fit', 'Build Muscle'];

  // Activity level options
  final _activityLevels = [
    {
      'label':       'Sedentary',
      'description': 'Little or no exercise',
      'factor':      1.2,
      'icon':        Icons.chair_outlined,
    },
    {
      'label':       'Lightly Active',
      'description': '1–3 days/week',
      'factor':      1.375,
      'icon':        Icons.directions_walk,
    },
    {
      'label':       'Moderately Active',
      'description': '3–5 days/week',
      'factor':      1.55,
      'icon':        Icons.directions_bike_outlined,
    },
    {
      'label':       'Very Active',
      'description': '6–7 days/week',
      'factor':      1.725,
      'icon':        Icons.fitness_center,
    },
    {
      'label':       'Super Active',
      'description': 'Physical job + training',
      'factor':      1.9,
      'icon':        Icons.bolt,
    },
  ];

  // ── BMR + TDEE calculation ───────────────────────────────
  double _calculateCalories() {
    final weight = double.tryParse(_weightCtrl.text) ?? 70;
    final height = double.tryParse(_heightCtrl.text) ?? 170;
    final age    = double.tryParse(_ageCtrl.text)    ?? 25;

    double bmr;
    if (_gender == 'male') {
      // Mifflin-St Jeor for men
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      // Mifflin-St Jeor for women
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    final tdee = bmr * _activityFactor;

    // Adjust based on goal
    if (_goal == 'Lose Weight')   return tdee - 500; // 500 kcal deficit
    if (_goal == 'Build Muscle')  return tdee + 300; // 300 kcal surplus
    return tdee;                                      // Stay Fit = maintenance
  }

  // ── Register ─────────────────────────────────────────────
  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final calories = _calculateCalories();

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
        dailyCalorieGoal: calories,
      );

      if (!mounted) return;
      context.read<UserProvider>().setUser(user);
      context.read<FoodProvider>().listenToToday(user.uid);
      // ADD this:
     Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(e.toString()),
          backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.number,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller:   ctrl,
        keyboardType: type,
        style: const TextStyle(color: AppColors.textPrimary),
        // Recalculate preview whenever user types
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calories = _calculateCalories();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Step 2 of 2 — Your Health Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text('Tell us about yourself',
                style: TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text(
                'We will calculate your daily calorie goal automatically.',
                style: TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 13)),
              const SizedBox(height: 24),

              // ── Goal selector ──────────────────────────────
              const Text('Your goal',
                style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: _goals.map((g) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _goal = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin:  const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _goal == g
                          ? AppColors.primary
                          : AppColors.card,
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(g,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _goal == g
                            ? Colors.black
                            : AppColors.textSecondary,
                          fontWeight: _goal == g
                            ? FontWeight.bold
                            : FontWeight.normal,
                          fontSize: 11)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),

              // ── Gender selector ────────────────────────────
              const Text('Gender',
                style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: ['male', 'female'].map((g) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _gender = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin:  const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _gender == g
                          ? AppColors.primary
                          : AppColors.card,
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        g[0].toUpperCase() + g.substring(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _gender == g
                            ? Colors.black
                            : AppColors.textSecondary,
                          fontWeight: _gender == g
                            ? FontWeight.bold
                            : FontWeight.normal)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),

              // ── Body fields ────────────────────────────────
              _field('Age (years)',         _ageCtrl),
              _field('Height (cm)',         _heightCtrl),
              _field('Current weight (kg)', _weightCtrl),
              _field('Target weight (kg)',  _targetCtrl),

              // ── Activity level ─────────────────────────────
              const Text('Activity Level',
                style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              ..._activityLevels.map((level) {
                final selected =
                  _activityFactor == level['factor'] as double;
                return GestureDetector(
                  onTap: () => setState(
                    () => _activityFactor = level['factor'] as double),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                          ? AppColors.primary
                          : Colors.transparent,
                        width: 1.5)),
                    child: Row(children: [
                      Icon(
                        level['icon'] as IconData,
                        color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                        size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(level['label'] as String,
                              style: TextStyle(
                                color: selected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize:   14)),
                            Text(level['description'] as String,
                              style: const TextStyle(
                                color:    AppColors.textSecondary,
                                fontSize: 12)),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size:  20),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 20),

              // ── Calculated calorie preview ─────────────────
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.calculate_outlined,
                        color: AppColors.primary, size: 16),
                      SizedBox(width: 6),
                      Text('Your Calculated Daily Calorie Goal',
                        style: TextStyle(
                          color:      AppColors.primary,
                          fontSize:   13,
                          fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${calories.toStringAsFixed(0)} kcal',
                          style: const TextStyle(
                            color:      AppColors.primary,
                            fontSize:   32,
                            fontWeight: FontWeight.bold)),
                        const Text(' / day',
                          style: TextStyle(
                            color:    AppColors.textSecondary,
                            fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _goalExplanation(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Register button ────────────────────────────
              SizedBox(
                width:  double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                  child: _loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Start My Journey 🚀',
                        style: TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.bold)))),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _goalExplanation() {
    switch (_goal) {
      case 'Lose Weight':
        return 'Based on your stats minus a 500 kcal deficit for steady fat loss';
      case 'Build Muscle':
        return 'Based on your stats plus a 300 kcal surplus to support muscle growth';
      default:
        return 'Based on your stats to maintain your current weight';
    }
  }
}