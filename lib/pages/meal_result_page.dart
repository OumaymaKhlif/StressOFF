/// The MealResultPage displays the results of a meal analysis.
/// Displays the dish name.
/// Presents detailed nutritional information (calories, proteins, carbs, fats, fibers).
/// Lists detected ingredients.
/// Displays health advice and recommendations.
/// Shows a note if the analysis is a "Try Analysis" (temporary/test analysis).

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../models/meal_models.dart';

class MealResultPage extends StatelessWidget {
  final MealAnalysis analysis;
  final String? imagePath;
  final bool isTryAnalysis;

  const MealResultPage({
    super.key,
    required this.analysis,
    this.imagePath,
    required this.isTryAnalysis,
  });

  // --- Builds the meal image widget ---
  Widget _buildImage() {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return Image.file(
        File(imagePath!),
        height: 250,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (analysis.imageBase64 != null && analysis.imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(analysis.imageBase64!);
        return Image.memory(
          bytes,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return _buildPlaceholder();
      }
    } else {
      return _buildPlaceholder();
    }
  }

  // --- Placeholder image when no meal image is available ---
  Widget _buildPlaceholder() {
    return Container(
      height: 250,
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(Icons.restaurant, size: 80, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isTryAnalysis ? 'Meal Insight' : 'Meal Analysis'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImage(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// --- Dish name ---
                  Text(
                    analysis.dishName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  /// --- Nutrition information card ---
                  _buildNutritionCard(analysis.nutrition),
                  const SizedBox(height: 20),

                  /// --- Ingredients section ---
                  _buildSection(
                    title: 'What’s in your plate 🍽️',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: analysis.ingredients.map((ingredient) {
                        return Chip(
                          label: Text(ingredient),
                          backgroundColor: Color(0xFFDEE8EA),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  /// --- Allergy alert (if any) ---
                  if (analysis.allergiesDetected != null && analysis.allergiesDetected!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Allergy Alert: ${analysis.allergiesDetected!.join(", ")}',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  /// --- Health advice section ---
                  _buildSection(
                    title: 'Health Notes 🩺',
                    child: Text(
                      analysis.healthAdvice,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recommandations
                  _buildSection(
                    title: 'Recommendations 💡',
                    child: Text(
                      analysis.recommendation,

                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  /// --- Special note for Try Analysis ---
                  if (isTryAnalysis)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF4E4E1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFCC7567)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Color(0xFFCC7567)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This is just a test result '
                                'use "Analyze and Save Meal" to save your meal.',

                              style: TextStyle(color: Color(0xFFCC7567)),
                            ),
                          ),
                        ],
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

  Widget _buildNutritionCard(Nutrition nutrition) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Color(0xFF65B8BF)),
                SizedBox(width: 8),
                Text(
                  'Nutritional Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildNutritionRow(
              'Calories',
              '${nutrition.calories.toInt()} kcal',
              Color(0xFFE3997E),
            ),
            _buildNutritionRow(
              'Proteins',
              '${nutrition.proteins.toStringAsFixed(1)} g',
              Color(0xFF65B8BF),
            ),
            _buildNutritionRow(
              'Carbs',
              '${nutrition.carbs.toStringAsFixed(1)} g',
              Color(0xFFF0D286),
            ),
            _buildNutritionRow(
              'Fats',
              '${nutrition.fats.toStringAsFixed(1)} g',
              Color(0xFFF28B89),
            ),
            _buildNutritionRow(
              'Fibers',
              '${nutrition.fibers.toStringAsFixed(1)} g',
                Color(0xFFA4D4A2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 16)),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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