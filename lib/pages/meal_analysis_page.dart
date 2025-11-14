/// The MealAnalysisPage is the main interface for meal tracking and analysis.
/// Allows users to capture a meal photo and analyze it with AI.
/// Provides two modes:
///     - Quick Analysis: analyzes a meal without saving.
///     - Analyze & Save: analyzes and saves the meal to Firebase.
/// Displays today’s meals with details like dish name, meal type, and calories.
/// Shows a daily nutritional summary with charts for protein, carbs, fats, fibers, and calories.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_models.dart';
import '../services/meal_analysis_service.dart';
import '../services/firebase_service.dart';
import 'meal_result_page.dart';
import 'daily_summary_page.dart';
import 'history_page.dart';
import '../widgets/daily_summary_meals_chart.dart';
import 'dart:convert';

class MealAnalysisPage extends StatefulWidget {
  const MealAnalysisPage({super.key});
  @override
  State<MealAnalysisPage> createState() => _MealAnalysisPageState();
}

class _MealAnalysisPageState extends State<MealAnalysisPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  List<MealAnalysis> _todayMeals = [];

  @override
  void initState() {
    super.initState();
    _loadTodayMeals();
  }

  Future<void> _loadTodayMeals() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final meals = await FirebaseService.getDailyMealAnalyses(
          userId,
          DateTime.now(),
        );
        setState(() {
          _todayMeals = meals;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des repas: $e');
    }
  }

  /// Quick Analysis - Without saving
  Future<void> _tryAnalyse() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userProfile = await FirebaseService.getUserProfile(userId);

      /// Call AI service to analyze the meal
      final result = await MealAnalysisService.analyzeMeal(
        imagePath: image.path,
        userId: userId,
        userProfile: userProfile,
      );

      final analysis = MealAnalysis(
        id: DateTime
            .now()
            .millisecondsSinceEpoch
            .toString(),
        userId: userId,
        mealType: 'try',
        timestamp: DateTime.now(),
        dishName: result['dishName'] ?? 'Unknown Dish',
        ingredients: List<String>.from(result['ingredients'] ?? []),
        nutrition: Nutrition.fromJson(result['nutrition'] ?? {}),
        healthAdvice: result['healthAdvice'] ?? '',
        recommendation: result['recommendation'] ?? '',
        isTryAnalysis: true,
      );

      /// Navigate to MealResultPage to display the result
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MealResultPage(
                  analysis: analysis,
                  imagePath: image.path,
                  isTryAnalysis: true,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  /// Analyze & Save Meal
  Future<void> _analyseMeal() async {
    final mealType = await _showMealTypeDialog();
    if (mealType == null) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userProfile = await FirebaseService.getUserProfile(userId);

      /// Analyze meal using AI service
      final result = await MealAnalysisService.analyzeMeal(
        imagePath: image.path,
        userId: userId,
        mealType: mealType,
        userProfile: userProfile,
      );

      final analysis = MealAnalysis(
        id: DateTime
            .now()
            .millisecondsSinceEpoch
            .toString(),
        userId: userId,
        mealType: mealType,
        timestamp: DateTime.now(),
        imageUrl: null,
        imageBase64: null,
        dishName: result['dishName'] ?? 'Unknown Dish',
        ingredients: List<String>.from(result['ingredients'] ?? []),
        nutrition: Nutrition.fromJson(result['nutrition'] ?? {}),
        healthAdvice: result['healthAdvice'] ?? '',
        recommendation: result['recommendation'] ?? '',
        isTryAnalysis: false,
      );

      /// Save meal and reload today's meals
      await FirebaseService.saveMealAnalysis(analysis, image.path);
      await _loadTodayMeals();

      /// Navigate to MealResultPage
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MealResultPage(
                  analysis: analysis,
                  imagePath: image.path,
                  isTryAnalysis: false,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  /// Meal type selection dialog
  Future<String?> _showMealTypeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Meal Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mealTypeButton('Breakfast', 'breakfast', Icons.free_breakfast),
              _mealTypeButton('Lunch', 'lunch', Icons.lunch_dining),
              _mealTypeButton('Dinner', 'dinner', Icons.dinner_dining),
              _mealTypeButton('Snack', 'snack', Icons.fastfood),
            ],
          ),
        );
      },
    );
  }

  /// Helper to create a meal type button
  Widget _mealTypeButton(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
    );
  }

  /// Analyze all meals for the day and optionally save daily summary
  Future<void> _analyzeDailyMeals() async {
    if (_todayMeals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No meals analyzed today'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final summary = await MealAnalysisService.analyzeDailyMeals(
        userId: userId,
        date: DateTime.now(),
        mealAnalyses: _todayMeals,
      );

      /// Show daily summary page
      if (mounted) {
        final shouldSave = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => DailySummaryPage(summary: summary),
          ),
        );

        if (shouldSave == true) {
          try {
            /// svae the summary
            await FirebaseService.saveDailySummary(summary);

            /// delete the meals of the day
            await FirebaseService.deleteDailyMeals(userId, summary.date);

            /// reload today's meals
            await _loadTodayMeals();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Daily summary saved successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving summary: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily analysis error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isAnalyzing
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Analysis in Progress...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Discover Your Meal's Potential",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Unleash the Secret of Every Bite',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(width: 6),
                Text('🍴', style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Analysis Button
            _buildActionButton(
              onPressed: _tryAnalyse,
              icon: Icons.camera_alt,
              label: 'Quick Analysis',
              subtitle: 'Run a fast analysis without saving',
              color: const Color(0xFF65B8BF),
            ),
            const SizedBox(height: 16),

            // Analyze & Save Meal Button
            _buildActionButton(
              onPressed: _analyseMeal,
              icon: Icons.add_a_photo,
              label: 'Analyze & Save Meal',
              subtitle: 'Capture, analyze, and store your meal',
              color: const Color(0xFF65B8BF),
            ),
            const SizedBox(height: 40),
            if (_todayMeals.isEmpty) ...[
              const Divider(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Meals (0)",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTodayMeals,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Message créatif si aucune donnée
              const Text(
                "Looks like you haven't logged any meals yet. Start tracking to stay on top of your nutrition!",
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),

              // Bouton pour consulter l'historique
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryPage(),
                      ),
                    );
                    await _loadTodayMeals(); // recharger après retour
                  },
                  icon: const Icon(Icons.history),
                  label: const Text("View Weekly Stats"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    backgroundColor: const Color(0xFF65B8BF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],


            if (_todayMeals.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Meals (${_todayMeals.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTodayMeals,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._todayMeals.map((meal) => _buildMealCard(meal)),
              const SizedBox(height: 40),
              const Divider(), // <-- Ajouté ici
              const SizedBox(height: 20),
              // --- Daily Summary Section ---
              const Text(
                'Daily Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Totals chart
              Builder(
                builder: (context) {
                  double totalProtein = 0;
                  double totalCarbs = 0;
                  double totalFats = 0;
                  double totalFibers = 0;
                  double totalCalories = 0;

                  for (var meal in _todayMeals) {
                    totalProtein += meal.nutrition.proteins;
                    totalCarbs += meal.nutrition.carbs;
                    totalFats += meal.nutrition.fats;
                    totalFibers += meal.nutrition.fibers;
                    totalCalories += meal.nutrition.calories;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DailySummaryMealsChart(
                        protein: totalProtein,
                        carbs: totalCarbs,
                        fats: totalFats,
                        fibers: totalFibers,
                        totalCalories: totalCalories,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _analyzeDailyMeals,
                              icon: const Icon(Icons.analytics),
                              label: const Text('Analyze Whole Day'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                backgroundColor:
                                const Color(0xFF65B8BF),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const HistoryPage(),
                                  ),
                                );
                                await _loadTodayMeals();
                              },
                              icon: const Icon(Icons.history),
                              label: const Text("View weekly stats"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                backgroundColor: Colors.white, // Fond blanc
                                foregroundColor: const Color(0xFF65B8BF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealCard(MealAnalysis meal) {
    final mealTypeLabels = {
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'dinner': 'Dinner',
      'snack': 'Snack',
    };

    /// Determine the image of the meal
    Widget avatarImage;

    if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) {
      avatarImage = CircleAvatar(
        backgroundImage: NetworkImage(meal.imageUrl!),
        backgroundColor: Colors.transparent,
      );
    } else if (meal.imageBase64 != null && meal.imageBase64!.isNotEmpty) {
      // Image Base64
      final decodedBytes = base64Decode(meal.imageBase64!);
      avatarImage = CircleAvatar(
        backgroundImage: MemoryImage(decodedBytes),
        backgroundColor: Colors.transparent,
      );
    } else {
      /// Image not available: default icon
      avatarImage = const CircleAvatar(
        backgroundColor: Color(0xFFDEE9EA),
        child: Icon(
          Icons.restaurant,
          color: Color(0xFF65B8BF),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SizedBox(
          width: 50,
          height: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: avatarImage,
          ),
        ),
        title: Text(meal.dishName),
        subtitle: Text(mealTypeLabels[meal.mealType] ?? meal.mealType),
        trailing: Text(
          '${meal.nutrition.calories.toInt()} kcal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        /// 👉 When you click on a meal, its analysis page will be displayed
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MealResultPage(
                analysis: meal,
                imagePath: null,
                isTryAnalysis: meal.isTryAnalysis,
              ),
            ),
          );
        },
      ),
    );
  }
}
