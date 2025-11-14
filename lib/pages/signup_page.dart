/// This page allows new users to create an account.
/// It collects authentication data and basic profile information.
/// After registration, the user is redirected to UserSettingsPage
/// with prefilled initial values.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_settings_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  final _allergiesController = TextEditingController();

  String? _gender;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserSettingsPage(
              prefilledAge: _ageController.text,
              prefilledWeight: _weightController.text,
              prefilledGender: _gender,
              prefilledAllergies: _allergiesController.text,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An unknown error occurred. Please try again.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// UI BUILDING
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0A4D50);
    const Color accentColor = Color(0xFF65B8BF);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1E1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// App logo
                Image.asset(
                  'assets/images/logo.png',
                  height: 150,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height:0),
                /// Motivational subtitle
                const Text(
                  "Your health journey begins here",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 30),

                /// Title
                const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Email
                _buildTextFormField(
                  controller: _emailController,
                  labelText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your email';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password
                _buildTextFormField(
                  controller: _passwordController,
                  labelText: 'Password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() {
                      _obscurePassword = !_obscurePassword;
                    }),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a password';
                    if (value.length < 6) return 'Password must be at least 6 characters long';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // age and weight
                Row(
                  children: [
                    Expanded(
                      child: _buildTextFormField(
                        controller: _weightController,
                        labelText: 'Weight (kg)',
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Required'
                            : double.tryParse(v) == null
                            ? 'Invalid'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextFormField(
                        controller: _ageController,
                        labelText: 'Age',
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Required'
                            : int.tryParse(v) == null
                            ? 'Invalid'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Gender
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: _inputDecoration('Gender'),
                  hint: const Text('Gender'),
                  items: ['Male', 'Female', 'Other']
                      .map((label) => DropdownMenuItem(
                    value: label,
                    child: Text(label),
                  ))
                      .toList(),
                  onChanged: (value) => setState(() => _gender = value),
                  validator: (value) => value == null ? 'Please select a gender' : null,
                ),
                const SizedBox(height: 14),

                // Allergies (optional)
                _buildTextFormField(
                  controller: _allergiesController,
                  labelText: 'Allergies (Optional)',
                  hintText: 'e.g., Peanuts, Shellfish, Dairy',
                  validator: (value) => null, // Optional field
                ),
                const SizedBox(height: 22),

                _buildGoalSection(),
                const SizedBox(height: 24),

                /// SIGN UP BUTTON
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 14),

                /// NAVIGATE TO LOGIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?",
                        style: TextStyle(color: Colors.grey)),
                    TextButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(FontAwesomeIcons.heart, color: Color(0xFF0A4D50), size: 16),
            SizedBox(width: 8),
            Text(
              'Your Journey, Our Goals:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A4D50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGoalChip('Reduce stress', const Color(0xFFF28B89), FontAwesomeIcons.spa),
            const SizedBox(width: 6),
            _buildGoalChip('Eat better', const Color(0xFFA4D4A2), FontAwesomeIcons.carrot),
            const SizedBox(width: 6),
            _buildGoalChip('Boost energy', const Color(0xFFF0D286), FontAwesomeIcons.bolt),
          ],
        ),
      ],
    );
  }

  /// Chip builder used for each goal
  Widget _buildGoalChip(String label, Color color, IconData icon) {
    return Chip(
      avatar: FaIcon(
        icon,
        size: 10,
        color: Color(0xFFF1F6F7).withOpacity(0.7),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: Color(0xFFF1F6F7).withOpacity(0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color,
      labelPadding: const EdgeInsets.only(left: 3.0, right: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.black.withOpacity(0.05)),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: _inputDecoration(labelText, suffixIcon: suffixIcon, hintText: hintText),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration(String labelText, {Widget? suffixIcon, String? hintText}) {
    const Color borderColor = Color(0xFFD9E0E1);
    const Color focusColor = Color(0xFF65B8BF);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: focusColor, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Colors.grey),
      floatingLabelStyle: const TextStyle(color: focusColor),
    );
  }
}
