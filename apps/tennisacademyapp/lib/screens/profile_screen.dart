import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _yearController = TextEditingController();
  DateTime? _dob;
  String? _dominantHand; // Right, Left, Both
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final p = context.read<AuthProvider>().profile;
    if (p != null) {
      _phoneController.text = p.phone ?? '';
      _yearController.text = p.startedPlayingYear?.toString() ?? '';
      _dob = p.dateOfBirth;
      _dominantHand = p.dominantHand;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final userId = context.read<AuthProvider>().user!.id;
      final ext = picked.path.split('.').last;
      final url = await AuthService.uploadAvatar(userId, bytes, 'avatar.$ext');
      if (url != null) {
        await AuthService.updateProfile(userId, {'avatar_url': url});
        await context.read<AuthProvider>().refreshProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final userId = context.read<AuthProvider>().user!.id;
      await AuthService.updateProfile(userId, {
        'phone': _phoneController.text.trim(),
        'started_playing_year': int.tryParse(_yearController.text.trim()),
        'date_of_birth': _dob?.toIso8601String(),
        'dominant_hand': _dominantHand,
      });
      await context.read<AuthProvider>().refreshProfile();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AuthProvider>().profile;
    if (p == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _uploading ? null : _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                  child: _uploading
                      ? const CircularProgressIndicator()
                      : p.avatarUrl == null
                          ? const Icon(Icons.camera_alt, size: 40)
                          : null,
                ),
              ),
              const SizedBox(height: 8),
              Text('Tap to change photo', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.length < 8) return 'Enter valid phone';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of Birth', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)),
                  child: Text(_dob == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(_dob!)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(labelText: 'Year Started Playing', border: OutlineInputBorder(), prefixIcon: Icon(Icons.sports_tennis)),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final y = int.tryParse(v ?? '');
                  if (y == null || y < 1950 || y > DateTime.now().year) return 'Invalid year';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _dominantHand,
                decoration: const InputDecoration(labelText: 'Dominant Hand', border: OutlineInputBorder(), prefixIcon: Icon(Icons.back_hand)),
                items: ['Right', 'Left', 'Both'].map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (v) => setState(() => _dominantHand = v),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.read<AuthProvider>().signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
