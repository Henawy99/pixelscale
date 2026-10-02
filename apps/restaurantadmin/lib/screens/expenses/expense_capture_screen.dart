import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:restaurantadmin/services/expense_service.dart';

/// Where the first page comes from when the screen opens.
enum CaptureSource { camera, photos, files }

/// Photograph, pick from Photos or upload every page of ONE invoice, then let Gemini read it.
/// Pops with the new expense id when the invoice was read.
class ExpenseCaptureScreen extends StatefulWidget {
  final ExpenseService? service;

  /// Opened straight away (phones); null shows the page picker first.
  final CaptureSource? start;
  const ExpenseCaptureScreen({super.key, this.service, this.start});

  @override
  State<ExpenseCaptureScreen> createState() => _ExpenseCaptureScreenState();
}

class _Page {
  final Uint8List bytes;
  final String extension;
  final String name;
  _Page(this.bytes, this.extension, this.name);
  bool get isPdf => extension == 'pdf';
}

enum _Phase { picking, uploading, reading }

class _ExpenseCaptureScreenState extends State<ExpenseCaptureScreen> {
  static const int _maxBytes = 18 * 1024 * 1024; // Gemini accepts ~20 MB per request

  late final ExpenseService _service = widget.service ?? ExpenseService();
  final ImagePicker _picker = ImagePicker();
  final List<_Page> _pages = [];
  _Phase _phase = _Phase.picking;
  String? _error;
  List<String>? _uploadedPaths;
  String? _failedExpenseId;
  int _hintIndex = 0;
  Timer? _hintTimer;

  static const _hints = [
    'Finding the supplier…',
    'Reading every line…',
    'Working out pack sizes…',
    'Matching your materials…',
  ];

  bool get _isPhone =>
      !kIsWeb &&
      (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    // Open the source chosen on the Expenses screen; nothing picked means the user changed their mind.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final start = widget.start;
      if (start == null) return;
      await switch (start) {
        CaptureSource.camera => _takePhoto(),
        CaptureSource.photos => _pickPhotos(),
        CaptureSource.files => _pickFiles(),
      };
      if (mounted && _pages.isEmpty) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  int get _totalBytes => _pages.fold(0, (s, p) => s + p.bytes.length);

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 82);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      _addPage(bytes, _ext(photo.name, fallback: 'jpg'), photo.name);
    } catch (e) {
      _showError('Could not open the camera: $e');
    }
  }

  /// One or more pages from the phone's photo library.
  Future<void> _pickPhotos() async {
    try {
      final photos = await _picker.pickMultiImage(maxWidth: 2400, imageQuality: 82);
      for (final photo in photos) {
        _addPage(await photo.readAsBytes(), _ext(photo.name, fallback: 'jpg'), photo.name);
      }
    } catch (e) {
      _showError('Could not open your photos: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
        withData: true,
      );
      if (result == null) return;
      for (final f in result.files) {
        if (f.bytes == null) continue;
        _addPage(f.bytes!, _ext(f.name, fallback: f.extension ?? 'jpg'), f.name);
      }
    } catch (e) {
      _showError('Could not open the files: $e');
    }
  }

  void _addPage(Uint8List bytes, String ext, String name) {
    setState(() {
      _pages.add(_Page(bytes, ext == 'jpeg' ? 'jpg' : ext, name));
      _error = null;
      _uploadedPaths = null; // pages changed: upload again
      _failedExpenseId = null;
    });
  }

  static String _ext(String name, {required String fallback}) {
    final dot = name.lastIndexOf('.');
    return (dot >= 0 ? name.substring(dot + 1) : fallback).toLowerCase();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _read() async {
    if (_pages.isEmpty) return;
    if (_totalBytes > _maxBytes) {
      setState(() => _error = 'These files are too large together (max 18 MB). Upload one invoice at a time.');
      return;
    }
    setState(() {
      _error = null;
      _phase = _uploadedPaths == null ? _Phase.uploading : _Phase.reading;
    });
    try {
      _uploadedPaths ??= await _service.uploadPages([for (final p in _pages) (bytes: p.bytes, extension: p.extension)]);
      if (!mounted) return;
      setState(() => _phase = _Phase.reading);
      _hintTimer?.cancel();
      _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
      });
      final id = _failedExpenseId != null
          ? await _service.reanalyze(_failedExpenseId!)
          : await _service.analyze(_uploadedPaths!);
      if (mounted) Navigator.of(context).pop(id);
    } on ExpenseException catch (e) {
      _failedExpenseId = e.expenseId ?? _failedExpenseId;
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      _hintTimer?.cancel();
      if (mounted && _error != null) setState(() => _phase = _Phase.picking);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase != _Phase.picking;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
          ),
          title: const Text('Scan invoice'),
        ),
        body: busy ? _buildProgress() : _buildPicker(),
        bottomNavigationBar: busy ? null : _buildBottomBar(),
      ),
    );
  }

  Widget _buildProgress() {
    final uploading = _phase == _Phase.uploading;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 5)),
            const SizedBox(height: 28),
            Text(
              uploading
                  ? 'Uploading ${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}…'
                  : 'Reading the invoice',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                uploading ? 'One moment' : _hints[_hintIndex],
                key: ValueKey(uploading ? -1 : _hintIndex),
                style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B))),
                ),
              ],
            ),
          ),
        Text(
          _pages.isEmpty ? 'Add the invoice' : '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'One invoice at a time. If it has several pages, add every page: the total is usually on the last one.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 170).floor().clamp(2, 6);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
              children: [
                for (var i = 0; i < _pages.length; i++) _pageTile(i),
                _addTile(
                  icon: Icons.photo_camera_rounded,
                  label: _pages.isEmpty ? 'Take photo' : 'Add page',
                  onTap: _takePhoto,
                  primary: true,
                ),
                if (_isPhone)
                  _addTile(icon: Icons.photo_library_rounded, label: 'From Photos', onTap: _pickPhotos),
                _addTile(
                  icon: Icons.upload_file_rounded,
                  label: kIsWeb ? 'Upload photos or PDF' : 'PDF / Files',
                  onTap: _pickFiles,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _pageTile(int index) {
    final page = _pages[index];
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.white,
              child: page.isPdf
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, size: 44, color: Color(0xFFDC2626)),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            page.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  : Image.memory(
                      page.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined, size: 40)),
                    ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Page ${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: IconButton.filledTonal(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() {
              _pages.removeAt(index);
              _uploadedPaths = null;
              _failedExpenseId = null;
            }),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }

  Widget _addTile({required IconData icon, required String label, required VoidCallback onTap, bool primary = false}) {
    final color = primary ? const Color(0xFF4F46E5) : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary ? const Color(0xFFC7D2FE) : const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _pages.isEmpty ? null : _read,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _pages.isEmpty
                      ? 'Add a page first'
                      : (_error != null
                            ? 'Try again'
                            : 'Read invoice (${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'})'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
