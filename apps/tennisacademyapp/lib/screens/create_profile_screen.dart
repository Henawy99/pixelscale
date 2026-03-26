import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _yearController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  File? _avatarFile;
  DateTime? _dob;
  String? _preferredHand; // "Right", "Left", "Both"
  bool _saving = false;

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked != null) {
        setState(() => _avatarFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your Date of Birth')));
      return;
    }
    if (_preferredHand == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your preferred hand')));
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.user!.id;
      
      String? avatarUrl;
      if (_avatarFile != null) {
        final bytes = await _avatarFile!.readAsBytes();
        final ext = _avatarFile!.path.split('.').last;
        avatarUrl = await AuthService.uploadAvatar(uid, bytes, 'avatar_$uid.$ext');
      }

      await AuthService.updateProfile(uid, {
        'date_of_birth': _dob!.toIso8601String().split('T')[0],
        'started_playing_year': int.parse(_yearController.text.trim()),
        'dominant_hand': _preferredHand,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      });

      await auth.refreshProfile(); // Reloads user properties to advance navigation!
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      setState(() => _saving = false);
    }
  }

  Widget _buildHandSelect(String value, IconData icon) {
    final isSelected = _preferredHand == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _preferredHand = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFDE21) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? Colors.orange.shade800 : Colors.grey.shade300, width: isSelected ? 2 : 1),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFFDE21).withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: isSelected ? Colors.orange.shade900 : Colors.grey.shade600),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? Colors.orange.shade900 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Profile'),
        automaticallyImplyLeading: false, // Force them to complete it!
      ),
      body: _saving 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Welcome! Let’s set up your player profile.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 32),
                  
                  // Avatar Section
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                            child: _avatarFile == null ? Icon(Icons.person, size: 50, color: Colors.grey.shade400) : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFFFFDE21), shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 20, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // DOB Section
                  Text('Date of Birth', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 12),
                          Text(_dob == null ? 'Select Date' : DateFormat('MMM d, yyyy').format(_dob!), style: TextStyle(fontSize: 16, color: _dob == null ? Colors.grey.shade600 : Colors.black)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Year started
                  Text('Year you started playing Tennis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 2015',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: const Icon(Icons.sports_tennis),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter the year you started playing';
                      final numValue = int.tryParse(v);
                      if (numValue == null || numValue < 1900 || numValue > DateTime.now().year) return 'Enter a valid year';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Preferred Hand
                  Text('Preferred Hand', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildHandSelect('Left', Icons.pan_tool),
                      _buildHandSelect('Right', Icons.front_hand),
                      _buildHandSelect('Both', Icons.waving_hand),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Complete Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
