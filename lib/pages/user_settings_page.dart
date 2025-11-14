/// This page allows the user to view, edit, and save their personal

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';
import '../services/firebase_service.dart';

class UserSettingsPage extends StatefulWidget {
  final String? prefilledAge;
  final String? prefilledWeight;
  final String? prefilledGender;
  final String? prefilledAllergies;

  const UserSettingsPage({
    super.key,
    this.prefilledAge,
    this.prefilledWeight,
    this.prefilledGender,
    this.prefilledAllergies,
  });

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _allergiesController = TextEditingController();

  String _gender = 'Male';
  String _goal = 'Lose weight';

  bool _isLoading = true;
  bool _isSaving = false;

  File? _profileImageFile;
  String? _profileImageBase64;

  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _goalOptions = [
    'Lose weight',
    'Gain muscle',
    'Maintain fitness',
    'Improve endurance',
    'Gain strength',
    'Improve flexibility',
    'Rehabilitation',
    'General wellness',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledAge != null ||
        widget.prefilledWeight != null ||
        widget.prefilledGender != null ||
        widget.prefilledAllergies != null) {
      _ageController.text = widget.prefilledAge ?? '';
      _weightController.text = widget.prefilledWeight ?? '';
      _allergiesController.text = widget.prefilledAllergies ?? '';
      if (widget.prefilledGender != null &&
          _genderOptions.contains(widget.prefilledGender)) {
        _gender = widget.prefilledGender!;
      }
      _isLoading = false;
    } else {
      _loadUserProfile();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  /// Load user data
  Future<void> _loadUserProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _heightController.text = data['height']?.toString() ?? '';
          _weightController.text = data['weight']?.toString() ?? '';
          _allergiesController.text = data['allergies'] ?? '';
          _gender = _genderOptions.contains(data['gender']) ? data['gender'] : 'Male';
          _goal = _goalOptions.contains(data['goal']) ? data['goal'] : 'Lose weight';
          _profileImageBase64 = data['profileImageBase64'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Opens a bottom sheet to choose picture source
  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Profile Picture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            /// Option to take a photo
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            /// Option to choose from gallery
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_profileImageFile != null || _profileImageBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profileImageFile = null;
                    _profileImageBase64 = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Function to pick an image
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() {
          _profileImageFile = File(picked.path);
          _profileImageBase64 = null; // Reset base64 if new image picked
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// save updated profile
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      int? age = int.tryParse(_ageController.text.trim());
      double? height = double.tryParse(_heightController.text.trim());
      double? weight = double.tryParse(_weightController.text.trim());
      if (age == null || height == null || weight == null) throw 'Invalid numeric values';

      String? base64Image = _profileImageBase64;
      if (_profileImageFile != null) {
        base64Image = await FirebaseService.compressAndEncodeImage(_profileImageFile!.path);
      }

      final profileData = {
        'username': _usernameController.text.trim(),
        'age': age,
        'height': height,
        'weight': weight,
        'gender': _gender,
        'goal': _goal,
        'allergies': _allergiesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (base64Image != null) profileData['profileImageBase64'] = base64Image;

      await FirebaseFirestore.instance.collection('users').doc(uid).set(profileData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Log Put the user out of the app
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: Color(0xFF65B8BF)))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const focusColor = Color(0xFF65B8BF);
    final defaultColor = Colors.grey.shade600;

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: focusColor,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: focusColor,
          selectionColor: focusColor.withOpacity(0.4),
          selectionHandleColor: focusColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: defaultColor.withOpacity(0.5), width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: focusColor, width: 2.0),
          ),
          labelStyle: TextStyle(color: defaultColor),
          floatingLabelStyle: TextStyle(color: defaultColor),
          iconColor: MaterialStateColor.resolveWith((states) => states.contains(MaterialState.focused) ? focusColor : defaultColor),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile Settings'),
          actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _signOut)],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: focusColor))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _showImagePickerBottomSheet,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFFF1F6F7),
                          backgroundImage: _profileImageFile != null
                              ? FileImage(_profileImageFile!)
                              : (_profileImageBase64 != null ? MemoryImage(base64Decode(_profileImageBase64!)) as ImageProvider : null),
                          child: (_profileImageFile == null && _profileImageBase64 == null) ? const Icon(Icons.person, size: 50, color: focusColor) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(radius: 18, backgroundColor: focusColor, child: const Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                /// ---------------- USERNAME ----------------
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person)),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter a username' : null,
                ),
                const SizedBox(height: 16),
                /// ---------------- GENDER ----------------
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
                  items: _genderOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(height: 16),
                /// ---------------- AGE ----------------
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake), suffixText: 'years'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your age';
                    final age = int.tryParse(v);
                    if (age == null || age < 1 || age > 120) return 'Enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                /// ---------------- HEIGHT ----------------
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height', prefixIcon: Icon(Icons.height), suffixText: 'cm'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter height';
                    final h = double.tryParse(v);
                    if (h == null || h < 50 || h > 300) return 'Enter a valid height';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                /// ---------------- WEIGHT ----------------
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight', prefixIcon: Icon(Icons.monitor_weight), suffixText: 'kg'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter weight';
                    final w = double.tryParse(v);
                    if (w == null || w < 20 || w > 500) return 'Enter a valid weight';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                /// ---------------- ALLERGIES ----------------
                TextFormField(
                  controller: _allergiesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Allergies (Optional)', prefixIcon: Icon(Icons.warning)),
                ),
                const SizedBox(height: 16),
                /// ---------------- GOAL ----------------
                DropdownButtonFormField<String>(
                  value: _goal,
                  decoration: const InputDecoration(labelText: 'Fitness & Health Goal', prefixIcon: Icon(Icons.flag)),
                  items: _goalOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _goal = v!),
                ),
                const SizedBox(height: 30),
                ///---------------- SAVE BUTTON ----------------
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: focusColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  )
                      : const Text(
                    'Save Profile',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ---------------- SIGN OUT BUTTON ----------------
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: focusColor),
                  label: const Text('Sign Out', style: TextStyle(color: focusColor)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: focusColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
