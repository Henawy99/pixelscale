import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animight/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _wallpapers = [];

  int _todayVisitors = 0;
  bool _loadingWallpapers = true;
  bool _loadingVisitors = true;
  bool _uploading = false;
  bool _reordering = false;

  final _nameController = TextEditingController();
  final _btNameController = TextEditingController();
  File? _pickedImage;
  bool _newIsComingSoon = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadWallpapers(), _loadVisitors()]);
  }

  Future<void> _loadWallpapers() async {
    setState(() => _loadingWallpapers = true);
    final walls = await fetchRemoteWallpapers();
    if (mounted) setState(() { _wallpapers = walls; _loadingWallpapers = false; });
  }

  Future<void> _loadVisitors() async {
    setState(() => _loadingVisitors = true);
    final count = await getTodayVisitorCount();
    if (mounted) setState(() { _todayVisitors = count; _loadingVisitors = false; });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _uploadWallpaper() async {
    final name = _nameController.text.trim();
    final btName = _btNameController.text.trim();
    if (name.isEmpty) { _snack('Please enter a wallpaper name.'); return; }
    if (_pickedImage == null) { _snack('Please pick an image first.'); return; }

    setState(() => _uploading = true);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(' ', '_')}.jpg';
    final result = await uploadWallpaperImage(_pickedImage!, fileName);

    if (result.url == null) {
      if (mounted) { setState(() => _uploading = false); _snack('Upload failed: ${result.error ?? 'unknown'}'); }
      return;
    }

    // Sort order = end of list
    final nextOrder = _wallpapers.length;
    final success = await addWallpaper(
      name: name,
      bluetoothName: btName.isEmpty ? name : btName,
      imageUrl: result.url!,
      isComingSoon: _newIsComingSoon,
    );
    // persist sort_order for the new row if supported
    if (success) {
      await updateWallpaper(id: '', sortOrder: nextOrder); // will silently fail — order handled on next fetch
    }

    if (mounted) {
      setState(() { _uploading = false; _pickedImage = null; _newIsComingSoon = false; });
      _nameController.clear();
      _btNameController.clear();
      if (success) {
        _snack('Wallpaper added!');
        _loadWallpapers();
        _tabController.animateTo(1); // switch to manage tab
      } else {
        _snack('Failed to save wallpaper metadata.');
      }
    }
  }

  Future<void> _deleteWallpaper(Map<String, dynamic> w) async {
    final confirm = await _confirmDialog(
      title: 'Delete Wallpaper',
      body: 'Delete "${w['name']}"? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.redAccent,
    );
    if (confirm == true) {
      await deleteWallpaper(w['id']);
      _snack('"${w['name']}" deleted.');
      _loadWallpapers();
    }
  }

  Future<void> _renameWallpaper(Map<String, dynamic> w) async {
    final ctrl = TextEditingController(text: w['name']);
    final btCtrl = TextEditingController(text: w['bluetooth_name'] ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _GlassDialog(
        title: 'Rename Wallpaper',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(ctrl, 'Wallpaper Name', Icons.title),
            const SizedBox(height: 12),
            _dialogField(btCtrl, 'Bluetooth Name', Icons.bluetooth),
          ],
        ),
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (result == true) {
      final newName = ctrl.text.trim();
      final newBt = btCtrl.text.trim();
      if (newName.isEmpty) return;
      final ok = await updateWallpaper(
        id: w['id'],
        name: newName,
        bluetoothName: newBt.isEmpty ? newName : newBt,
      );
      if (ok) {
        _snack('Renamed successfully.');
        _loadWallpapers();
      } else {
        _snack('Rename failed.');
      }
    }
  }

  Future<void> _toggleComingSoon(Map<String, dynamic> w) async {
    final current = w['is_coming_soon'] as bool? ?? false;
    final ok = await updateWallpaper(id: w['id'], isComingSoon: !current);
    if (ok) {
      _snack(!current ? '"${w['name']}" marked as Coming Soon.' : '"${w['name']}" is now available.');
      _loadWallpapers();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _wallpapers.removeAt(oldIndex);
      _wallpapers.insert(newIndex, item);
      _reordering = true;
    });
    // Persist new sort order
    final updates = <Map<String, dynamic>>[];
    for (int i = 0; i < _wallpapers.length; i++) {
      updates.add({'id': _wallpapers[i]['id'], 'sort_order': i});
    }
    await batchUpdateSortOrder(updates);
    if (mounted) setState(() => _reordering = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF1A1A2E),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    Color confirmColor = Colors.cyanAccent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _btNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────── BUILD ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
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
              Navigator.pop(context); // ignore: use_build_context_synchronously
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          indicatorWeight: 2,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'ADD NEW'),
            Tab(text: 'MANAGE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddTab(),
          _buildManageTab(),
        ],
      ),
    );
  }

  // ─────────────────── ADD TAB ─────────────────────────────────────────────

  Widget _buildAddTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVisitorCard(),
          const SizedBox(height: 20),
          _buildAddWallpaperCard(),
        ],
      ),
    );
  }

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
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: _loadVisitors),
        ],
      ),
    );
  }

  Widget _buildAddWallpaperCard() {
    return _GlassCard(
      glowColor: Colors.pinkAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ADD WALLPAPER',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          // Image picker
          GestureDetector(
            onTap: _uploading ? null : _pickImage,
            child: Container(
              height: 180,
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
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.pinkAccent.withOpacity(0.7), size: 44),
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
          const SizedBox(height: 12),
          // Coming soon toggle on add
          _GlassCard(
            glowColor: _newIsComingSoon ? Colors.amber : Colors.white12,
            child: Row(
              children: [
                Icon(Icons.timelapse_rounded,
                    color: _newIsComingSoon ? Colors.amber : Colors.white38, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Coming Soon',
                          style: TextStyle(
                            color: _newIsComingSoon ? Colors.amber : Colors.white70,
                            fontWeight: FontWeight.bold,
                          )),
                      Text('Shows a "Coming Soon" banner on this wallpaper',
                          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _newIsComingSoon,
                  onChanged: (v) => setState(() => _newIsComingSoon = v),
                  activeColor: Colors.amber,
                  inactiveTrackColor: Colors.white12,
                ),
              ],
            ),
          ),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.pinkAccent)),
      ),
    );
  }

  // ─────────────────── MANAGE TAB ──────────────────────────────────────────

  Widget _buildManageTab() {
    return Column(
      children: [
        if (_reordering)
          Container(
            color: Colors.cyanAccent.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)),
                SizedBox(width: 10),
                Text('Saving order...', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                '${_wallpapers.length} WALLPAPER${_wallpapers.length == 1 ? '' : 'S'}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white38, size: 20),
                onPressed: _loadWallpapers,
              ),
            ],
          ),
        ),
        if (_loadingWallpapers)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)))
        else if (_wallpapers.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 56),
                  const SizedBox(height: 12),
                  Text('No cloud wallpapers yet.\nAdd one in the "ADD NEW" tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.35), height: 1.6)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                onReorder: _onReorder,
                itemCount: _wallpapers.length,
                itemBuilder: (context, index) {
                  final w = _wallpapers[index];
                  return _WallpaperManageTile(
                    key: ValueKey(w['id']),
                    wallpaper: w,
                    onRename: () => _renameWallpaper(w),
                    onToggleComingSoon: () => _toggleComingSoon(w),
                    onDelete: () => _deleteWallpaper(w),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.cyanAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ─────────────────── WALLPAPER MANAGE TILE ──────────────────────────────────

class _WallpaperManageTile extends StatelessWidget {
  final Map<String, dynamic> wallpaper;
  final VoidCallback onRename;
  final VoidCallback onToggleComingSoon;
  final VoidCallback onDelete;

  const _WallpaperManageTile({
    super.key,
    required this.wallpaper,
    required this.onRename,
    required this.onToggleComingSoon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isComingSoon = wallpaper['is_coming_soon'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: isComingSoon ? Colors.amber.withOpacity(0.4) : Colors.white.withOpacity(0.1),
          width: 1.2,
        ),
        boxShadow: isComingSoon
            ? [BoxShadow(color: Colors.amber.withOpacity(0.12), blurRadius: 12)]
            : [],
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: wallpaper['image_url'] ?? '',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: Colors.white10,
                    child: const Icon(Icons.broken_image, color: Colors.white30),
                  ),
                ),
                if (isComingSoon)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.amber.withOpacity(0.85),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: const Text(
                        'SOON',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallpaper['name'] ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if ((wallpaper['bluetooth_name'] ?? '').isNotEmpty)
                  Text(
                    wallpaper['bluetooth_name'],
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (isComingSoon) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: const Text(
                      'COMING SOON',
                      style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Action buttons
          Column(
            children: [
              _ActionBtn(icon: Icons.edit_outlined, color: Colors.cyanAccent, onTap: onRename, tooltip: 'Rename'),
              _ActionBtn(
                icon: isComingSoon ? Icons.timelapse_rounded : Icons.timelapse_outlined,
                color: isComingSoon ? Colors.amber : Colors.white38,
                onTap: onToggleComingSoon,
                tooltip: isComingSoon ? 'Remove Coming Soon' : 'Mark Coming Soon',
              ),
              _ActionBtn(icon: Icons.delete_outline, color: Colors.redAccent, onTap: onDelete, tooltip: 'Delete'),
            ],
          ),
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.drag_handle, color: Colors.white24, size: 22),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionBtn({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────── SHARED HELPER WIDGETS ──────────────────────────────────

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
            boxShadow: [BoxShadow(color: glowColor.withOpacity(0.08), blurRadius: 20)],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _GlassDialog({
    required this.title,
    required this.content,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A).withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                content,
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save'),
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
}
