/// This service handles all communication between the Flutter app and
/// Firebase (Firestore + Storage) AND the AI backend server.
/// Its responsibilities include:
///      • Calling the AI backend to get event recommendations
///       • Compressing and encoding images (free, local solution)
///      • Uploading profile images to Firebase Storage
///      • Saving and retrieving meal analyses from Firestore
///       • Saving daily summaries and deleting daily meals after summary
///       • Cleaning / formatting Firestore data for AI analysis
///      • Saving and retrieving health metrics, sleep data, and daily health summaries
///      • Storing LLM-generated health analyses
///      This file centralizes **all user data operations** of the app.
library;

import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/meal_models.dart';
import '../models/health_models.dart';
import 'package:http/http.dart' as http;


class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  ///                     use: 'http://YOUR_COMPUTER_IP:8000'
  static const String baseUrl = 'http://0.0.0.0:8000';

  /// AI BACKEND  — GENERATE EVENT RECOMMENDATION
  /// Sends event info to the AI server and receives recommendation
  static Future<EventRecommendation?> getEventRecommendation(
      String eventTitle,
      DateTime startTime,
      DateTime endTime,
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-event-recommendation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'eventTitle': eventTitle,
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return EventRecommendation.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getting event recommendation: $e');
      return null;
    }
  }

  /// IMAGE HANDLING — COMPRESS AND CONVERT TO BASE64
  /// Used to send image to backend or store locally without Firebase Storage
  static Future<String> compressAndEncodeImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();

      /// Decode the image file
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Impossible de décoder l\'image');
      }

      final resized = image.width > 800
          ? img.copyResize(image, width: 800)
          : image;

      /// Compress to JPEG at 85% quality
      final compressed = img.encodeJpg(resized, quality: 85);

      /// Convert to Base64 string
      final base64String = base64Encode(compressed);

      if (kDebugMode) {
        print('Image compressée: ${bytes.length} bytes → ${compressed.length} bytes');
      }
      return base64String;
    } catch (e) {
      throw Exception('Erreur lors de la compression de l\'image: $e');
    }
  }

  /// UPLOAD PROFILE IMAGE TO FIREBASE STORAGE
  /// Image is resized and compressed before upload
  static Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      print('📤 Uploading profile image for user: $userId');

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final resized = image.width > 500
          ? img.copyResize(image, width: 500, height: 500)
          : image;

      /// Compress to JPEG
      final compressed = img.encodeJpg(resized, quality: 90);

      print('Image compressée: ${bytes.length} bytes → ${compressed.length} bytes');

      /// Upload to Firebase Storage path
      final ref = _storage.ref().child('profile_images/$userId/profile.jpg');

      final uploadTask = ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Profile image uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading profile image: $e');
      throw Exception('Erreur lors de l\'upload de l\'image de profil: $e');
    }
  }

  /// SAVE MEAL ANALYSIS TO FIRESTORE
  /// Optionally includes compressed base64 image
  static Future<void> saveMealAnalysis(MealAnalysis analysis, String? imagePath) async {
    try {
      // Convert to JSON
      final data = <String, dynamic>{
        'id': analysis.id,
        'userId': analysis.userId,
        'mealType': analysis.mealType,
        'timestamp': Timestamp.fromDate(analysis.timestamp), // Utiliser Timestamp de Firestore
        'imageUrl': analysis.imageUrl,
        'dishName': analysis.dishName,
        'ingredients': analysis.ingredients,
        'nutrition': analysis.nutrition.toJson(),
        'healthAdvice': analysis.healthAdvice,
        'recommendation': analysis.recommendation,
        'isTryAnalysis': analysis.isTryAnalysis,
      };

      /// If an image was provided → compress then attach base64
      if (imagePath != null && imagePath.isNotEmpty) {
        final base64Image = await compressAndEncodeImage(imagePath);
        data['imageBase64'] = base64Image;
      }

      await _firestore
          .collection('users')
          .doc(analysis.userId)
          .collection('mealAnalyses')
          .doc(analysis.id)
          .set(data);
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde de l\'analyse: $e');
    }
  }

  /// GET MEAL ANALYSES FOR A SPECIFIC DAY
  /// Query simplified to avoid composite indexes, filtered locally by date
  static Future<List<MealAnalysis>> getDailyMealAnalyses(
      String userId,
      DateTime date,
      ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Simplified query - filter client-side to avoid composite index
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('mealAnalyses')
          .where('isTryAnalysis', isEqualTo: false)
          .get();

      // Filter by date on client side
      return snapshot.docs
          .map((doc) => MealAnalysis.fromJson(doc.data()))
          .where((meal) {
        return meal.timestamp.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
            meal.timestamp.isBefore(endOfDay);
      })
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      throw Exception('Erreur lors de la récupération des analyses: $e');
    }
  }

  /// SAVE DAILY SUMMARY (nutrition totals for the day)
  static Future<void> saveDailySummary(DailySummary summary) async {
    try {
      await _firestore
          .collection('users')
          .doc(summary.userId)
          .collection('dailySummaries')
          .doc(summary.id)
          .set(summary.toJson());
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde du résumé: $e');
    }
  }

  /// DELETE ALL MEALS OF A DAY (used after generating a summary)
  static Future<void> deleteDailyMeals(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('mealAnalyses')
          .where('isTryAnalysis', isEqualTo: false)
          .get();

      final docsToDelete = snapshot.docs.where((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'];
        DateTime? mealDate;

        if (timestamp is Timestamp) {
          mealDate = timestamp.toDate();
        } else if (timestamp is DateTime) {
          mealDate = timestamp;
        } else if (timestamp is String) {
          mealDate = DateTime.tryParse(timestamp);
        }

        if (mealDate == null) {
          return false;
        }

        return !mealDate.isBefore(startOfDay) && mealDate.isBefore(endOfDay);
      }).toList();

      if (docsToDelete.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in docsToDelete) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Erreur lors de la suppression des repas du jour: $e');
    }
  }

  /// DELETE DAILY SUMMARY
  static Future<void> deleteDailySummary(String userId, String summaryId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummaries')
          .doc(summaryId)
          .delete();
    } catch (e) {
      throw Exception('Erreur lors de la suppression du résumé: $e');
    }
  }

  /// GET DAILY SUMMARIES HISTORY
  static Future<List<DailySummary>> getDailySummaries(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummaries')
          .orderBy('date', descending: true)
          .limit(7)
          .get();

      return snapshot.docs
          .map((doc) => DailySummary.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// GET USER PROFILE — CLEAN FIRESTORE DATA FOR AI BACKEND
  /// Converts Timestamp → ISO date, maps → cleaned maps...
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data() ?? {};
      return _sanitizeFirestoreData(data);
    } catch (e) {
      throw Exception('Erreur lors de la récupération du profil: $e');
    }
  }

  /// // Convert Firestore values (Timestamp, nested maps...) to backend-friendly types
  static Map<String, dynamic> _sanitizeFirestoreData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      result[key] = _convertValue(value);
    });
    return result;
  }

  static dynamic _convertValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is Map<String, dynamic>) {
      return _sanitizeFirestoreData(value);
    }
    if (value is List) {
      return value.map(_convertValue).toList();
    }
    return value;
  }

  /// Save health metrics from smartwatch
  static Future<void> saveHealthMetrics(HealthMetrics metrics) async {
    try {
      await _firestore
          .collection('users')
          .doc(metrics.userId)
          .collection('health_metrics')
          .doc(metrics.id)
          .set({
        'id': metrics.id,
        'userId': metrics.userId,
        'timestamp': Timestamp.fromDate(metrics.timestamp),
        'heartRate': metrics.heartRate,
        'restingHeartRate': metrics.restingHeartRate,
        'hrv': metrics.hrv,
        'steps': metrics.steps,
        'calories': metrics.calories,
        'activeMinutes': metrics.activeMinutes,
        'spo2': metrics.spo2,
      });
    } catch (e) {
      throw Exception('Error saving health metrics: $e');
    }
  }

  /// Get health metrics for a specific day
  static Future<List<HealthMetrics>> getDailyHealthMetrics(
      String userId,
      DateTime date,
      ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_metrics')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp')
          .get();

      return snapshot.docs
          .map((doc) => HealthMetrics.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error fetching health metrics: $e');
    }
  }

  /// Save sleep data
  static Future<void> saveSleepData(SleepData sleepData) async {
    try {
      await _firestore
          .collection('users')
          .doc(sleepData.userId)
          .collection('sleep_data')
          .doc(sleepData.id)
          .set({
        'id': sleepData.id,
        'userId': sleepData.userId,
        'date': Timestamp.fromDate(sleepData.date),
        'durationHours': sleepData.durationHours,
        'qualityScore': sleepData.qualityScore,
        'deepSleepMinutes': sleepData.deepSleepMinutes,
        'remSleepMinutes': sleepData.remSleepMinutes,
        'lightSleepMinutes': sleepData.lightSleepMinutes,
      });
    } catch (e) {
      throw Exception('Error saving sleep data: $e');
    }
  }

  /// Get sleep data for a specific date
  static Future<SleepData?> getSleepData(String userId, DateTime date) async {
    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sleep_data')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateOnly))
          .where('date', isLessThan: Timestamp.fromDate(dateOnly.add(const Duration(days: 1))))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return SleepData.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Error fetching sleep data: $e');
    }
  }

  /// Save daily health summary
  static Future<void> saveDailyHealthSummary(DailyHealthSummary summary) async {
    try {
      final data = summary.toJson();
      // Convert timestamp
      data['date'] = Timestamp.fromDate(summary.date);

      await _firestore
          .collection('users')
          .doc(summary.userId)
          .collection('daily_health_summaries')
          .doc(summary.id)
          .set(data);
    } catch (e) {
      throw Exception('Error saving health summary: $e');
    }
  }

  /// Save health analysis from LLM
  static Future<void> saveHealthAnalysis(HealthAnalysis analysis) async {
    try {
      await _firestore
          .collection('users')
          .doc(analysis.userId)
          .collection('health_analyses')
          .doc(analysis.id)
          .set({
        'id': analysis.id,
        'userId': analysis.userId,
        'timestamp': Timestamp.fromDate(analysis.timestamp),
        'summary': analysis.summary,
        'action': analysis.action,
        'breakfastSuggestion': analysis.breakfastSuggestion,
        'indicatorToWatch': analysis.indicatorToWatch,
        'alerts': analysis.alerts,
      });
    } catch (e) {
      throw Exception('Error saving health analysis: $e');
    }
  }

  /// Get latest health analysis
  static Future<HealthAnalysis?> getLatestHealthAnalysis(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_analyses')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return HealthAnalysis.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Error fetching health analysis: $e');
    }
  }

  /// Get health analysis for today
  static Future<HealthAnalysis?> getTodayHealthAnalysis(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_analyses')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return HealthAnalysis.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Error fetching today\'s analysis: $e');
    }
  }
}