// This page displays the user's daily health summary (DailySummary).
// It shows the date, number of meals analyzed, total nutritional intake,
// goals achieved, overall advice, and recommendations.
// Users can choose to save the summary or skip it.
import 'package:flutter/material.dart';
import '../models/meal_models.dart';
import 'package:intl/intl.dart';

class DailySummaryPage extends StatelessWidget {
  final DailySummary summary;

  const DailySummaryPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              elevation: 4,
              color: Color(0xFFF1F6F7),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 60,
                      color: const Color(0xFF65B8BF),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'en_US').format(summary.date),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${summary.mealAnalysisIds.length} meals analyzed',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Total nutrition
            _buildNutritionSummary(summary.totalNutrition),
            const SizedBox(height: 24),

            // Goals achieved
            _buildGoalsCard(summary.needsMet),
            const SizedBox(height: 24),

            // Overall advice
            _buildSection(
              title: 'Nutrition Summary 🥗',
              child: Text(
                summary.globalAdvice,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),

            // Recommendations
            _buildSection(
              title: 'Recommendations 💡',
              child: Text(
                summary.recommendations,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: Color(0xFF65B8BF)),
                    label: const Text(
                      'Skip ',
                      style: TextStyle(color: Color(0xFF65B8BF)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      side: const BorderSide(color: Color(0xFF65B8BF), width: 2),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: const Color(0xFF65B8BF),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSummary(Nutrition nutrition) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.restaurant_menu, color: Color(0xFF65B8BF)),
                SizedBox(width: 8),
                Text(
                  'Daily Nutritional Intake',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildNutritionBar('Calories', nutrition.calories, 2000, Color(0xFFE3997E), 'kcal'),
            const SizedBox(height: 16),
            _buildNutritionBar('Proteins', nutrition.proteins, 60, Color(0xFF65B8BF), 'g'),
            const SizedBox(height: 16),
            _buildNutritionBar('Carbs', nutrition.carbs, 250, Color(0xFFF0D286), 'g'),
            const SizedBox(height: 16),
            _buildNutritionBar('Fats', nutrition.fats, 70, Color(0xFFF28B89), 'g'),
            const SizedBox(height: 16),
            _buildNutritionBar('Fiber', nutrition.fibers, 30, Color(0xFFA4D4A2), 'g'),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionBar(
      String label,
      double value,
      double target,
      Color color,
      String unit,
      ) {
    final percentage = (value / target * 100).clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '${value.toStringAsFixed(1)} / $target $unit',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsCard(bool needsMet) {
    return Card(
      elevation: 4,
      color: needsMet ? Colors.green.shade50 : Color(0xFFF4E4E1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              needsMet ? Icons.check_circle : Icons.info,
              size: 40,
              color: needsMet ? Colors.green : Color(0xFFCC7567),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    needsMet ? 'Goals Achieved!' : 'Partial Goals Achieved',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: needsMet ? Colors.green.shade900 : Color(0xFFCC7567),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    needsMet
                        ? 'Your nutrition was balanced today'
                        : 'Some adjustments are recommended',
                    style: TextStyle(
                      color: needsMet ? Colors.green.shade700 : Color(0xFFCC7567),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
