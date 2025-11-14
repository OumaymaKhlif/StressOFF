/// This service handles communication with the backend to analyze
/// user health data using an AI model. It gathers smartwatch metrics,
/// sleep data, and user profile, sends them to the backend, and
/// retrieves insights and recommendations.
/// Main responsibilities:
/// 1. Send daily health data (HRV, heart rate, steps, SpO2...) to backend
/// 2. Receive AI-generated health analysis and suggestions
/// 3. Perform local threshold checks (HRV drops, low SpO2, poor sleep)
/// 4. Return alerts that can be used inside the app UI
///
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_models.dart';

class HealthAnalysisService {
  ///                     use: 'http://YOUR_COMPUTER_IP:8000'
  static const String baseUrl = 'http://0.0.0.0:8000';

  /// Analyze health data and get AI recommendations
  static Future<Map<String, dynamic>> analyzeHealth({
    required String userId,
    required DateTime date,
    required List<HealthMetrics> metrics,
    SleepData? sleepData,
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/analyze-health');

      final body = {
        'userId': userId,
        'date': date.toIso8601String(),
        'metrics': metrics.map((m) => {
          'timestamp': m.timestamp.toIso8601String(),
          'heartRate': m.heartRate,
          'restingHeartRate': m.restingHeartRate,
          'hrv': m.hrv,
          'steps': m.steps,
          'calories': m.calories,
          'activeMinutes': m.activeMinutes,
          'spo2': m.spo2,
        }).toList(),
        if (sleepData != null) 'sleepData': {
          'durationHours': sleepData.durationHours,
          'qualityScore': sleepData.qualityScore,
          'deepSleepMinutes': sleepData.deepSleepMinutes,
          'remSleepMinutes': sleepData.remSleepMinutes,
          'lightSleepMinutes': sleepData.lightSleepMinutes,
        },
        if (userProfile != null) 'userProfile': userProfile,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Health analysis failed');
      }
    } catch (e) {
      throw Exception('Error analyzing health data: $e');
    }
  }

  /// Check for threshold violations and return alerts
  static List<String> checkThresholds({
    required List<HealthMetrics> metrics,
    SleepData? sleepData,
  }) {
    final alerts = <String>[];

    if (metrics.isEmpty) return alerts;

    // Check HRV drop
    if (metrics.length > 2) {
      final hrvValues = metrics.map((m) => m.hrv).toList();
      final halfPoint = hrvValues.length ~/ 2;
      final baselineHRV = hrvValues.sublist(0, halfPoint).reduce((a, b) => a + b) / halfPoint;
      final recentHRV = hrvValues.sublist(halfPoint).reduce((a, b) => a + b) / (hrvValues.length - halfPoint);

      if (baselineHRV > 0 && (baselineHRV - recentHRV) / baselineHRV > 0.20) {
        alerts.add('⚠️ HRV a chuté de plus de 20% - possible stress ou surentraînement');
      }
    }

    /// Check sleep duration
    if (sleepData != null && sleepData.durationHours < 6) {
      alerts.add('😴 Sommeil insuffisant: ${sleepData.durationHours.toStringAsFixed(1)}h (recommandé: 7-9h)');
    }

    /// Check SpO2
    final spo2Values = metrics.where((m) => m.spo2 != null).map((m) => m.spo2!).toList();
    if (spo2Values.isNotEmpty) {
      final avgSpO2 = spo2Values.reduce((a, b) => a + b) / spo2Values.length;
      if (avgSpO2 < 94) {
        alerts.add('🫁 Oxygène sanguin faible: ${avgSpO2.toStringAsFixed(1)}% (normal: >95%)');
      }
    }

    /// Check sedentary behavior
    final totalActiveMinutes = metrics.fold<int>(0, (sum, m) => sum + m.activeMinutes);
    if (totalActiveMinutes < 120) {  // Less than 2h active in 24h
      alerts.add('🚶 Activité très faible - essayez de bouger plus durant la journée');
    }

    return alerts;
  }
}