import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

/// Field Mask Editor Screen
/// Allows drawing polygon points on a video frame or screenshot to define field boundaries
/// Supports saving masks per field to Supabase
class FieldMaskEditorScreen extends StatefulWidget {
  final String? fieldId;
  final String? fieldName;
  final String? cameraStreamUrl;
  final String? screenshotUrl; // NEW: Pre-loaded screenshot from Pi
  
  const FieldMaskEditorScreen({
    Key? key,
    this.fieldId,
    this.fieldName,
    this.cameraStreamUrl,
    this.screenshotUrl,
    this.cameraFieldId,  // Used to refresh live frame from the Pi camera
  }) : super(key: key);

  // The field_id in camera_status (same as fieldId, exposed for screenshot re-request)
  final String? cameraFieldId;

  @override
  State<FieldMaskEditorScreen> createState() => _FieldMaskEditorScreenState();
}

class _FieldMaskEditorScreenState extends State<FieldMaskEditorScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _urlController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _videoLoaded = false;
  bool _screenshotLoaded = false; // NEW: Screenshot image mode
  String? _screenshotUrl; // Current screenshot URL
  String? _errorMessage;
  bool _requestingLiveFrame = false; // Requesting fresh frame from camera
  
  // Drawing state
  List<Offset> _points = [];
  bool _showPreview = false;
  Size _videoSize = Size.zero;
  Size? _screenshotImageSize; // Actual pixel dimensions of screenshot (for correct tap 0-1)
  
  // Default field mask from chunk_processor.py (for reference)
  static const List<Offset> _defaultMask = [
    Offset(0.2756, 0.1777), Offset(0.3737, 0.0969), Offset(0.4884, 0.0653), Offset(0.5629, 0.0600),
    Offset(0.6920, 0.1212), Offset(0.7272, 0.1435), Offset(0.7990, 0.3257), Offset(0.8406, 0.4415),
    Offset(0.8785, 0.5593), Offset(0.9202, 0.6517), Offset(0.8502, 0.7684), Offset(0.7673, 0.8662),
    Offset(0.7197, 0.9278), Offset(0.6520, 0.9668), Offset(0.6225, 0.9901), Offset(0.3859, 0.9944),
    Offset(0.3260, 0.9709), Offset(0.2498, 0.8915), Offset(0.2130, 0.8411), Offset(0.1710, 0.8004),
    Offset(0.1366, 0.7317), Offset(0.1066, 0.6896), Offset(0.0943, 0.6766),
  ];
  bool _showDefaultMask = false;
  bool _hasExistingMask = false;
  
  @override
  void initState() {
    super.initState();
    
    // Pre-fill URL if camera stream URL is provided
    if (widget.cameraStreamUrl != null && widget.cameraStreamUrl!.isNotEmpty) {
      _urlController.text = widget.cameraStreamUrl!;
    }
    
    // If a screenshot URL is provided, load it directly
    if (widget.screenshotUrl != null && widget.screenshotUrl!.isNotEmpty) {
      _screenshotUrl = widget.screenshotUrl;
      _loadScreenshot();
    }
    
    // Load existing mask for this field
    if (widget.fieldId != null) {
      _loadExistingMask();
    }
  }
  
  @override
  void dispose() {
    _urlController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadExistingMask() async {
    if (widget.fieldId == null) return;
    
    try {
      final response = await _supabase
          .from('field_masks')
          .select('mask_points')
          .eq('field_id', widget.fieldId!)
          .maybeSingle();
      
      if (response != null && response['mask_points'] != null) {
        final maskData = response['mask_points'] as List<dynamic>;
        setState(() {
          _points = maskData.map((p) => Offset(
            (p['x'] as num).toDouble(),
            (p['y'] as num).toDouble(),
          )).toList();
          _hasExistingMask = true;
        });
        print('✅ Loaded existing mask with ${_points.length} points');
      }
    } catch (e) {
      print('Field mask load error: $e');
      // Table might not exist yet, that's OK
    }
  }
  
  /// Load a screenshot image (instead of video)
  Future<void> _loadScreenshot() async {
    if (_screenshotUrl == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Resolve image to get dimensions (for correct BoxFit.contain tap normalization)
      _screenshotImageSize = null;
      final imageProvider = NetworkImage(_screenshotUrl!);
      final stream = imageProvider.resolve(const ImageConfiguration());
      final completer = Completer<void>();
      stream.addListener(ImageStreamListener((ImageInfo info, bool sync) {
        if (completer.isCompleted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (mounted) setState(() => _screenshotImageSize = Size(w, h));
        completer.complete();
      }, onError: (dynamic e, StackTrace? st) {
        if (!completer.isCompleted) completer.complete();
      }));
      await completer.future;

      setState(() {
        _screenshotLoaded = true;
        _videoLoaded = false; // Not using video mode
        _isLoading = false;
        // Don't reset points if we have an existing mask
        if (!_hasExistingMask) {
          _points = [];
        }
      });

      print('✅ Screenshot loaded from: $_screenshotUrl${_screenshotImageSize != null ? " (${_screenshotImageSize!.width.toInt()}x${_screenshotImageSize!.height.toInt()})" : ""}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load screenshot: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a video URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _videoLoaded = false;
      _screenshotLoaded = false;
    });

    try {
      // Dispose old controller
      await _videoController?.dispose();
      
      // Create new controller
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      
      // Seek to first frame and pause
      await _videoController!.seekTo(Duration.zero);
      await _videoController!.pause();
      
      setState(() {
        _videoLoaded = true;
        _isLoading = false;
        _videoSize = _videoController!.value.size;
        // Don't reset points if we have an existing mask
        if (!_hasExistingMask) {
          _points = [];
        }
      });
      
      print('✅ Video loaded: ${_videoSize.width}x${_videoSize.height}');
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load video: $e';
        _isLoading = false;
      });
    }
  }

  void _addPoint(Offset normalizedPoint) {
    setState(() {
      _points.add(normalizedPoint);
    });
    print('✅ Point ${_points.length}: (${normalizedPoint.dx.toStringAsFixed(4)}, ${normalizedPoint.dy.toStringAsFixed(4)})');
  }

  void _removeLastPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
      print('❌ Removed last point');
    }
  }

  void _resetPoints() {
    setState(() {
      _points = [];
    });
    print('🔄 Reset all points');
  }

  void _copyToClipboard() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Need at least 3 points'), backgroundColor: Colors.orange),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('        FIELD_MASK_POINTS_NORMALIZED = np.array([');
    for (int i = 0; i < _points.length; i++) {
      final p = _points[i];
      final comma = i < _points.length - 1 ? ',' : '';
      buffer.writeln('            [${p.dx.toStringAsFixed(4)}, ${p.dy.toStringAsFixed(4)}]$comma');
    }
    buffer.writeln('        ], dtype=np.float32)');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Copied to clipboard! Paste into chunk_processor.py'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _loadDefaultMask() {
    setState(() {
      _points = List.from(_defaultMask);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Loaded default mask'), backgroundColor: Colors.blue),
    );
  }
  
  void _applyAndClose() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Need at least 3 points to define a mask'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Convert to the format expected by admin_ball_tracking_screen: List<List<double>>
    final result = _points.map((p) => [
      double.parse(p.dx.toStringAsFixed(4)),
      double.parse(p.dy.toStringAsFixed(4)),
    ]).toList();
    
    Navigator.pop(context, result);
  }

  Future<void> _saveFieldMask() async {
    if (widget.fieldId == null) return;
    
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Need at least 3 points to define a mask'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      // Convert points to JSON-serializable format
      final maskPoints = _points.map((p) => {
        'x': double.parse(p.dx.toStringAsFixed(4)),
        'y': double.parse(p.dy.toStringAsFixed(4)),
      }).toList();
      
      // Upsert (insert or update) the mask
      await _supabase.from('field_masks').upsert({
        'field_id': widget.fieldId!,
        'mask_points': maskPoints,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'field_id');
      
      setState(() {
        _isSaving = false;
        _hasExistingMask = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Field mask saved for ${widget.fieldName ?? 'field'}!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // We don't pop here anymore, let them click "Apply" to return
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save mask: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Request a fresh screenshot from the Pi camera by setting screenshot_requested=true,
  /// then poll camera_status until the Pi uploads a new image (up to 30s).
  Future<void> _refreshFromCamera() async {
    final fid = widget.cameraFieldId ?? widget.fieldId;
    if (fid == null) return;

    setState(() => _requestingLiveFrame = true);

    try {
      // Remember the current URL so we can detect when a new one arrives
      final existingUrl = _screenshotUrl;

      // Signal the Pi to take a screenshot
      await _supabase.from('camera_status').update({
        'screenshot_requested': true,
      }).eq('field_id', fid);

      // Poll up to 30 seconds (2s intervals)
      String? newUrl;
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        try {
          final res = await _supabase
              .from('camera_status')
              .select('screenshot_url, screenshot_requested')
              .eq('field_id', fid)
              .maybeSingle();
          if (res != null) {
            final url = res['screenshot_url'] as String?;
            final stillRequested = res['screenshot_requested'];
            if (url != null &&
                url.isNotEmpty &&
                (url != existingUrl || stillRequested == false)) {
              newUrl = url;
              break;
            }
          }
        } catch (e) {
          // Table might not have column yet — ignore
        }
      }

      if (!mounted) return;

      if (newUrl != null) {
        setState(() {
          _screenshotUrl = newUrl;
          _screenshotLoaded = false; // force reload
        });
        await _loadScreenshot();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Live frame refreshed!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏱ Camera did not respond in time. Is the Pi online?'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Refresh failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingLiveFrame = false);
    }
  }

  bool get _isEditorReady => _videoLoaded || _screenshotLoaded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.crop_free, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Field Mask Editor', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (widget.fieldName != null)
                    Text(widget.fieldName!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
        actions: [
          if (_isEditorReady) ...[
            IconButton(
              icon: Icon(_showDefaultMask ? Icons.visibility_off : Icons.visibility),
              tooltip: _showDefaultMask ? 'Hide default mask' : 'Show default mask',
              onPressed: () => setState(() => _showDefaultMask = !_showDefaultMask),
            ),
            IconButton(
              icon: Icon(_showPreview ? Icons.preview : Icons.preview_outlined),
              tooltip: _showPreview ? 'Hide preview' : 'Show preview',
              onPressed: () => setState(() => _showPreview = !_showPreview),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // URL Input Section (only show if no screenshot was provided)
          if (_screenshotUrl == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📹 Load Video Frame',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'Enter video URL (e.g., from raw recording or stream)',
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _loadVideo(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _loadVideo,
                        icon: _isLoading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download),
                        label: Text(_isLoading ? 'Loading...' : 'Load Frame'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BF63),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          
          // Screenshot banner (when using screenshot mode)
          if (_screenshotUrl != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live camera screenshot — draw the field boundaries',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Refresh live frame from camera button
                  if (_requestingLiveFrame)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 6),
                        Text('Requesting...', style: TextStyle(fontSize: 12)),
                      ],
                    )
                  else if (widget.cameraFieldId != null || widget.fieldId != null)
                    TextButton.icon(
                      onPressed: _refreshFromCamera,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh Frame', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    )
                  else if (_isLoading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          
          // Main Content
          Expanded(
            child: _isEditorReady 
              ? _buildEditor()
              : _buildInstructions(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crop_free, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Field Mask Editor',
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Define the playing field boundaries for accurate ball tracking.\n'
              'The ball tracker will only detect balls inside this polygon.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Existing mask indicator
            if (_hasExistingMask)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Existing mask loaded (${_points.length} points)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900]),
                    ),
                  ],
                ),
              ),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text('How to use:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStep('1', 'Paste a video URL from your raw recordings'),
                  _buildStep('2', 'Click "Load Frame" to see the first frame'),
                  _buildStep('3', 'Click around the field boundaries (clockwise)'),
                  _buildStep('4', 'Click "Save Field Mask" to save for this field'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.blue[700],
            child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: Colors.blue[900]))),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Row(
      children: [
        // Canvas (Left) - supports both video and screenshot
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.black,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_screenshotLoaded && _screenshotUrl != null) {
                    return _buildScreenshotCanvas(constraints);
                  } else if (_videoLoaded && _videoController != null) {
                    return _buildVideoCanvas(constraints);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
        
        // Controls Panel (Right)
        Container(
          width: 350,
          color: Colors.grey[100],
          child: Column(
            children: [
              // Stats
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📊 Stats', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (_videoLoaded) Text('Video: ${_videoSize.width.toInt()}x${_videoSize.height.toInt()}'),
                    if (_screenshotLoaded) Text('Source: Live camera screenshot'),
                    Text('Points: ${_points.length}'),
                    Text('Preview: ${_showPreview ? "ON" : "OFF"}'),
                    if (_showDefaultMask) Text('Default mask: VISIBLE', style: TextStyle(color: Colors.orange[700])),
                    if (_hasExistingMask) Text('Has saved mask: YES', style: TextStyle(color: Colors.green[700])),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('🎯 Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    
                    ElevatedButton.icon(
                      onPressed: _removeLastPoint,
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Undo Last Point'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton.icon(
                      onPressed: _resetPoints,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset All Points'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    OutlinedButton.icon(
                      onPressed: _loadDefaultMask,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Load Default Mask'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showPreview = !_showPreview),
                      icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility, size: 18),
                      label: Text(_showPreview ? 'Hide Preview' : 'Show Preview'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Points List
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('📍 Points (${_points.length})', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _points.length,
                          itemBuilder: (context, index) {
                            final p = _points[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFF00BF63),
                                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '(${p.dx.toStringAsFixed(4)}, ${p.dy.toStringAsFixed(4)})',
                                      style: GoogleFonts.robotoMono(fontSize: 12),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() => _points.removeAt(index));
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              
              // Save/Copy Buttons
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Save to database button (if field is selected)
                    // Primary Action: Apply and Use
                    ElevatedButton.icon(
                      onPressed: _points.length >= 3 ? _applyAndClose : null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Apply & Use Mask'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BF63),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Secondary Action: Save to DB (Optional)
                    if (widget.fieldId != null) ...[
                      OutlinedButton.icon(
                        onPressed: _points.length >= 3 && !_isSaving ? _saveFieldMask : null,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cloud_upload_outlined, size: 18),
                        label: Text(_isSaving ? 'Saving...' : 'Save to Field Database'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal[700],
                          side: BorderSide(color: Colors.teal[300]!),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Copy to clipboard (Helpful for manual pasting)
                    OutlinedButton.icon(
                      onPressed: _points.length >= 3 ? _copyToClipboard : null,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Coordinates'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        side: BorderSide(color: Colors.blue[200]!),
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Build canvas for screenshot image mode
  Widget _buildScreenshotCanvas(BoxConstraints constraints) {
    return Image.network(
      _screenshotUrl!,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          // Image loaded - wrap with gesture detector and overlay (pass image size for correct 0-1 taps)
          return LayoutBuilder(
            builder: (context, imageConstraints) {
              return _buildInteractiveCanvas(
                imageConstraints,
                // Since this is inside a Positioned matching the aspect ratio, 
                // use fill to ensure it covers the calculated area perfectly
                Image.network(_screenshotUrl!, fit: BoxFit.fill),
                imageSize: _screenshotImageSize,
              );
            },
          );
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text('Loading screenshot...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load screenshot', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => setState(() {}), // Trigger rebuild to retry
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Build interactive canvas for either video or screenshot
  Widget _buildInteractiveCanvas(BoxConstraints constraints, Widget backgroundWidget, {Size? imageSize}) {
    final containerW = constraints.maxWidth;
    final containerH = constraints.maxHeight;

    if (imageSize == null || imageSize.width == 0 || imageSize.height == 0) {
      return backgroundWidget;
    }

    final imageAspect = imageSize.width / imageSize.height;
    final containerAspect = containerW / containerH;
    
    double displayW;
    double displayH;
    double offsetX;
    double offsetY;

    if (containerAspect > imageAspect) {
      // Pillarbox (black bars on sides)
      displayH = containerH;
      displayW = containerH * imageAspect;
      offsetX = (containerW - displayW) / 2;
      offsetY = 0;
    } else {
      // Letterbox (black bars top/bottom)
      displayW = containerW;
      displayH = containerW / imageAspect;
      offsetX = 0;
      offsetY = (containerH - displayH) / 2;
    }

    final imageContentRect = Rect.fromLTWH(offsetX, offsetY, displayW, displayH);

    return GestureDetector(
      onTapDown: (details) {
        final localPos = details.localPosition;
        
        final xInImage = localPos.dx - imageContentRect.left;
        final yInImage = localPos.dy - imageContentRect.top;
        
        if (xInImage >= 0 && xInImage <= imageContentRect.width && 
            yInImage >= 0 && yInImage <= imageContentRect.height) {
          final normalizedX = (xInImage / imageContentRect.width).clamp(0.0, 1.0);
          final normalizedY = (yInImage / imageContentRect.height).clamp(0.0, 1.0);
          _addPoint(Offset(normalizedX, normalizedY));
        }
      },
      child: Stack(
        children: [
          // Background content centered exactly like the calculation above
          Positioned(
            left: imageContentRect.left,
            top: imageContentRect.top,
            width: imageContentRect.width,
            height: imageContentRect.height,
            child: backgroundWidget,
          ),
          // Drawing overlay over the WHOLE container so coordinates remain stable
          Positioned.fill(
            child: CustomPaint(
              painter: FieldMaskPainter(
                points: _points,
                showPreview: _showPreview,
                defaultMask: _showDefaultMask ? _defaultMask : null,
                imageContentRect: imageContentRect,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build canvas for video mode
  Widget _buildVideoCanvas(BoxConstraints constraints) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return _buildInteractiveCanvas(
      constraints,
      VideoPlayer(_videoController!),
      imageSize: _videoSize,
    );
  }
}

/// Custom painter for drawing the field mask
class FieldMaskPainter extends CustomPainter {
  final List<Offset> points;
  final bool showPreview;
  final List<Offset>? defaultMask;
  /// When set (screenshot with BoxFit.contain), points are in image 0-1; this rect is the image content area in widget coords.
  final Rect? imageContentRect;

  FieldMaskPainter({
    required this.points,
    required this.showPreview,
    this.defaultMask,
    this.imageContentRect,
  });

  Offset _toPixel(Offset p, Size size) {
    if (imageContentRect != null) {
      return Offset(
        imageContentRect!.left + p.dx * imageContentRect!.width,
        imageContentRect!.top + p.dy * imageContentRect!.height,
      );
    }
    return Offset(p.dx * size.width, p.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw default mask (orange, dashed)
    if (defaultMask != null && defaultMask!.isNotEmpty) {
      final defaultPaint = Paint()
        ..color = Colors.orange.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final defaultPath = Path();
      for (int i = 0; i < defaultMask!.length; i++) {
        final p = defaultMask![i];
        final pt = _toPixel(p, size);
        final x = pt.dx;
        final y = pt.dy;
        if (i == 0) {
          defaultPath.moveTo(x, y);
        } else {
          defaultPath.lineTo(x, y);
        }
      }
      defaultPath.close();
      canvas.drawPath(defaultPath, defaultPaint);
    }
    
    if (points.isEmpty) return;

    // Draw preview fill
    if (showPreview && points.length >= 3) {
      final fillPaint = Paint()
        ..color = Colors.green.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final path = Path();
      for (int i = 0; i < points.length; i++) {
        final pt = _toPixel(points[i], size);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, fillPaint);
    }

    // Draw lines
    if (points.length >= 2) {
      final linePaint = Paint()
        ..color = Colors.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      for (int i = 0; i < points.length - 1; i++) {
        final a = _toPixel(points[i], size);
        final b = _toPixel(points[i + 1], size);
        canvas.drawLine(a, b, linePaint);
      }
      if (points.length >= 3) {
        canvas.drawLine(_toPixel(points.last, size), _toPixel(points.first, size), linePaint);
      }
    }

    // Draw points
    for (int i = 0; i < points.length; i++) {
      final pt = _toPixel(points[i], size);
      final x = pt.dx;
      final y = pt.dy;
      
      // Outer circle (white border)
      canvas.drawCircle(
        Offset(x, y),
        10,
        Paint()..color = Colors.white,
      );
      
      // Inner circle (green)
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()..color = const Color(0xFF00BF63),
      );
      
      // Number
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant FieldMaskPainter oldDelegate) {
    return oldDelegate.points != points ||
           oldDelegate.showPreview != showPreview ||
           oldDelegate.defaultMask != defaultMask ||
           oldDelegate.imageContentRect != imageContentRect;
  }
}
