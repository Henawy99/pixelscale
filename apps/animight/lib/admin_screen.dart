import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animight/supabase_service.dart';
import 'dart:ui';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _remoteWallpapers = [];
  int _todayVisitors = 0;
  bool _loadingWallpapers = true;
  bool _loadingVisitors = true;
  bool _uploading = false;

  final _nameController = TextEditingController();
  final _btNameController = TextEditingController();
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadWallpapers(), _loadVisitors()]);
  }

  Future<void> _loadWallpapers() async {
    setState(() => _loadingWallpapers = true);
    final walls = await fetchRemoteWallpapers();
    if (mounted) setState(() { _remoteWallpapers = walls; _loadingWallpapers = false; });
  }

  Future<void> _loadVisitors() async {
    setState(() => _loadingVisitors = true);
    final count = await getTodayVisitorCount();
    if (mounted) setState(() { _todayVisitors = count; _loadingVisitors = false; });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _uploadWallpaper() async {
    final name = _nameController.text.trim();
    final btName = _btNameController.text.trim();

    if (name.isEmpty) {
      _snack('Please enter a wallpaper name.');
      return;
    }
    if (_pickedImage == null) {
      _snack('Please pick an image first.');
      return;
    }

    setState(() => _uploading = true);

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(' ', '_')}.jpg';
    final result = await uploadWallpaperImage(_pickedImage!, fileName);

    if (result.url == null) {
      if (mounted) {
        setState(() => _uploading = false);
        _snack('Upload failed: ${result.error ?? 'unknown error'}');
      }
      return;
    }
    final imageUrl = result.url!;

    final success = await addWallpaper(
      name: name,
      bluetoothName: btName.isEmpty ? name : btName,
      imageUrl: imageUrl,
    );

    if (mounted) {
      setState(() { _uploading = false; _pickedImage = null; });
      _nameController.clear();
      _btNameController.clear();
      if (success) {
        _snack('Wallpaper added!');
        _loadWallpapers();
      } else {
        _snack('Failed to save wallpaper metadata.');
      }
    }
  }

  Future<void> _deleteWallpaper(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Delete Wallpaper', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$name"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await deleteWallpaper(id);
      _loadWallpapers();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _btNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.cyanAccent, Colors.pinkAccent],
          ).createShader(bounds),
          child: const Text(
            'ADMIN PANEL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.pinkAccent),
            tooltip: 'Sign out',
            onPressed: () async {
              await signOut();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVisitorCard(),
            const SizedBox(height: 24),
            _buildAddWallpaperCard(),
            const SizedBox(height: 24),
            _buildWallpaperList(),
          ],
        ),
      ),
    );
  }

  // ── Visitor Counter ────────────────────────────────────────────────────
  Widget _buildVisitorCard() {
    return _GlassCard(
      glowColor: Colors.cyanAccent,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.cyanAccent.withOpacity(0.15),
              boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 16)],
            ),
            child: const Icon(Icons.people_alt_outlined, color: Colors.cyanAccent, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('App Visitors Today', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              _loadingVisitors
                  ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                  : Text(
                      '$_todayVisitors',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 12)],
                      ),
                    ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadVisitors,
          ),
        ],
      ),
    );
  }

  // ── Add Wallpaper Form ────────────────────────────────────────────────
  Widget _buildAddWallpaperCard() {
    return _GlassCard(
      glowColor: Colors.pinkAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADD WALLPAPER',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),

          // Image picker
          GestureDetector(
            onTap: _uploading ? null : _pickImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.pinkAccent.withOpacity(0.5), width: 1.5),
                color: Colors.white.withOpacity(0.04),
              ),
              child: _pickedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(_pickedImage!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.pinkAccent.withOpacity(0.7), size: 40),
                        const SizedBox(height: 8),
                        Text('Tap to pick image', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          _buildTextField(_nameController, 'Wallpaper Name', Icons.title),
          const SizedBox(height: 12),
          _buildTextField(_btNameController, 'Bluetooth Name (optional)', Icons.bluetooth),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: _uploading
                ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                : ElevatedButton.icon(
                    onPressed: _uploadWallpaper,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Upload & Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                      foregroundColor: Colors.pinkAccent,
                      side: const BorderSide(color: Colors.pinkAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.pinkAccent),
        ),
      ),
    );
  }

  // ── Remote Wallpapers List ───────────────────────────────────────────
  Widget _buildWallpaperList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'UPLOADED WALLPAPERS',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white54, size: 20), onPressed: _loadWallpapers),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingWallpapers)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          ))
        else if (_remoteWallpapers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No uploaded wallpapers yet.', style: TextStyle(color: Colors.white.withOpacity(0.4))),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _remoteWallpapers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final w = _remoteWallpapers[index];
              return _WallpaperListTile(
                wallpaper: w,
                onDelete: () => _deleteWallpaper(w['id'], w['name']),
              );
            },
          ),
      ],
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;

  const _GlassCard({required this.child, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: glowColor.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: glowColor.withOpacity(0.12), blurRadius: 20)],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _WallpaperListTile extends StatelessWidget {
  final Map<String, dynamic> wallpaper;
  final VoidCallback onDelete;

  const _WallpaperListTile({required this.wallpaper, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: Image.network(
              wallpaper['image_url'] ?? '',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64, height: 64,
                color: Colors.white10,
                child: const Icon(Icons.broken_image, color: Colors.white30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wallpaper['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if ((wallpaper['bluetooth_name'] ?? '').isNotEmpty)
                  Text(wallpaper['bluetooth_name'], style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
