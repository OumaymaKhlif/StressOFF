/// This file defines data structures (models) used to store, retrieve,
/// and manipulate information related to analyzed meals (photos, ingredients,
/// nutritional values, health advice) and daily summaries.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a meal analysis
class MealAnalysis {
  final String id;
  final String userId;
  final String mealType;
  final DateTime timestamp;
  final String? imageUrl;
  final String? imageBase64;
  final String dishName;
  final List<String> ingredients;
  final Nutrition nutrition;
  final String healthAdvice;
  final String recommendation;
  final bool isTryAnalysis;
  final List<String>? allergiesDetected;

  MealAnalysis({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.timestamp,
    this.imageUrl,
    this.imageBase64,
    required this.dishName,
    required this.ingredients,
    required this.nutrition,
    required this.healthAdvice,
    required this.recommendation,
    this.isTryAnalysis = false,
    this.allergiesDetected,
  });

  /// Convert MealAnalysis object to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'mealType': mealType,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'dishName': dishName,
      'ingredients': ingredients,
      'nutrition': nutrition.toJson(),
      'healthAdvice': healthAdvice,
      'recommendation': recommendation,
      'isTryAnalysis': isTryAnalysis,
    };
  }

  /// Create MealAnalysis object from JSON format
  factory MealAnalysis.fromJson(Map<String, dynamic> json) {
    // Gérer le timestamp qui peut être String ou Timestamp de Firestore
    DateTime timestamp;
    if (json['timestamp'] is Timestamp) {
      timestamp = (json['timestamp'] as Timestamp).toDate();
    } else if (json['timestamp'] is String) {
      timestamp = DateTime.parse(json['timestamp']);
    } else {
      timestamp = DateTime.now();
    }

    return MealAnalysis(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      mealType: json['mealType'] ?? '',
      timestamp: timestamp,
      imageUrl: json['imageUrl'],
      imageBase64: json['imageBase64'],
      dishName: json['dishName'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      nutrition: Nutrition.fromJson(json['nutrition'] ?? {}),
      healthAdvice: json['healthAdvice'] ?? '',
      recommendation: json['recommendation'] ?? '',
      isTryAnalysis: json['isTryAnalysis'] ?? false,
      allergiesDetected: json['allergiesDetected'] != null
          ? List<String>.from(json['allergiesDetected'])
          : [],
    );
  }
}

/// Model representing nutritional information
class Nutrition {
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;
  final double fibers;

  Nutrition({
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.fibers,
  });

  /// Convert Nutrition object to JSON format
  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'proteins': proteins,
      'carbs': carbs,
      'fats': fats,
      'fibers': fibers,
    };
  }

  // Create Nutrition object from JSON format
  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      calories: (json['calories'] ?? 0).toDouble(),
      proteins: (json['proteins'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fats: (json['fats'] ?? 0).toDouble(),
      fibers: (json['fibers'] ?? 0).toDouble(),
    );
  }
}


/// Model representing a daily summary
class DailySummary {
  final String id;
  final String userId;
  final DateTime date;
  final List<String> mealAnalysisIds;
  final Nutrition totalNutrition;
  final String globalAdvice;
  final String recommendations;
  final bool needsMet;

  DailySummary({
    required this.id,
    required this.userId,
    required this.date,
    required this.mealAnalysisIds,
    required this.totalNutrition,
    required this.globalAdvice,
    required this.recommendations,
    required this.needsMet,
  });

  /// Convert DailySummary to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'mealAnalysisIds': mealAnalysisIds,
      'totalNutrition': totalNutrition.toJson(),
      'globalAdvice': globalAdvice,
      'recommendations': recommendations,
      'needsMet': needsMet,
    };
  }

  /// Create DailySummary object from JSON format
  factory DailySummary.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;

    if (json['date'] is Timestamp) {
      parsedDate = (json['date'] as Timestamp).toDate();
    } else if (json['date'] is String) {
      parsedDate = DateTime.parse(json['date']);
    } else if (json['date'] is DateTime) {
      parsedDate = json['date'];
    } else {
      parsedDate = DateTime.now();
    }

    return DailySummary(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      date: parsedDate,
      mealAnalysisIds: List<String>.from(json['mealAnalysisIds'] ?? []),
      totalNutrition: Nutrition.fromJson(json['totalNutrition'] ?? {}),
      globalAdvice: json['globalAdvice'] ?? '',
      recommendations: json['recommendations'] ?? '',
      needsMet: json['needsMet'] ?? false,
    );
  }
}