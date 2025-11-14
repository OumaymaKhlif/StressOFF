import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
  });
  /// Event duration
  Duration get duration => endTime.difference(startTime);
  String get timeRange => '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}';
}

class EventRecommendation {
  final String eventTitle;
  final String eventTime;
  final String practices;  // 3-4 sentences with best practices
  final String nutritionSuggestion;  // Nutrition advice
  final String purpose;

  EventRecommendation({
    required this.eventTitle,
    required this.eventTime,
    required this.practices,
    required this.nutritionSuggestion,
    required this.purpose,
  });

  /// Create EventRecommendation
  factory EventRecommendation.fromJson(Map<String, dynamic> json) {
    return EventRecommendation(
      eventTitle: json['eventTitle'] ?? '',
      eventTime: json['eventTime'] ?? '',
      practices: json['practices'] ?? '',
      nutritionSuggestion: json['nutritionSuggestion'] ?? '',
      purpose: json['purpose'] ?? '',
    );
  }
}
/// Real-time health metrics from smartwatch
class HealthMetrics {
  final String id;
  final String userId;
  final DateTime timestamp;
  final double heartRate; // Average HR over period
  final double restingHeartRate; // Resting HR
  final double hrv; // Heart Rate Variability (ms)
  final int steps;
  final double calories;
  final int activeMinutes;
  final double? spo2; // Blood oxygen saturation (%)

  HealthMetrics({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.heartRate,
    required this.restingHeartRate,
    required this.hrv,
    required this.steps,
    required this.calories,
    required this.activeMinutes,
    this.spo2,
  });

  /// Convert HealthMetrics to JSON for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'heartRate': heartRate,
      'restingHeartRate': restingHeartRate,
      'hrv': hrv,
      'steps': steps,
      'calories': calories,
      'activeMinutes': activeMinutes,
      'spo2': spo2,
    };
  }

  /// Create HealthMetrics from JSON
  factory HealthMetrics.fromJson(Map<String, dynamic> json) {
    DateTime timestamp;
    if (json['timestamp'] is Timestamp) {
      timestamp = (json['timestamp'] as Timestamp).toDate();
    } else if (json['timestamp'] is String) {
      timestamp = DateTime.parse(json['timestamp']);
    } else {
      timestamp = DateTime.now();
    }

    return HealthMetrics(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      timestamp: timestamp,
      heartRate: (json['heartRate'] ?? 0).toDouble(),
      restingHeartRate: (json['restingHeartRate'] ?? 0).toDouble(),
      hrv: (json['hrv'] ?? 0).toDouble(),
      steps: json['steps'] ?? 0,
      calories: (json['calories'] ?? 0).toDouble(),
      activeMinutes: json['activeMinutes'] ?? 0,
      spo2: json['spo2'] != null ? (json['spo2'] as num).toDouble() : null,
    );
  }
}

/// Sleep data sent once per day after wake-up
class SleepData {
  final String id;
  final String userId;
  final DateTime date;
  final double durationHours; // Total sleep duration
  final double qualityScore; // 0-100 sleep quality
  final int deepSleepMinutes;
  final int remSleepMinutes;
  final int lightSleepMinutes;

  SleepData({
    required this.id,
    required this.userId,
    required this.date,
    required this.durationHours,
    required this.qualityScore,
    required this.deepSleepMinutes,
    required this.remSleepMinutes,
    required this.lightSleepMinutes,
  });

  /// Convert SleepData to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'durationHours': durationHours,
      'qualityScore': qualityScore,
      'deepSleepMinutes': deepSleepMinutes,
      'remSleepMinutes': remSleepMinutes,
      'lightSleepMinutes': lightSleepMinutes,
    };
  }

  /// Create SleepData from JSON
  factory SleepData.fromJson(Map<String, dynamic> json) {
    DateTime date;
    if (json['date'] is Timestamp) {
      date = (json['date'] as Timestamp).toDate();
    } else if (json['date'] is String) {
      date = DateTime.parse(json['date']);
    } else {
      date = DateTime.now();
    }

    return SleepData(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      date: date,
      durationHours: (json['durationHours'] ?? 0).toDouble(),
      qualityScore: (json['qualityScore'] ?? 0).toDouble(),
      deepSleepMinutes: json['deepSleepMinutes'] ?? 0,
      remSleepMinutes: json['remSleepMinutes'] ?? 0,
      lightSleepMinutes: json['lightSleepMinutes'] ?? 0,
    );
  }
}

/// Daily aggregated health summary
class DailyHealthSummary {
  final String id;
  final String userId;
  final DateTime date;
  final double avgRestingHR;
  final double medianHRV;
  final int totalSteps;
  final double totalCalories;
  final int totalActiveMinutes;
  final double? avgSpO2;
  final SleepData? sleepData;
  final double stressLevel; // 0-10 (computed from HRV variance)
  final String mood; // "good", "neutral", "poor" (computed)

  DailyHealthSummary({
    required this.id,
    required this.userId,
    required this.date,
    required this.avgRestingHR,
    required this.medianHRV,
    required this.totalSteps,
    required this.totalCalories,
    required this.totalActiveMinutes,
    this.avgSpO2,
    this.sleepData,
    required this.stressLevel,
    required this.mood,
  });

  /// Convert summary to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'avgRestingHR': avgRestingHR,
      'medianHRV': medianHRV,
      'totalSteps': totalSteps,
      'totalCalories': totalCalories,
      'totalActiveMinutes': totalActiveMinutes,
      'avgSpO2': avgSpO2,
      'sleepData': sleepData?.toJson(),
      'stressLevel': stressLevel,
      'mood': mood,
    };
  }

  /// Create DailyHealthSummary from JSON
  factory DailyHealthSummary.fromJson(Map<String, dynamic> json) {
    DateTime date;
    if (json['date'] is Timestamp) {
      date = (json['date'] as Timestamp).toDate();
    } else if (json['date'] is String) {
      date = DateTime.parse(json['date']);
    } else {
      date = DateTime.now();
    }

    return DailyHealthSummary(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      date: date,
      avgRestingHR: (json['avgRestingHR'] ?? 0).toDouble(),
      medianHRV: (json['medianHRV'] ?? 0).toDouble(),
      totalSteps: json['totalSteps'] ?? 0,
      totalCalories: (json['totalCalories'] ?? 0).toDouble(),
      totalActiveMinutes: json['totalActiveMinutes'] ?? 0,
      avgSpO2: json['avgSpO2'] != null ? (json['avgSpO2'] as num).toDouble() : null,
      sleepData: json['sleepData'] != null ? SleepData.fromJson(json['sleepData']) : null,
      stressLevel: (json['stressLevel'] ?? 0).toDouble(),
      mood: json['mood'] ?? 'neutral',
    );
  }
}

/// AI health analysis from LLM
class HealthAnalysis {
  final String id;
  final String userId;
  final DateTime timestamp;
  final String summary; // Brief state of the day
  final String action; // Concrete action to take
  final String breakfastSuggestion; // Suggested breakfast
  final String indicatorToWatch; // Key metric to monitor
  final List<String> alerts; // Threshold violations
  final String sleepRemark;
  final String sleepPractices;

  HealthAnalysis({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.summary,
    required this.action,
    required this.breakfastSuggestion,
    required this.indicatorToWatch,
    this.alerts = const [],
    required this.sleepRemark,
    required this.sleepPractices,
  });

  /// Convert analysis to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'summary': summary,
      'action': action,
      'breakfastSuggestion': breakfastSuggestion,
      'indicatorToWatch': indicatorToWatch,
      'alerts': alerts,
      'sleepRemark': sleepRemark,
    };
  }

  /// Create HealthAnalysis from JSON
  factory HealthAnalysis.fromJson(Map<String, dynamic> json) {
    DateTime timestamp;
    if (json['timestamp'] is Timestamp) {
      timestamp = (json['timestamp'] as Timestamp).toDate();
    } else if (json['timestamp'] is String) {
      timestamp = DateTime.parse(json['timestamp']);
    } else {
      timestamp = DateTime.now();
    }

    return HealthAnalysis(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      timestamp: timestamp,
      summary: json['summary'] ?? '',
      action: json['action'] ?? '',
      breakfastSuggestion: json['breakfastSuggestion'] ?? '',
      indicatorToWatch: json['indicatorToWatch'] ?? '',
      alerts: List<String>.from(json['alerts'] ?? []),
      // --- NOUVEAU CHAMP ---
      // Fournir une valeur par défaut si le champ n'existe pas encore dans Firestore
      sleepRemark: json['sleepRemark'] ?? 'Sleep analysis in progress ...',
        sleepPractices: json['sleepPractices'] ?? 'No specific sleep practice available. Aim for 7-9 hours of quality sleep.',

    );
  }
}