import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DailySummaryMealsChart extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fats;
  final double fibers;
  final double totalCalories;

  const DailySummaryMealsChart({
    Key? key,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fibers,
    required this.totalCalories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = protein + carbs + fats + fibers;

    if (total == 0) {
      return const Text("No data available");
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 30,
              sectionsSpace: 1,
              sections: [
                PieChartSectionData(
                  value: protein,
                  color: Color(0xFF65B8BF),
                  showTitle: false,
                  radius: 15,
                ),
                PieChartSectionData(
                  value: carbs,
                  color: Color(0xFFF0D286),
                  showTitle: false,
                  radius: 15,
                ),
                PieChartSectionData(
                  value: fats,
                  color: Color(0xFFF28B89),
                  showTitle: false,
                  radius: 15,
                ),
                PieChartSectionData(
                  value: fibers, // ← nouveau
                  color: Color(0xFFA4D4A2), // couleur pastel pour fibers
                  showTitle: false,
                  radius: 15,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total Calories: ${totalCalories.toInt()} kcal",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _macroRow("Protein", protein, const Color(0xFF65B8BF)),
              _macroRow("Carbs", carbs, const Color(0xFFF0D286)),
              _macroRow("Fats", fats, const Color(0xFFF28B89)),
              _macroRow("Fibers", fibers, const Color(0xFFA4D4A2)),

            ],
          ),
        ),
      ],
    );
  }

  Widget _macroRow(String name, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "$name: ${value.toStringAsFixed(1)} g",
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
