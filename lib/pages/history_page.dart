//// HistoryPage displays all daily summaries of a user (meals, nutrition, recommendations)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';
import '../services/firebase_service.dart';
import 'dart:async';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<DailySummary> _summaries = [];
  bool _isLoading = true;
  bool _hasChanges = false;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _loadHistory();

  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Fetches all daily summaries from Firebase for the current user
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      print('📱 Loading history for user: $userId');

      if (userId != null) {
        final summaries = await FirebaseService.getDailySummaries(userId);
        print('✅ Loaded ${summaries.length} summaries');

        setState(() {
          _summaries = summaries;
          _isLoading = false;
        });
      } else {
        print('❌ No user logged in');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading history: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadHistory,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _summaries.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 100,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 20),
              Text(
                'No history available',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your daily analyses\nwill appear here',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _summaries.length,
          itemBuilder: (context, index) {
            return _buildSummaryCard(_summaries[index]);
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(DailySummary summary) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: InkWell(
        onTap: () => _showSummaryDetails(summary),
        onLongPress: () => _confirmDeleteSummary(summary),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Color(0xFF65B8BF),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy', 'en_US')
                            .format(summary.date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        summary.needsMet
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color:
                        summary.needsMet ? Colors.green : Color(0xFFCC7567),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _confirmDeleteSummary(summary);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Color(0xFFCC7567)),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // Statistics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(
                    'Meals',
                    '${summary.mealAnalysisIds.length}',
                    Icons.restaurant,
                  ),
                  _buildStat(
                    'Calories',
                    '${summary.totalNutrition.calories.toInt()}',
                    Icons.local_fire_department,
                  ),
                  _buildStat(
                    'Proteins',
                    '${summary.totalNutrition.proteins.toInt()}g',
                    Icons.fitness_center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFF65B8BF), size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _showSummaryDetails(DailySummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Text(
                DateFormat('EEEE, MMMM d, yyyy', 'en_US')
                    .format(summary.date),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Overview
              _buildDetailSection(
                'Nutritional Summary',
                Icons.analytics,
                summary.globalAdvice,
              ),
              const SizedBox(height: 16),

              // Recommendations
              _buildDetailSection(
                'Recommendations',
                Icons.lightbulb,
                summary.recommendations,
              ),
              const SizedBox(height: 16),

              // Nutrition details
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.restaurant_menu, color: Color(0xFF65B8BF)),
                          SizedBox(width: 8),
                          Text(
                            'Total Nutrition',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildNutritionRow(
                        'Calories',
                        '${summary.totalNutrition.calories.toInt()} kcal',
                      ),
                      _buildNutritionRow(
                        'Proteins',
                        '${summary.totalNutrition.proteins.toStringAsFixed(1)} g',
                      ),
                      _buildNutritionRow(
                        'Carbohydrates',
                        '${summary.totalNutrition.carbs.toStringAsFixed(1)} g',
                      ),
                      _buildNutritionRow(
                        'Fats',
                        '${summary.totalNutrition.fats.toStringAsFixed(1)} g',
                      ),
                      _buildNutritionRow(
                        'Fibers',
                        '${summary.totalNutrition.fibers.toStringAsFixed(1)} g',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Color(0xFF65B8BF)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSummary(DailySummary summary) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this summary?'),
        content: const Text(
          'This action will permanently delete the summary and all associated meals for that day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseService.deleteDailySummary(userId, summary.id);
      //await FirebaseService.deleteDailyMeals(userId, summary.date);

      if (!mounted) return;

      setState(() {
        _summaries.removeWhere((item) => item.id == summary.id);
        _hasChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Summary deleted successfully'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deletion failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
