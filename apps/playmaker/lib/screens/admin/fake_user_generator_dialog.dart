import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playmakerappstart/config/supabase_config.dart';
import 'package:uuid/uuid.dart';

import 'dart:math';

class FakeUserGeneratorDialog extends StatefulWidget {
  const FakeUserGeneratorDialog({super.key});

  @override
  State<FakeUserGeneratorDialog> createState() => _FakeUserGeneratorDialogState();
}

class _FakeUserGeneratorDialogState extends State<FakeUserGeneratorDialog> {
  List<PlatformFile> _pickedFiles = [];
  final TextEditingController _countController = TextEditingController(text: '1');
  bool _isLoading = false;
  String _statusMessage = 'Ready';

  final List<String> _egyptianNames = [
    'Mohamed Khaled', 'Khaled Youssef', 'Omar Tarek', 'Mostafa Ahmed', 
    'Mahmoud Ali', 'Ahmed Hassan', 'Ali Yasser', 'Youssef Hisham', 
    'Hassan Ibrahim', 'Hussein Said', 'Kareem Ashraf', 'Mazen Waleed', 'Seif Amr'
  ];
  final List<String> _positions = ['Goalkeeper (GK)', 'Last Man Defender', 'Winger', 'Striker', 'All Rounder'];
  final List<String> _levels = ['Beginner', 'Amateur', 'Semi-Pro', 'Pro'];

  late SupabaseClient _adminClient;

  @override
  void initState() {
    super.initState();
    // Initialize admin client to bypass RLS and create Auth users
    _adminClient = SupabaseClient(
      SupabaseConfig.supabaseUrl,
      SupabaseConfig.supabaseServiceRoleKey,
    );
  }

  @override
  void dispose() {
    _countController.dispose();
    _adminClient.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _pickedFiles = result.files);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _generateFakeUsers() async {
    final int totalCount;
    if (_pickedFiles.isNotEmpty) {
      totalCount = _pickedFiles.length;
    } else {
      totalCount = int.tryParse(_countController.text.trim()) ?? 0;
      if (totalCount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid number or select pictures')));
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting generation of $totalCount fake users...';
    });

    try {
      final random = Random();

      setState(() => _statusMessage = 'Checking booking_images bucket...');
      try {
        final buckets = await _adminClient.storage.listBuckets();
        if (!buckets.any((b) => b.id == 'booking_images')) {
          await _adminClient.storage.createBucket('booking_images', const BucketOptions(public: true));
        }
      } catch (e) {
        print('Error ensuring bucket exists: $e');
      }

      for (int i = 0; i < totalCount; i++) {
        final file = i < _pickedFiles.length ? _pickedFiles[i] : null;
        final name = _egyptianNames[random.nextInt(_egyptianNames.length)];
        final age = (18 + random.nextInt(21)).toString(); // 18 to 38
        final position = _positions[random.nextInt(_positions.length)];
        final level = _levels[random.nextInt(_levels.length)];
        
        final uuid = const Uuid().v4();
        final sanitizedName = name.replaceAll(' ', '').toLowerCase();
        final email = 'fake_${sanitizedName}_${uuid.substring(0, 5)}@playmaker.com';

        setState(() => _statusMessage = 'Creating user ${i+1}/$totalCount: $name...');

        // 1. Create Fake Auth User
        final fakeUserRes = await _adminClient.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: 'password123',
            emailConfirm: true,
          ),
        );
        final fakeUserId = fakeUserRes.user!.id;

        // 2. Upload Profile Picture (optional)
        String profilePicUrl = '';
        if (file != null) {
          setState(() => _statusMessage = 'Uploading picture for $name...');
          final fileExt = file.extension ?? 'jpg';
          final fileName = 'fake_profiles/${fakeUserId}_$uuid.$fileExt';
          
          if (kIsWeb && file.bytes != null) {
            await _adminClient.storage.from('booking_images').uploadBinary(
                  fileName,
                  file.bytes!,
                );
          } else if (!kIsWeb && file.path != null) {
            await _adminClient.storage.from('booking_images').upload(
                  fileName,
                  File(file.path!),
                );
          }
          profilePicUrl = _adminClient.storage.from('booking_images').getPublicUrl(fileName);
        }

        // 3. Create Fake Player Profile
        setState(() => _statusMessage = 'Saving profile for $name...');
        final playerId = (10000 + random.nextInt(90000)).toString(); // 5-digit ID
        await _adminClient.from('player_profiles').insert({
          'id': fakeUserId,
          'email': email,
          'name': name,
          'age': age,
          'nationality': 'Egypt',
          'player_id': playerId,
          'preferred_position': position,
          'personal_level': level,
          'profile_picture': profilePicUrl,
          'joined': DateTime.now().subtract(Duration(days: random.nextInt(30))).toIso8601String(),
          'verified': 'true',
          'is_guest': false,
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Success! $totalCount fake users created.';
          _pickedFiles.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully generated $totalCount fake users!'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      print('❌ Fake User Gen Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Fake User & Matches'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload profile pictures OR set a count to generate fake Egyptian users.\n'
              'Names, ages, positions, and levels are auto-generated.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of users (without pictures)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.people),
                helperText: _pickedFiles.isNotEmpty ? 'Ignored — using ${_pickedFiles.length} pictures instead' : null,
                helperStyle: const TextStyle(color: Colors.orange),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: _pickedFiles.isEmpty
                        ? const Icon(Icons.group_add, size: 40, color: Colors.grey)
                        : Center(
                            child: Text(
                              '+${_pickedFiles.length}',
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Select Profile Pictures (optional)'),
                  ),
                  if (_pickedFiles.isNotEmpty)
                    TextButton(
                      onPressed: _isLoading ? null : () => setState(() => _pickedFiles.clear()),
                      child: const Text('Clear pictures', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusMessage.startsWith('Error') ? Colors.red : Colors.green[800],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _generateFakeUsers,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BF63), foregroundColor: Colors.white),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Generate Fake Users'),
        ),
      ],
    );
  }
}
