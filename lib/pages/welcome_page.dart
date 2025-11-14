/// This is the animated welcome screen shown when the app starts.
/// It fades in smoothly, displays the app logo and a meditation illustration,
/// then automatically redirects the user to AuthWrapper after 4 seconds.
///
import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    /// Start the fade-in animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });

    /// 🕒 Wait 4 seconds before navigating to the next page (AuthWrapper)
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF8F1E1);
    const Color primaryTextColor = Color(0xFF0A4D50);
    const Color secondaryTextColor = Color(0xFF5B6F6F);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(seconds: 2), // Duration of the fade-in effect
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  height: 150,
                ),

                const Spacer(flex: 1),

                // Illustration
                Image.asset(
                  'assets/images/meditation_illustration.png',
                  height: 250,
                ),
                const SizedBox(height: 30),

                // Title
                const Text(
                  "Find Your Calm\n& Recharge Daily",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle motivating the user
                const Text(
                  'Your daily AI coach for balance, energy and calm',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
