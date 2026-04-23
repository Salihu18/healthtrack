import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../models/food_entry.dart';
import '../../models/user_model.dart';
import '../../providers/food_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_service.dart';
import '../../widgets/food_entry_tile.dart';

class FoodLogScreen extends StatelessWidget {
  const FoodLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final food = context.watch<FoodProvider>();
    final uid  = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Food Log',
          style: TextStyle(
            color:      AppColors.textPrimary,
            fontWeight: FontWeight.bold)),
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [

          // ── Macro summary bar ──────────────────────────────
          Container(
            margin:  const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        AppColors.card,
              borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Macro('Calories',
                  food.totalCalories.toStringAsFixed(0),
                  'kcal', AppColors.primary),
                _Macro('Protein',
                  food.entries.fold<double>(
                    0, (s, e) => s + e.protein).toStringAsFixed(1),
                  'g', Colors.redAccent),
                _Macro('Carbs',
                  food.entries.fold<double>(
                    0, (s, e) => s + e.carbs).toStringAsFixed(1),
                  'g', AppColors.warning),
                _Macro('Fat',
                  food.entries.fold<double>(
                    0, (s, e) => s + e.fat).toStringAsFixed(1),
                  'g', AppColors.caloriePurple),
              ],
            ),
          ),

          // ── AI Meal Suggestions button ─────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _showMealSuggestions(context, food),
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3))),
                child: const Row(children: [
                  Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 18),
                  SizedBox(width: 10),
                  Text('Get AI Meal Suggestions',
                    style: TextStyle(
                      color:      AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize:   14)),
                  Spacer(),
                  Icon(Icons.chevron_right,
                    color: AppColors.primary, size: 18),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Food list ──────────────────────────────────────
          Expanded(
            child: food.entries.isEmpty
              ? const Center(
                  child: Text(
                    'No food logged today.\nTap + to add a meal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:  AppColors.textSecondary,
                      height: 1.6)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: food.entries.length,
                  itemBuilder: (_, i) => FoodEntryTile(
                    entry:    food.entries[i],
                    onDelete: () =>
                      food.deleteEntry(uid, food.entries[i].id),
                  ),
                ),
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFoodSheet(context, uid, food),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        label: const Text('Add Food',
          style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // ── Add food bottom sheet ──────────────────────────────────
  void _showAddFoodSheet(
      BuildContext ctx, String uid, FoodProvider food) {
    final nameCtrl    = TextEditingController();
    final servingCtrl = TextEditingController(text: '100');
    final calorieCtrl = TextEditingController();
    final proteinCtrl = TextEditingController(text: '0');
    final carbsCtrl   = TextEditingController(text: '0');
    final fatCtrl     = TextEditingController(text: '0');

    showModalBottomSheet(
      context:            ctx,
      isScrollControlled: true,
      backgroundColor:    AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left:   24,
            right:  24,
            top:    24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize:      MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title
              const Text('Add Food Entry',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text(
                'Type a food name and tap "AI Predict" to auto-fill '
                'nutrition, or fill it in manually.',
                style: TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 12)),
              const SizedBox(height: 16),

              // Food name + serving
              Row(children: [
                Expanded(
                  flex: 3,
                  child: _buildField(
                    nameCtrl,
                    'Food name (e.g. Jollof Rice)',
                    TextInputType.text),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildField(
                    servingCtrl, 'Serving (g)',
                    TextInputType.number),
                ),
              ]),
              const SizedBox(height: 12),

              // AI Predict button
              SizedBox(
                width:  double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;

                    // Close keyboard
                    FocusScope.of(ctx).unfocus();

                    // Show loading state
                    setSheetState(() {
                      calorieCtrl.text = '...';
                      proteinCtrl.text = '...';
                      carbsCtrl.text   = '...';
                      fatCtrl.text     = '...';
                    });

                    final user = ctx.read<UserProvider>().user;
                    if (user == null) return;

                    final result = await AiService.predictNutrition(
                      foodName:     nameCtrl.text.trim(),
                      servingGrams: double.tryParse(
                        servingCtrl.text) ?? 100.0,
                      user:         user,
                      caloriesToday: food.totalCalories,
                      mealsToday:   food.entries.length,
                    );

                    if (result != null) {
                      setSheetState(() {
                        calorieCtrl.text =
                          result['calories'].toStringAsFixed(0);
                        proteinCtrl.text =
                          result['protein_g'].toStringAsFixed(1);
                        carbsCtrl.text   =
                          result['carbs_g'].toStringAsFixed(1);
                        fatCtrl.text     =
                          result['fat_g'].toStringAsFixed(1);
                      });
                    } else {
                      setSheetState(() {
                        calorieCtrl.text = '';
                        proteinCtrl.text = '0';
                        carbsCtrl.text   = '0';
                        fatCtrl.text     = '0';
                      });
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'AI unavailable — enter values manually.'),
                          backgroundColor: AppColors.warning));
                    }
                  },
                  icon:  const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 16),
                  label: const Text('AI Predict Nutrition',
                    style: TextStyle(
                      color:      AppColors.primary,
                      fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(height: 12),

              // Divider with label
              Row(children: [
                const Expanded(child: Divider(color: AppColors.card)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('or enter manually',
                    style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11))),
                const Expanded(child: Divider(color: AppColors.card)),
              ]),
              const SizedBox(height: 12),

              // Calories
              _buildField(
                calorieCtrl, 'Calories (kcal)',
                TextInputType.number),
              const SizedBox(height: 12),

              // Protein / Carbs / Fat
              Row(children: [
                Expanded(child: _buildField(
                  proteinCtrl, 'Protein (g)',
                  TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _buildField(
                  carbsCtrl,   'Carbs (g)',
                  TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _buildField(
                  fatCtrl,     'Fat (g)',
                  TextInputType.number)),
              ]),
              const SizedBox(height: 20),

              // Add Entry button
              SizedBox(
                width:  double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;

                    final calories =
                      double.tryParse(calorieCtrl.text) ?? 0;
                    final protein  =
                      double.tryParse(proteinCtrl.text) ?? 0;
                    final carbs    =
                      double.tryParse(carbsCtrl.text)   ?? 0;
                    final fat      =
                      double.tryParse(fatCtrl.text)     ?? 0;

                    final entry = FoodEntry(
                      name:     nameCtrl.text.trim(),
                      calories: calories,
                      protein:  protein,
                      carbs:    carbs,
                      fat:      fat,
                      date:     DateTime.now(),
                    );

                    food.addEntry(uid, entry);
                    Navigator.pop(ctx);

                    // Show AI advice after logging
                    final user = ctx.read<UserProvider>().user;
                    if (user != null) {
                      final result = await AiService.predictNutrition(
                        foodName:      nameCtrl.text.trim(),
                        servingGrams:  double.tryParse(
                          servingCtrl.text) ?? 100.0,
                        user:          user,
                        caloriesToday: food.totalCalories,
                        mealsToday:    food.entries.length,
                      );
                      if (result != null && ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['food_advice'] ?? 'Meal logged!'),
                            backgroundColor: AppColors.card,
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label:     result['meal_rating'] ?? 'Good',
                              textColor: AppColors.primary,
                              onPressed: () {},
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                  child: const Text('Add Entry',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AI Meal Suggestions sheet ──────────────────────────────
  void _showMealSuggestions(BuildContext context, FoodProvider food) {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    showModalBottomSheet(
      context:         context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24))),
      builder: (_) => _MealSuggestionsSheet(
        user: user,
        food: food,
      ),
    );
  }

  TextField _buildField(
    TextEditingController ctrl,
    String hint,
    TextInputType type,
  ) {
    return TextField(
      controller:   ctrl,
      keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(
          color:    AppColors.textSecondary,
          fontSize: 13)),
    );
  }
}

// ── Meal Suggestions Sheet ────────────────────────────────────────────────────

class _MealSuggestionsSheet extends StatefulWidget {
  final UserModel    user;
  final FoodProvider food;
  const _MealSuggestionsSheet({
    required this.user,
    required this.food,
  });
  @override
  State<_MealSuggestionsSheet> createState() =>
    _MealSuggestionsSheetState();
}

class _MealSuggestionsSheetState extends State<_MealSuggestionsSheet> {
  Map<String, dynamic>? _suggestions;
  bool   _loading  = true;
  String _mealType = 'dinner';

  final _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final food   = widget.food;
    final result = await AiService.getMealSuggestions(
      user:              widget.user,
      caloriesRemaining: (widget.user.dailyCalorieGoal
                          - food.totalCalories).clamp(0, double.infinity),
      proteinToday:      food.entries.fold(0, (s, e) => s + e.protein),
      carbsToday:        food.entries.fold(0, (s, e) => s + e.carbs),
      fatToday:          food.entries.fold(0, (s, e) => s + e.fat),
      mealType:          _mealType,
    );

    if (mounted) {
      setState(() {
        _suggestions = result;
        _loading     = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.user.dailyCalorieGoal
                       - widget.food.totalCalories).clamp(0, double.infinity);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header
          const Row(children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('AI Meal Suggestions',
              style: TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   18,
                fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(
            '${remaining.toStringAsFixed(0)} kcal remaining today',
            style: const TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 13)),
          const SizedBox(height: 16),

          // Meal type selector
          Row(
            children: _mealTypes.map((type) => Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _mealType = type);
                  _load();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin:   const EdgeInsets.only(right: 6),
                  padding:  const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _mealType == type
                      ? AppColors.primary
                      : AppColors.card,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    type[0].toUpperCase() + type.substring(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _mealType == type
                        ? Colors.black
                        : AppColors.textSecondary,
                      fontWeight: _mealType == type
                        ? FontWeight.bold
                        : FontWeight.normal,
                      fontSize: 11)),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),

          // Results
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('AI is thinking...',
                    style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
            )
          else if (_suggestions != null) ...[

            // Reasoning
            Text(
              _suggestions!['reasoning'] ?? '',
              style: const TextStyle(
                color:    AppColors.textSecondary,
                fontSize: 13,
                height:   1.5)),
            const SizedBox(height: 12),

            // Meal cards
            ...(_suggestions!['suggestions'] as List).map((s) =>
              Container(
                margin:  const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        AppColors.card,
                  borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(
                    width:  36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.restaurant_menu,
                      color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.toString(),
                      style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   14,
                        fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
            const SizedBox(height: 8),

            // Calorie estimate
            Row(children: [
              const Icon(Icons.local_fire_department,
                color: AppColors.warning, size: 14),
              const SizedBox(width: 4),
              Text(
                'Estimated: ${_suggestions!['estimated_calories']}',
                style: const TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 12)),
            ]),

          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Could not load suggestions.\n'
                  'Make sure your AI server is running.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Macro widget ──────────────────────────────────────────────────────────────

class _Macro extends StatelessWidget {
  final String label, value, unit;
  final Color  color;
  const _Macro(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
        style: TextStyle(
          color:      color,
          fontWeight: FontWeight.bold,
          fontSize:   18)),
      Text(unit,
        style: const TextStyle(
          color:    AppColors.textSecondary,
          fontSize: 11)),
      const SizedBox(height: 2),
      Text(label,
        style: const TextStyle(
          color:    AppColors.textSecondary,
          fontSize: 11)),
    ]);
  }
}