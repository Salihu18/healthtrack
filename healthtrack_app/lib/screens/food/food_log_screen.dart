import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../models/food_entry.dart';
import '../../providers/food_provider.dart';
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
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          // Macro summary bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Macro('Calories', food.totalCalories.toStringAsFixed(0), 'kcal',
                        AppColors.primary),
                _Macro('Protein',
                  food.entries.fold<double>(0, (s,e) => s+e.protein).toStringAsFixed(1),
                  'g', Colors.redAccent),
                _Macro('Carbs',
                  food.entries.fold<double>(0, (s,e) => s+e.carbs).toStringAsFixed(1),
                  'g', AppColors.warning),
                _Macro('Fat',
                  food.entries.fold<double>(0, (s,e) => s+e.fat).toStringAsFixed(1),
                  'g', AppColors.caloriePurple),
              ],
            ),
          ),

          // Food list
          Expanded(
            child: food.entries.isEmpty
              ? const Center(child: Text('No food logged today.\nTap + to add a meal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: food.entries.length,
                  itemBuilder: (_, i) => FoodEntryTile(
                    entry: food.entries[i],
                    onDelete: () => food.deleteEntry(uid, food.entries[i].id),
                  ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFoodSheet(context, uid, food),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        label: const Text('Add Food', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddFoodSheet(BuildContext ctx, String uid, FoodProvider food) {
    final nameCtrl     = TextEditingController();
    final calorieCtrl  = TextEditingController();
    final proteinCtrl  = TextEditingController(text: '0');
    final carbsCtrl    = TextEditingController(text: '0');
    final fatCtrl      = TextEditingController(text: '0');

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Food Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                               color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            _buildField(nameCtrl, 'Food name (e.g. Chicken Rice)',
                        TextInputType.text),
            const SizedBox(height: 12),
            _buildField(calorieCtrl, 'Calories (kcal)', TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildField(proteinCtrl, 'Protein (g)', TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _buildField(carbsCtrl,  'Carbs (g)',   TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _buildField(fatCtrl,    'Fat (g)',     TextInputType.number)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty || calorieCtrl.text.isEmpty) return;
                  food.addEntry(uid, FoodEntry(
                    name:     nameCtrl.text.trim(),
                    calories: double.tryParse(calorieCtrl.text) ?? 0,
                    protein:  double.tryParse(proteinCtrl.text) ?? 0,
                    carbs:    double.tryParse(carbsCtrl.text)   ?? 0,
                    fat:      double.tryParse(fatCtrl.text)     ?? 0,
                    date:     DateTime.now(),
                  ));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
                child: const Text('Add Entry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextField _buildField(TextEditingController ctrl, String hint,
      TextInputType type) {
    return TextField(
      controller: ctrl, keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13)));
  }
}

class _Macro extends StatelessWidget {
  final String label, value, unit;
  final Color  color;
  const _Macro(this.label, this.value, this.unit, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold,
                                   fontSize: 18)),
      Text(unit,  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]);
  }
}