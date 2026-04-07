import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/weight_entry.dart';
import '../../providers/weight_provider.dart';
import '../../providers/user_provider.dart';

class WeightTrackScreen extends StatefulWidget {
  const WeightTrackScreen({super.key});
  @override State<WeightTrackScreen> createState() => _WeightTrackScreenState();
}

class _WeightTrackScreenState extends State<WeightTrackScreen> {
  final _weightCtrl = TextEditingController();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    // Load history when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeightProvider>().loadHistory(_uid);
    });
  }

  Future<void> _logWeight() async {
    final val = double.tryParse(_weightCtrl.text.trim());
    if (val == null || val < 20 || val > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight (20–300 kg)')));
      return;
    }

    final entry = WeightEntry(weight: val, date: DateTime.now());
    await context.read<WeightProvider>().addEntry(_uid, entry);

    // Also update the dashboard's current weight immediately
    if (mounted) context.read<UserProvider>().updateWeight(val);

    _weightCtrl.clear();
    FocusScope.of(context).unfocus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weight logged!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WeightProvider>();
    final reversed = wp.history.reversed.toList(); // oldest → newest for chart

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // Input row
            Row(children: [
              Expanded(
                child: TextField(
                  controller:   _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText:   'Enter weight in kg',
                    suffixText: 'kg',
                    suffixStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  onSubmitted: (_) => _logWeight(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: wp.loading ? null : _logWeight,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                child: wp.loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Log'),
              ),
            ]),
            const SizedBox(height: 20),

            // Chart — only shows when there are at least 2 entries
            if (reversed.length >= 2) ...[
              Container(
                height: 180,
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16)),
                child: LineChart(
                  LineChartData(
                    gridData:   FlGridData(
                      show:                 true,
                      drawVerticalLine:     false,
                      horizontalInterval:   1,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AppColors.surface, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles:   true,
                          reservedSize: 40,
                          getTitlesWidget: (v, _) => Text(
                            v.toStringAsFixed(0),
                            style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles:   true,
                          reservedSize: 22,
                          interval:     (reversed.length / 5).ceilToDouble(),
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= reversed.length) return const SizedBox();
                            return Text(
                              DateFormat('d/M').format(reversed[i].date),
                              style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 9));
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: reversed.asMap().entries.map((e) =>
                          FlSpot(e.key.toDouble(), e.value.weight)).toList(),
                        isCurved:    true,
                        color:       AppColors.primary,
                        barWidth:    2.5,
                        dotData:     FlDotData(show: reversed.length <= 14),
                        belowBarData: BarAreaData(
                          show:  true,
                          color: AppColors.primary.withOpacity(0.12)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // History list header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('History',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
                Text('${wp.history.length} entries',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),

            // History entries
            Expanded(
              child: wp.history.isEmpty
                ? const Center(
                    child: Text(
                      'No weight logged yet.\nEnter your weight above to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, height: 1.6)))
                : ListView.separated(
                    itemCount: wp.history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e    = wp.history[i];
                      final prev = i + 1 < wp.history.length
                        ? wp.history[i + 1].weight
                        : null;
                      final diff = prev != null ? e.weight - prev : null;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12)),
                            child: const Icon(
                              Icons.monitor_weight_outlined,
                              color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.weight.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                              Text(
                                DateFormat('EEE, MMM d  •  h:mm a').format(e.date),
                                style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          )),
                          // Show difference from previous entry
                          if (diff != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: diff <= 0
                                  ? AppColors.success.withOpacity(0.15)
                                  : AppColors.danger.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: diff <= 0
                                    ? AppColors.success
                                    : AppColors.danger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                            ),
                        ]),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}