/// HomePage: Main landing page of the app
/// It includes greeting, current date, bottom navigation, and page body

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'user_settings_page.dart';
import 'meal_analysis_page.dart';
import 'ai_coaching_page.dart';
import 'healthcare_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _username = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            _username = doc.data()?['username'] ?? 'User';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _username = 'User';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _username = 'User';
          _isLoading = false;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Builds top AppBar with greeting, emoji, and current date
  Widget _buildAppBar() {
    final hour = DateTime.now().hour;
    final bool isMorning = hour >= 5 && hour < 18;
    final String greeting = isMorning ? 'Good morning' : 'Good night';
    final String emoji = isMorning ? '☀️' : '🌙';
    final String formattedDate =
    DateFormat('EEEE, MMM d').format(DateTime.now());

    return AppBar(

      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Container(
        width: double.infinity,
        color: const Color(0xFFF1F6F7), // la couleur bleu clair pour le texte seulement
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$greeting, $_username $emoji",
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );

  }

  /// Determines which page body to show based on selected bottom tab
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const HealthcarePage();
      case 1:
        return const AICoachingPage();
      case 2:
        return const MealAnalysisPage();
      default:
        return const UserSettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: PreferredSize( preferredSize: const Size.fromHeight(kToolbarHeight), child: _buildAppBar(), ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.robot,
              size: 22,),
            label: 'Coach',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Meals',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF65B8BF),
        unselectedItemColor: Colors.black,
        onTap: (index) {
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserSettingsPage(),
              ),
            );
          } else {
            _onItemTapped(index);
          }
        },
      ),
    );
  }
}
