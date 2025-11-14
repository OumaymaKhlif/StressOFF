/// This page provides a comprehensive healthcare dashboard for the user.
/// It displays daily health metrics such as sleep, stress index, activity data,
/// alerts, calendar reminders, and AI-based health insights.
/// Users can also trigger an analysis of their daily data to receive recommendations.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_models.dart';
import '../services/firebase_service.dart';
import '../services/health_analysis_service.dart';
import '../main.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/calender_service.dart';


class HealthcarePage extends StatefulWidget {
  const HealthcarePage({Key? key}) : super(key: key);
  @override
  State<HealthcarePage> createState() => _HealthcarePageState();
}

class _HealthcarePageState extends State<HealthcarePage> {
  bool _isLoading = true;
  bool _isAnalyzing = false;
  SleepData? _todaySleep;
  String? _sleepRemark;
  List<HealthMetrics> _todayMetrics = [];
  Map<String, dynamic>? _latestAnalysis;
  List<String> _alerts = [];
  int _stressIndex = 0; // 0-100
  String _dailyQuote = "Take a deep breath. You are doing great.";
  List<String> _stressTips = [];
  List<CalendarEvent> _todayEvents = [];
  List<EventRecommendation> _eventRecommendations = [];

  /// Calendar events & recommendations
  Future<void> _triggerSystemNotification(String alert) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'health_alerts_channel',
      'Health Alerts',
      channelDescription: 'Notifications for health alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unique
      '⚠️ Health Alert',
      alert,
      platformDetails,
    );
  }

  /// Predefined motivational quotes to reduce stress
  final List<String> _stressQuotes = [
    "Breathe. Your calm is stronger than your chaos.",
    "Let today be lighter than yesterday.",
    "You don’t have to control everything — just your breathing.",
    "Pause. Inhale peace, exhale pressure.",
    "The storm in your mind always passes. Let it rain, then shine.",
    "Peace is not the absence of problems, but the presence of balance.",
    "You are allowed to rest. That’s also progress.",
    "Your body whispers before it screams — listen early.",
    "Even mountains are shaped slowly. Be patient with yourself.",
    "Calm is not found, it’s created — one deep breath at a time.",
    "Smile softly. It confuses stress.",
    "Tension is energy. Redirect it into something beautiful.",
    "You’re not behind — you’re exactly where your growth happens.",
    "Some days need less doing and more breathing.",
    "A calm mind sees clearer paths.",
    "Rest isn’t weakness — it’s maintenance.",
    "Your heartbeat is your body’s applause for staying alive.",
    "Stress fades when gratitude enters.",
    "Slow down. You move faster when your mind is quiet.",
    "Be gentle with yourself — you’re learning peace.",
  ];


  @override
  void initState() {
    super.initState();
    _loadTodayData();
    _selectDailyQuote();
    _loadTodayEvents();
  }

  /// Load today's health data (metrics, sleep, analysis, alerts)
  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('[Healthcare] No user logged in');
        return;
      }

      print('[Healthcare] Loading data for user: $userId');
      final today = DateTime.now();
      print('[Healthcare] Today date: $today');

      /// Load today's metrics and sleep
      final metrics = await FirebaseService.getDailyHealthMetrics(userId, today);
      print('[Healthcare] Loaded ${metrics.length} health metrics');

      /// Load today's sleep data
      final sleep = await FirebaseService.getSleepData(userId, today);
      print('[Healthcare] Sleep data: ${sleep != null ? "found" : "not found"}');

      /// Check if we have today's analysis
      final analysis = await FirebaseService.getTodayHealthAnalysis(userId);
      print('[Healthcare] Analysis: ${analysis != null ? "found" : "not found"}');

      setState(() {
        _todayMetrics = metrics;
        _todaySleep = sleep;
        if (analysis != null) {
          _latestAnalysis = {
            'summary': analysis.summary,
            'action': analysis.action,
            'breakfastSuggestion': analysis.breakfastSuggestion,
            'indicatorToWatch': analysis.indicatorToWatch,
            'sleepRemark': analysis.sleepRemark,
          };
          _alerts = analysis.alerts;
          _sleepRemark = analysis.sleepRemark;
        }
      });
      /// generate tips based on stress index
      _generateStressTips();

      /// Display alerts & notifications
      if (_alerts.isNotEmpty && mounted) {
        for (String alert in _alerts) {
          _showAlertNotification(alert);
          _triggerSystemNotification(alert);
        }
      }

      // Auto-analyze if no analysis exists yet and we have data
      if (analysis == null && metrics.isNotEmpty) {
        await _analyzeNow();
      }

    } catch (e) {
      print('Error loading health data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Pick a daily motivational quote
  void _selectDailyQuote() {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year)).inDays;
    _dailyQuote = _stressQuotes[dayOfYear % _stressQuotes.length];
  }

  /// Generate stress-relief tips based on the calculated stress index
  void _generateStressTips() {
    _stressTips.clear();

    final stressIndex = _calculateStressIndex(); // 0-100

    if (stressIndex < 50) { // Low stress
      _stressTips = [
        "✓ Maintain your calm by practicing short 2-3 minute breathing breaks throughout the day.",
        "✓ Keep a gratitude journal to reinforce positive mindset and resilience.",
        "✓ Continue light physical activity like walking or stretching to sustain energy balance.",
      ];
    } else if (stressIndex < 70) { // Moderate stress
      _stressTips = [
        "✓ Take 5 minutes of mindful breathing: Inhale for 4s, hold 4s, exhale 6s to restore focus.",
        "✓ Schedule brief physical movement or stretching sessions to reduce tension.",
        "✓ Limit caffeine or heavy screen exposure in the evening to ease nervous system strain.",
      ];
    } else { // High stress
      _stressTips = [
        "✓ Engage in a 10-minute guided meditation or deep breathing session to lower acute stress.",
        "✓ Prioritize restorative activities: a short walk in nature, yoga, or light stretching.",
        "✓ Reduce cognitive load: delegate tasks, take breaks, and focus on one thing at a time.",
      ];
    }
  }

  Future<void> _loadTodayEvents() async {
    try {
      final hasPermission = await CalendarService.requestCalendarPermission();
      if (!hasPermission) {
        print('[Healthcare] Calendar permission denied');
        return;
      }

      final events = await CalendarService.getTodayEvents();

      List<EventRecommendation> recommendations = [];
      for (var event in events) {
        final recommendation = await FirebaseService.getEventRecommendation(
          event.title,
          event.startTime,
          event.endTime,
        );
        if (recommendation != null) {
          recommendations.add(recommendation);
        }
      }

      setState(() {
        _todayEvents = events;
        _eventRecommendations = recommendations;
      });
    } catch (e) {
      print('Error loading calendar events: $e');
    }
   }


  /// 🔔  Display in-app alert notification as snackbar
  void _showAlertNotification(String alert) {
    if (!mounted) return;
    Future.delayed(Duration(milliseconds: 300), () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFFCC7567), // Couleur orange/rouge
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    });
  }

  /// Compute stress index (0-100) from heart rate, sleep, and activity
  int _calculateStressIndex() {
    if (_todayMetrics.isEmpty) return 0;

    int stressScore = 0;

    /// Heart rate analysis
    final avgHR = _todayMetrics.map((m) => m.heartRate).reduce((a, b) => a + b) / _todayMetrics.length;
    if (avgHR > 100) stressScore += 30;
    else if (avgHR > 80) stressScore += 15;
    else stressScore += 5;

    /// Sleep analysis
    if (_todaySleep != null) {
      if (_todaySleep!.qualityScore < 50) stressScore += 30;
      else if (_todaySleep!.qualityScore < 70) stressScore += 15;
      else stressScore += 5;
    }

    // Activity analysis
    final totalSteps = _todayMetrics.fold<int>(0, (sum, m) => sum + m.steps);
    if (totalSteps < 3000) stressScore += 20; // Insuffisant
    else if (totalSteps > 20000) stressScore += 10; // Suractivité
    else stressScore += 5; // Bon

    return (stressScore * 0.7).toInt().clamp(0, 100);
  }

  /// Trigger AI analysis for today and save results
  Future<void> _analyzeNow() async {
    if (_todayMetrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No health data recorded today')),
      );
      return;
    }
    setState(() => _isAnalyzing = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userProfile = await FirebaseService.getUserProfile(userId);

      // Call backend for analysis
      final result = await HealthAnalysisService.analyzeHealth(
        userId: userId,
        date: DateTime.now(),
        metrics: _todayMetrics,
        sleepData: _todaySleep,
        userProfile: userProfile,
      );

      // Save analysis to Firestore
      final analysis = HealthAnalysis(
        id: '${userId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        timestamp: DateTime.now(),
        summary: result['summary'] ?? '',
        action: result['action'] ?? '',
        breakfastSuggestion: result['breakfastSuggestion'] ?? '',
        indicatorToWatch: result['indicatorToWatch'] ?? '',
        alerts: List<String>.from(result['alerts'] ?? []),
        sleepRemark: result['sleepRemark'] ?? 'No detailed sleep analysis available.',
        sleepPractices: result['sleepPractices'] ?? ''  ,
      );

      await FirebaseService.saveHealthAnalysis(analysis);

      setState(() {
        _latestAnalysis = result;
        _alerts = List<String>.from(result['alerts'] ?? []);
        _sleepRemark = result['sleepRemark'];
        // Régénérer les tips en fonction du nouveau stress index
        _generateStressTips();
      });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analysis Complete ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis Error: $e'),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadTodayData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 20),

          // Alerts section
          if (_alerts.isNotEmpty) ...[
            _buildAlertsCard(),
            const SizedBox(height: 16),
          ],

          if (_todayEvents.isNotEmpty) ...[
            _buildCalendarRemindersCard(),
            const SizedBox(height: 16),
          ],

          // Stress Analysis Card
          _buildStressAnalysisCard(),
          const SizedBox(height: 16),

          // Main cards
          _buildSleepCard(),
          const SizedBox(height: 16),
          _buildEnergyCard(),
          const SizedBox(height: 16),
          _buildAIAdviceCard(),
          const SizedBox(height: 24),

          // Analyze button
          _buildAnalyzeButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Find Your Balance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Balance is not something you find, it's something you create.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildAlertsCard() {
    return Card(
      color: Color(0xFFF4E4E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Color(0xFFCC7567)),
                const SizedBox(width: 8),
                Text(
                  'Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCC7567),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• $alert', style: const TextStyle(fontSize: 14)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarRemindersCard() {
    return Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event, size: 32, color: Color(0xFF65B8BF)),
                  const SizedBox(width: 12),
                  const Text(
                    'Reminders',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_todayEvents.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No events scheduled for today',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ..._eventRecommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFF65B8BF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Color(0xFF65B8BF)),
                            const SizedBox(width: 8),
                            Text(
                              rec.eventTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              rec.eventTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rec.practices,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFFF1F6F7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.restaurant, size: 16, color: Color(0xFF65B8BF)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rec.nutritionSuggestion,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            ],
          ),
        ),
    );
  }

  Widget _buildStressAnalysisCard() {
    _stressIndex = _calculateStressIndex();

    Color stressColor = Colors.green;
    String stressLevel = 'Low';

    if (_stressIndex >= 70) {
      stressColor = Colors.red;
      stressLevel = 'High';
    } else if (_stressIndex >= 50) {
      stressColor = Colors.orange;
      stressLevel = 'Moderate';
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.psychology, size: 32, color: Color(0xFF65B8BF)),
                const SizedBox(width: 12),
                const Text(
                  'Stress Analysis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF1F6F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFF1F6F7)!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, size: 20, color: Color(0xFF65B8BF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dailyQuote,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stress Index',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: stressColor.withOpacity(0.2),
                        border: Border.all(color: stressColor, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_stressIndex/100 - $stressLevel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: stressColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _stressIndex / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(stressColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stressLevel == 'Low'
                      ? 'Your stress levels are well-managed ✨'
                      : stressLevel == 'Moderate'
                      ? 'Try some relaxation techniques'
                      : 'Take time to de-stress and relax',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stress-Relief Tips',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ..._stressTips.take(3).map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime, size: 32, color: Colors.indigo[700]),
                const SizedBox(width: 12),
                const Text(
                  'Sleep',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_sleepRemark != null && _sleepRemark!.isNotEmpty && (_todaySleep != null)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 18.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sleepRemark!,
                        style: const TextStyle(
                            fontStyle: FontStyle.italic, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(FontAwesomeIcons.personBiking, size: 18),
                  ],
                ),
              ),
            ],

            if (_todaySleep != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    '${_todaySleep!.durationHours.toStringAsFixed(1)}h',
                    'Duration',
                    Icons.access_time,
                    Colors.indigo,
                  ),
                  _buildStatColumn(
                    '${_todaySleep!.deepSleepMinutes} min',
                    'Deep Sleep',
                    FontAwesomeIcons.bed,
                    Colors.indigo[700]!,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    '${_todaySleep!.qualityScore.toInt()}/100',
                    'Quality',
                    Icons.star,
                    Colors.amber,
                  ),
                  _buildStatColumn(
                    '${_todaySleep!.remSleepMinutes} min',
                    'REM Sleep',
                    FontAwesomeIcons.moon,
                    Color(0xFF65B8BF),
                  ),


                ],
              ),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No sleep data available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildEnergyCard() {
    final totalSteps = _todayMetrics.fold<int>(0, (sum, m) => sum + m.steps);
    final totalCalories = _todayMetrics.fold<double>(0, (sum, m) => sum + m.calories);
    final avgHR = _todayMetrics.isEmpty ? 0.0 :
    _todayMetrics.map((m) => m.heartRate).reduce((a, b) => a + b) / _todayMetrics.length;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, size: 32, color: Colors.orange[700]),
                const SizedBox(width: 12),
                const Text(
                  'Daily Energy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_todayMetrics.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    totalSteps.toString(),
                    'Steps',
                    Icons.directions_walk,
                    Colors.green,
                  ),
                  _buildStatColumn(
                    '${totalCalories.toInt()}',
                    'Calories',
                    Icons.local_fire_department,
                    Colors.red,
                  ),
                  _buildStatColumn(
                    '${avgHR.toInt()} bpm',
                    'Avg HR',
                    Icons.favorite,
                    Colors.pink,
                  ),
                ],
              ),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No Activity Data Available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAdviceCard() {
    return Card(
      elevation: 3, // même effet d'ombre que Sleep et Energy
      color: const Color(0xFFF1F6F7),
      child: Padding(
        padding: const EdgeInsets.all(20), // même padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, size: 32, color: Colors.grey[800]),
                const SizedBox(width: 12),
                const Text(
                  'AI Insights',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_latestAnalysis != null) ...[
              _buildAdviceSection(
                'Summary',
                _latestAnalysis!['summary'] ?? '',
                Icons.summarize,
              ),
              const SizedBox(height: 16),
              _buildAdviceSection(
                "Today's Activities",
                _latestAnalysis!['action'] ?? '',
                Icons.check_circle_outline,
              ),
              const SizedBox(height: 16),
              _buildAdviceSection(
                'Breakfast Suggestion',
                _latestAnalysis!['breakfastSuggestion'] ?? '',
                Icons.breakfast_dining,
              ),
              const SizedBox(height: 16),

              // Section "Better Sleep Practices"
              if (_latestAnalysis!['sleepPractices'] != null &&
                  _latestAnalysis!['sleepPractices'].isNotEmpty &&
                  _todaySleep != null) ...[
                _buildAdviceSection(
                  'Better Sleep Practices',
                  _latestAnalysis!['sleepPractices'],
                  FontAwesomeIcons.moon,
                ),
                const SizedBox(height: 16),
              ],

              _buildAdviceSection(
                'Key Metric',
                _latestAnalysis!['indicatorToWatch'] ?? '',
                Icons.track_changes,
              ),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Tap "Analyze My Day" to get AI insights',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAdviceSection(String title, String content, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[800]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isAnalyzing ? null : _analyzeNow,
        icon: _isAnalyzing
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.analytics),
        label: Text(_isAnalyzing ? 'Analyzing… ⏳' : 'Analyze My Day'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: Color(0xFF65B8BF),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
