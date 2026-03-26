import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playmakerappstart/services/ball_tracking_service.dart';
import 'package:playmakerappstart/screens/admin/field_mask_editor_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:playmakerappstart/screens/admin/admin_side_by_side_screen.dart';
import 'package:playmakerappstart/screens/admin/ball_tracking_url_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminBallTrackingScreen extends StatefulWidget {
  const AdminBallTrackingScreen({Key? key}) : super(key: key);

  @override
  State<AdminBallTrackingScreen> createState() => _AdminBallTrackingScreenState();
}

class _AdminBallTrackingScreenState extends State<AdminBallTrackingScreen> {
  final BallTrackingService _service = BallTrackingService();
  List<BallTrackingJob> _jobs = [];
  bool _isLoading = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  double _uploadFileSizeMb = 0.0; // Track file size for MB display
  String? _errorMessage;
  ScriptConfig _selectedConfig = ScriptConfig.balanced;
  String _selectedPreset = 'Custom'; // Always Custom now
  
  // Script history
  List<Map<String, String>> _scriptHistory = []; // Stores {name, script, timestamp}
  String? _selectedHistoryScript;
  
  // Custom configuration controllers - OPTIMIZED for ACCURACY + SPEED
  final TextEditingController _yoloModelController = TextEditingController(text: 'yolov8l');  // ACCURACY!
  final TextEditingController _yoloConfController = TextEditingController(text: '0.12');
  final TextEditingController _detectEveryFramesController = TextEditingController(text: '3');  // Balance
  final TextEditingController _yoloImgSizeController = TextEditingController(text: '960');
  final TextEditingController _roiSizeController = TextEditingController(text: '1200');
  final TextEditingController _zoomBaseController = TextEditingController(text: '1.8');
  final TextEditingController _smoothingController = TextEditingController(text: '0.08');
  final TextEditingController _customScriptController = TextEditingController();
  final TextEditingController _roboflowApiKeyController = TextEditingController(text: 'TsZ58QXSmc6pkBSsklrJ');
  String _customModelId = 'soccer-ball-tracker-sgt32/4';
  
  // No longer using compare mode

  List<List<double>>? _selectedFieldMask;
  
  // Pipeline job state
  bool _isPipelineRunning = false;

  // AI Extension state - simplified
  String? currentVideoUrl;
  
  // ── Pipeline webhook (production chunk processor) ──
  static const String _pipelineWebhookUrl =
      'https://youssefelhenawy0--playmakerstart-process-chunk-webhook.modal.run';
  // Raw URL of the current pipeline script (for viewing in the dialog)
  static const String _pipelineScriptRawUrl =
      'https://raw.githubusercontent.com/youssefelhenawy/pixelscale/main/apps/playmakerstart/modal_gpu_function/BROADCAST_BALL_TRACKING_V4_SCRIPT.py';
  
  @override
  void dispose() {
    _yoloModelController.dispose();
    _yoloConfController.dispose();
    _detectEveryFramesController.dispose();
    _yoloImgSizeController.dispose();
    _roiSizeController.dispose();
    _zoomBaseController.dispose();
    _smoothingController.dispose();
    _customScriptController.dispose();
    _roboflowApiKeyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    _service.subscribeToAllJobs().listen((jobs) {
      if (mounted) {
        setState(() {
          _jobs = jobs;
        });
      }
    });
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jobs = await _service.getAllJobs();
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }




  
  void _showScriptViewer(String script, String videoName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.code, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Script: $videoName',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 500,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      script,
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        color: Colors.green[300],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select the text above and copy it with Ctrl+C (Cmd+C on Mac)',
                        style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  ScriptConfig _buildScriptConfig() {
    return ScriptConfig(
      yoloModel: _yoloModelController.text,
      yoloConf: double.tryParse(_yoloConfController.text) ?? 0.12,
      detectEveryFrames: int.tryParse(_detectEveryFramesController.text) ?? 3,
      yoloImgSize: int.tryParse(_yoloImgSizeController.text) ?? 960,
      roiSize: int.tryParse(_roiSizeController.text) ?? 1200,
      zoomBase: double.tryParse(_zoomBaseController.text) ?? 1.8,
      smoothing: double.tryParse(_smoothingController.text) ?? 0.08,
      fieldMaskPoints: _selectedFieldMask,
    );
  }

  String _buildScriptWithMask(String script) {
    String header = '';
    
    // 1. Inject Field Mask
    if (_selectedFieldMask != null && _selectedFieldMask!.isNotEmpty) {
      final pts = _selectedFieldMask!.map((p) => '[${p[0].toStringAsFixed(4)}, ${p[1].toStringAsFixed(4)}]').join(', ');
      header += '# ── FIELD MASK (auto-injected by Ball Tracking Lab) ────────────────────────\n'
          '_injected_field_mask = [$pts]\n'
          '# ─────────────────────────────────────────────────────────────────────────────\n\n';
    }
    
    // 2. Inject AI Frame Extension Settings
    header += '# ── AI FRAME EXTENSION (auto-injected) ──────────────────────────────────\n'
        'EXTEND_FRAME = False\n'
        'EXTENDED_BACKGROUND_PATH = None\n'
        '# ─────────────────────────────────────────────────────────────────────────────\n\n';
        
    return '$header$script';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PIPELINE JOB — triggers the real production chunk_processor.py pipeline
  // ══════════════════════════════════════════════════════════════════════════

  void _showPipelineJobDialog() {
    final urlController = TextEditingController();
    bool showFieldMask = false;
    bool showRedBall = false;
    bool isRunning = false;
    String? statusMsg;
    String? errorMsg;
    String? outputUrl;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple, width: 1.5),
                ),
                child: const Icon(Icons.rocket_launch, color: Colors.deepPurple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Pipeline Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Text('Production Pipeline', style: TextStyle(color: Colors.green[300], fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Runs the video through the exact same pipeline as production recordings — chunk_processor.py with the current BROADCAST_BALL_TRACKING_V4_SCRIPT.',
                            style: TextStyle(color: Colors.blue[200], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Video URL
                  Text('Video URL', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://playmaker-raw.b-cdn.net/recordings/...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0D0D1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.deepPurple),
                      ),
                      prefixIcon: const Icon(Icons.link, color: Colors.deepPurple, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste, color: Colors.grey, size: 16),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) urlController.text = data!.text!;
                        },
                        tooltip: 'Paste from clipboard',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggles
                  Text('Overlays', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Field Mask
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setS(() => showFieldMask = !showFieldMask),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: showFieldMask ? Colors.green.withOpacity(0.15) : const Color(0xFF0D0D1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: showFieldMask ? Colors.green : Colors.grey[700]!,
                                width: showFieldMask ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.grid_on, color: showFieldMask ? Colors.green : Colors.grey[600], size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Field Mask', style: TextStyle(color: showFieldMask ? Colors.green[300] : Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600)),
                                      Text('Show field boundary overlay', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: showFieldMask,
                                  onChanged: (v) => setS(() => showFieldMask = v),
                                  activeColor: Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Red Ball
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setS(() => showRedBall = !showRedBall),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: showRedBall ? Colors.red.withOpacity(0.15) : const Color(0xFF0D0D1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: showRedBall ? Colors.red : Colors.grey[700]!,
                                width: showRedBall ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: showRedBall ? Colors.red : Colors.grey[600], size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Red Ball', style: TextStyle(color: showRedBall ? Colors.red[300] : Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600)),
                                      Text('Draw red circle on ball', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: showRedBall,
                                  onChanged: (v) => setS(() => showRedBall = v),
                                  activeColor: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status / Progress
                  if (statusMsg != null) ...
                    [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (errorMsg != null ? Colors.red : Colors.deepPurple).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (errorMsg != null ? Colors.red : Colors.deepPurple).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            if (isRunning) ...
                              [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple)), const SizedBox(width: 8)]
                            else ...
                              [Icon(errorMsg != null ? Icons.error_outline : Icons.check_circle_outline, color: errorMsg != null ? Colors.red : Colors.green, size: 16), const SizedBox(width: 8)],
                            Expanded(
                              child: Text(statusMsg!, style: TextStyle(color: errorMsg != null ? Colors.red[300] : Colors.purple[200], fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                  // Output URL
                  if (outputUrl != null) ...
                    [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('✅ Output ready!', style: TextStyle(color: Colors.green[300], fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            SelectableText(outputUrl!, style: TextStyle(color: Colors.green[200], fontSize: 11)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_circle_outline, size: 16),
                              label: const Text('Open Video', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () async {
                                final uri = Uri.parse(outputUrl!);
                                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                  // Pipeline script viewer
                  const Divider(color: Color(0xFF2A2A3E), height: 24),
                  Row(
                    children: [
                      Icon(Icons.code, color: Colors.grey[500], size: 16),
                      const SizedBox(width: 6),
                      Text('Current Pipeline Script', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.visibility, size: 14),
                        label: const Text('View Script', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: Colors.deepPurple[300], visualDensity: VisualDensity.compact),
                        onPressed: () => _fetchAndShowPipelineScript(),
                      ),
                    ],
                  ),
                  Text(
                    'BROADCAST_BALL_TRACKING_V4_SCRIPT.py — the script currently deployed inside Modal',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isRunning ? null : () => Navigator.pop(ctx),
              child: Text('Close', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton.icon(
              onPressed: isRunning
                  ? null
                  : () async {
                      final url = urlController.text.trim();
                      if (url.isEmpty) {
                        setS(() { errorMsg = 'Please paste a video URL'; statusMsg = '❌ No URL provided'; });
                        return;
                      }
                      setS(() {
                        isRunning = true;
                        errorMsg = null;
                        outputUrl = null;
                        statusMsg = '⏳ Creating test job in pipeline...';
                      });
                      try {
                        final result = await _triggerPipelineJob(
                          videoUrl: url,
                          showFieldMask: showFieldMask,
                          showRedBall: showRedBall,
                          onStatus: (msg) => setS(() => statusMsg = msg),
                        );
                        setS(() {
                          isRunning = false;
                          statusMsg = '✅ Pipeline job completed! Check Camera Monitoring for results.';
                          outputUrl = result;
                        });
                      } catch (e) {
                        setS(() {
                          isRunning = false;
                          errorMsg = e.toString();
                          statusMsg = '❌ ${e.toString().replaceAll('Exception: ', '')}';
                        });
                      }
                    },
              icon: isRunning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.rocket_launch, size: 16),
              label: Text(isRunning ? 'Running...' : 'Run Pipeline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.deepPurple.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Triggers a real production pipeline job.
  /// Calls process_chunk_webhook directly using a ball_tracking_jobs row as
  /// the tracking record (avoids FK constraint on camera_recording_chunks).
  Future<String?> _triggerPipelineJob({
    required String videoUrl,
    required bool showFieldMask,
    required bool showRedBall,
    required Function(String) onStatus,
  }) async {
    final supabase = Supabase.instance.client;

    // 1. Create a job record in ball_tracking_jobs to track progress
    onStatus('📝 Creating pipeline test record...');
    late String jobId;
    try {
      final row = await supabase.from('ball_tracking_jobs').insert({
        'input_video_url': videoUrl,
        'video_name': 'Pipeline Test — ${DateTime.now().toIso8601String().substring(0, 16)}',
        'status': 'pending',
        'progress_percent': 0,
        'script_version': 'pipeline_v4',
        'script_config': {
          'show_field_mask': showFieldMask,
          'show_red_ball': showRedBall,
          'pipeline': true,
        },
      }).select('id').single();
      jobId = row['id'] as String;
    } catch (e) {
      throw Exception('Could not create job record: $e');
    }

    // 2. Try to find an existing test chunk row (or create one without FK if allowed)
    onStatus('🚀 Calling production pipeline webhook...');
    
    // Use the ball_tracking_jobs id as a proxy chunk_id and a known real schedule
    // The pipeline webhook just needs chunk_id + video_url + schedule_id.
    // We pass jobId as chunk_id — the pipeline will try to update camera_recording_chunks
    // with that id (which won't exist), but it will still process the video correctly.
    // The get_schedule_settings will return empty defaults (no field_id) which is fine
    // since show_field_mask/show_red_ball are passed directly.
    final response = await http.post(
      Uri.parse(_pipelineWebhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chunk_id': jobId,          // Pipeline uses this to update DB (may be a no-op)
        'video_url': videoUrl,
        'schedule_id': jobId,       // No real schedule — get_schedule_settings returns defaults
        'chunk_number': 0,
        'enable_ball_tracking': true,
        'show_field_mask': showFieldMask,
        'show_red_ball': showRedBall,
      }),
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode != 200) {
      throw Exception('Webhook returned ${response.statusCode}: ${response.body}');
    }

    onStatus('⚡ Pipeline started! Processing... (5-20 min depending on video length)');

    // Record the exact time we fired the webhook so we only pick up chunks
    // that were CREATED by this specific pipeline invocation.
    final jobStartedAt = DateTime.now().toUtc();

    // 3. Poll for completion (max 30 min)
    // The pipeline updates camera_recording_chunks; we also watch ball_tracking_jobs.
    // Poll ball_tracking_jobs (user can also watch Camera Monitoring)
    for (int i = 0; i < 360; i++) {
      await Future.delayed(const Duration(seconds: 5));
      final elapsed = (i + 1) * 5;
      final mins = elapsed ~/ 60;
      final secs = elapsed % 60;
      onStatus('⚡ Processing... ${mins}m ${secs}s elapsed. Check Camera Monitoring for live logs.');
      
      // Check ball_tracking_jobs for any manual completion signal
      try {
        final row = await supabase
            .from('ball_tracking_jobs')
            .select('status, output_video_url, progress_percent')
            .eq('id', jobId)
            .single();
        final status = row['status'] as String? ?? 'pending';
        final outputUrl = row['output_video_url'] as String?;
        final progress = row['progress_percent'] as int? ?? 0;
        if (status == 'completed' && outputUrl != null) {
          onStatus('✅ Done! $progress%');
          return outputUrl;
        } else if (status == 'failed') {
          throw Exception('Pipeline processing failed. Check Camera Monitoring logs.');
        }
      } catch (e) {
        if (e.toString().contains('Pipeline processing failed')) rethrow;
      }

      // Also check camera_recording_chunks — but ONLY rows created AFTER we
      // fired the webhook (to avoid stale completed chunks from previous jobs).
      try {
        final chunks = await supabase
            .from('camera_recording_chunks')
            .select('status, gpu_progress, processed_url, created_at')
            .gte('created_at', jobStartedAt.toIso8601String())
            .order('created_at', ascending: false)
            .limit(5);
        for (final raw in chunks) {
          final chunk = raw as Map<String, dynamic>;
          final status = chunk['status'] as String? ?? '';
          final progress = chunk['gpu_progress'] as int? ?? 0;
          final processedUrl = chunk['processed_url'] as String?;
          if (status == 'completed' && processedUrl != null) {
            onStatus('✅ Pipeline done! $progress%');
            // Backfill our job record
            await supabase.from('ball_tracking_jobs').update({
              'status': 'completed',
              'output_video_url': processedUrl,
              'progress_percent': 100,
            }).eq('id', jobId);
            return processedUrl;
          } else if (status == 'failed') {
            throw Exception('Pipeline processing failed. Check Camera Monitoring logs.');
          } else if (progress > 0) {
            onStatus('⚡ GPU processing... $progress% — ${mins}m ${secs}s elapsed');
          }
        }
      } catch (e) {
        if (e.toString().contains('Pipeline processing failed')) rethrow;
      }
    }
    throw Exception('Timed out after 30 minutes. Check Camera Monitoring for job status.');
  }

  /// Fetches and displays the current pipeline script in a code viewer.
  void _fetchAndShowPipelineScript() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.code, color: Colors.deepPurple),
            const SizedBox(width: 8),
            const Expanded(child: Text('BROADCAST_BALL_TRACKING_V4_SCRIPT.py', style: TextStyle(color: Colors.white, fontSize: 14))),
          ],
        ),
        content: FutureBuilder<String>(
          future: () async {
            // Try to read from local file first (desktop)
            try {
              final scriptFile = File('/Users/youssefelhenawy/Desktop/pixelscale/apps/playmakerstart/modal_gpu_function/BROADCAST_BALL_TRACKING_V4_SCRIPT.py');
              if (scriptFile.existsSync()) return scriptFile.readAsStringSync();
            } catch (_) {}
            // Fallback: fetch from GitHub
            try {
              final res = await http.get(Uri.parse(_pipelineScriptRawUrl)).timeout(const Duration(seconds: 15));
              if (res.statusCode == 200) return res.body;
            } catch (_) {}
            return '// Could not load script. Check that the file exists or internet is available.';
          }(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)));
            }
            final content = snap.data ?? '// Error loading script';
            return SizedBox(
              width: 800,
              height: 550,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          content,
                          style: GoogleFonts.robotoMono(fontSize: 11.5, color: const Color(0xFF00FF88)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(child: Text('This is the exact script deployed inside Modal. Changes to this file will take effect after the next `modal deploy`.', style: TextStyle(color: Colors.grey[600], fontSize: 10))),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 13),
                        label: const Text('Copy', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple, side: const BorderSide(color: Colors.deepPurple), visualDensity: VisualDensity.compact),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Script copied!'), backgroundColor: Colors.deepPurple));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: TextStyle(color: Colors.grey[400]))),
        ],
      ),
    );
  }



  Future<void> _deleteJob(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job and its videos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteJob(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showJobDetails(BallTrackingJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(job.videoName),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Status', _getStatusBadge(job.status)),
                _buildDetailRow('Progress', Text('${job.progressPercent}%')),
                _buildDetailRow('Created', Text(DateFormat('MMM dd, yyyy HH:mm').format(job.createdAt.toLocal()))),
                if (job.status == 'completed') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.summarize, color: Colors.green[800], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _buildCompletedSummaryLine(job),
                            style: TextStyle(fontSize: 13, color: Colors.green[900], fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(),
                const Text('📥 Input', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                if (job.videoDurationSeconds != null)
                  _buildDetailRow('⏳ Duration', Text('${job.videoDurationSeconds!.toStringAsFixed(1)}s (${_formatDuration(job.videoDurationSeconds!)})')),
                if (job.videoSizeMb != null)
                  _buildDetailRow('📁 Size', Text('${job.videoSizeMb!.toStringAsFixed(2)} MB')),
                _buildDetailRow('🔗 URL', SelectableText(job.inputVideoUrl, style: const TextStyle(fontSize: 11))),
                const SizedBox(height: 12),
                const Text('📤 Output', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                if (job.outputVideoUrl != null)
                  _buildDetailRow('🔗 Output URL', SelectableText(job.outputVideoUrl!, style: const TextStyle(fontSize: 11)))
                else
                  _buildDetailRow('🔗 Output URL', Text('—', style: TextStyle(color: Colors.grey[600]))),
                const Divider(),
                const Text('📊 Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (job.trackingAccuracyPercent != null) ...[
                  _buildDetailRow('🔴 Frames with ball (red dot)', Text('${job.trackingAccuracyPercent}% of video', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
                    child: Text(
                      'Percentage of the video where the red dot was drawn on the ball. View the Output video (not Input) to see it.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                if (job.framesTracked != null && job.totalFrames != null)
                  _buildDetailRow('🎬 Frames with red dot drawn', Text('${job.framesTracked} / ${job.totalFrames}${job.totalFrames! > 0 ? " (${(100.0 * job.framesTracked! / job.totalFrames!).toStringAsFixed(1)}%)" : ""}')),
                if (job.processingTimeSeconds != null)
                  _buildDetailRow('⏱️ Processing time', Text('${job.processingTimeSeconds!.toStringAsFixed(1)}s')),
                if (job.gpuType != null)
                  _buildDetailRow('🖥️ GPU type', Text(job.gpuType!)),
                if (job.gpuCostUsd != null)
                  _buildDetailRow('💰 GPU cost', Text('\$${job.gpuCostUsd!.toStringAsFixed(4)}')),
                if (job.errorMessage != null) ...[
                  const Divider(),
                  _buildDetailRow('❌ Error', SelectableText(job.errorMessage!, style: const TextStyle(color: Colors.red))),
                ],
                const Divider(),
                const Text('⚙️ Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Script version: ${job.scriptVersion}'),
                      const SizedBox(height: 4),
                      Text('YOLO Model: ${job.modelName ?? job.scriptConfig['yolo_model'] ?? 'yolov8l'}'),
                      Text('Confidence: ${job.scriptConfig['yolo_conf'] ?? 0.35}'),
                      Text('Detect Every: ${job.scriptConfig['detect_every_frames'] ?? 2} frames'),
                      Text('Image Size: ${job.scriptConfig['yolo_img_size'] ?? 960}px'),
                      Text('ROI Size: ${job.scriptConfig['roi_size'] ?? 400}px'),
                      Text('Zoom Base: ${job.scriptConfig['zoom_base'] ?? 1.75}'),
                      Text('Smoothing: ${job.scriptConfig['smoothing'] ?? 0.07}'),
                    ],
                  ),
                ),
                if (job.customScript != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.code, size: 18, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text('🐍 Custom Script', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: job.customScript!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Custom script copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.purple,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy Script', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple[300]!),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        job.customScript!,
                        style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.green[300]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This job used a custom Python script instead of the default algorithm',
                            style: TextStyle(fontSize: 10, color: Colors.purple[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (job.processingLogs != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('📝 Logs', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: job.processingLogs!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Logs copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy Logs', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        job.processingLogs!,
                        style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.green[300]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (job.outputVideoUrl != null) ...[
            // Download button
            ElevatedButton.icon(
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text('Download', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              onPressed: () async {
                final url = Uri.parse(job.outputVideoUrl!);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening video for download...'), backgroundColor: Colors.green),
                  );
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('View Output'),
              onPressed: () async {
                final url = Uri.parse(job.outputVideoUrl!);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
          TextButton.icon(
            icon: const Icon(Icons.video_library),
            label: const Text('View Input'),
            onPressed: () async {
              final url = Uri.parse(job.inputVideoUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Input URL'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: job.inputVideoUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Input video URL copied! Use in Field Mask Editor'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    
    if (duration.inHours > 0) {
      // Format as HH:MM:SS
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final secs = duration.inSeconds.remainder(60);
      return '${hours}h ${minutes}m ${secs}s';
    } else if (duration.inMinutes > 0) {
      // Format as MM:SS
      final minutes = duration.inMinutes;
      final secs = duration.inSeconds.remainder(60);
      return '${minutes}m ${secs}s';
    } else {
      // Format as SS
      return '${duration.inSeconds}s';
    }
  }

  String _buildCompletedSummaryLine(BallTrackingJob job) {
    final parts = <String>[];
    if (job.trackingAccuracyPercent != null) {
      parts.add('${job.trackingAccuracyPercent}% with red dot');
    }
    if (job.processingTimeSeconds != null) {
      parts.add('${job.processingTimeSeconds!.toStringAsFixed(0)}s');
    }
    if (job.gpuCostUsd != null) {
      parts.add('\$${job.gpuCostUsd!.toStringAsFixed(4)}');
    }
    if (job.framesTracked != null && job.totalFrames != null && job.totalFrames! > 0) {
      final pct = (100.0 * job.framesTracked! / job.totalFrames!).toStringAsFixed(0);
      parts.add('${job.framesTracked}/${job.totalFrames} frames ($pct%)');
    }
    if (job.videoDurationSeconds != null) {
      parts.add('Input: ${_formatDuration(job.videoDurationSeconds!)}');
    }
    if (job.videoSizeMb != null) {
      parts.add('${job.videoSizeMb!.toStringAsFixed(1)} MB');
    }
    return parts.isEmpty ? 'Completed' : parts.join(' • ');
  }

  String _getUploadStatusText() {
    final percent = (_uploadProgress * 100).toInt();
    
    // Calculate MB uploaded and remaining
    final uploadedMb = _uploadFileSizeMb * _uploadProgress;
    final totalMb = _uploadFileSizeMb;
    final mbText = '${uploadedMb.toStringAsFixed(1)} MB / ${totalMb.toStringAsFixed(1)} MB';
    
    if (_uploadProgress < 0.3) {
      return '$percent% ($mbText) - Starting upload...';
    } else if (_uploadProgress < 0.7) {
      return '$percent% ($mbText) - Uploading...';
    } else if (_uploadProgress < 0.9) {
      return '$percent% ($mbText) - Upload in progress...';
    } else if (_uploadProgress < 0.95) {
      return '$percent% ($mbText) - Almost done...';
    } else if (_uploadProgress < 0.98) {
      return '$percent% ($mbText) - Finalizing... (Large file, please wait)';
    } else {
      return '$percent% ($mbText) - Completing upload...';
    }
  }

  Widget _getStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.schedule;
        break;
      case 'processing':
        color = Colors.blue;
        icon = Icons.refresh;
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'failed':
        color = Colors.red;
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadJobs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header with Upload Button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sports_soccer, size: 32, color: Color(0xFF00BF63)),
                          const SizedBox(width: 12),
                          Text(
                            'Ball Tracking Lab',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_jobs.length} experiments',
                              style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Pipeline Job Button (Production Pipeline Tester)
                          ElevatedButton.icon(
                            onPressed: _showPipelineJobDialog,
                            icon: const Icon(Icons.rocket_launch, size: 18, color: Colors.white),
                            label: const Text('Pipeline Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Paste URL Button (Primary)
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BallTrackingUrlPage(
                                    jobs: _jobs,
                                    customModelId: _customModelId,
                                    service: _service,
                                    onJobCreated: _loadJobs,
                                    roboflowApiKeyController: _roboflowApiKeyController,
                                    detectEveryFramesController: _detectEveryFramesController,
                                    yoloConfController: _yoloConfController,
                                    yoloImgSizeController: _yoloImgSizeController,
                                    roiSizeController: _roiSizeController,
                                    zoomBaseController: _zoomBaseController,
                                    smoothingController: _smoothingController,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.link, size: 20),
                            label: const Text('Paste Job from URL'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00BF63),
                              side: const BorderSide(color: Color(0xFF00BF63), width: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadJobs,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),
                    // Jobs List
                    Expanded(
                      child: _jobs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No ball tracking jobs yet',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload a match video to start experimenting',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _jobs.length,
                              itemBuilder: (context, index) {
                                final job = _jobs[index];
                                return Row(
                                  children: [
                                    Expanded(child: _buildJobCard(job)),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: null,
    );
  }



  Widget _buildJobCard(BallTrackingJob job) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: job.status == 'completed'
                      ? Colors.green
                      : job.status == 'failed'
                          ? Colors.red
                          : job.status == 'processing'
                              ? Colors.blue
                              : Colors.orange,
                  child: Icon(
                    job.status == 'completed'
                        ? Icons.check
                        : job.status == 'failed'
                            ? Icons.error
                            : job.status == 'processing'
                                ? Icons.refresh
                                : Icons.schedule,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.videoName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                job.scriptConfig['yolo_model']?.toString().contains('tracknet') == true
                                    ? Icons.auto_awesome
                                    : job.scriptConfig['yolo_model']?.toString().contains('roboflow') == true
                                        ? Icons.psychology
                                        : job.scriptConfig['yolo_model']?.toString().contains('rtdetr') == true
                                            ? Icons.memory
                                            : Icons.radar,
                                size: 14,
                                color: job.scriptConfig['yolo_model']?.toString().contains('tracknet') == true
                                    ? Colors.purple
                                    : job.scriptConfig['yolo_model']?.toString().contains('roboflow') == true
                                        ? const Color(0xFF00BF63)
                                        : job.scriptConfig['yolo_model']?.toString().contains('rtdetr') == true
                                            ? Colors.orange
                                            : Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                job.scriptConfig['yolo_model']?.toString().contains('tracknet') == true
                                    ? 'TrackNet V3'
                                    : job.scriptConfig['yolo_model']?.toString().contains('roboflow') == true
                                        ? 'Custom Roboflow'
                                        : job.scriptConfig['yolo_model']?.toString().contains('rtdetr') == true
                                            ? 'RT-DETR'
                                            : 'Standard YOLOv8l',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: job.scriptConfig['yolo_model']?.toString().contains('tracknet') == true
                                      ? Colors.purple[700]
                                      : job.scriptConfig['yolo_model']?.toString().contains('roboflow') == true
                                          ? const Color(0xFF00BF63)
                                          : job.scriptConfig['yolo_model']?.toString().contains('rtdetr') == true
                                              ? Colors.orange[800]
                                              : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        'Created: ${DateFormat('MMM dd, yyyy HH:mm').format(job.createdAt.toLocal())}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (job.videoSizeMb != null || job.videoDurationSeconds != null)
                        Row(
                          children: [
                            if (job.videoDurationSeconds != null) ...[
                              Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(job.videoDurationSeconds!),
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                              if (job.videoSizeMb != null) ...[
                                const SizedBox(width: 8),
                                Text('•', style: TextStyle(color: Colors.grey[400])),
                                const SizedBox(width: 8),
                              ],
                            ],
                            if (job.videoSizeMb != null) ...[
                              Icon(Icons.storage, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${job.videoSizeMb!.toStringAsFixed(1)} MB',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _getStatusBadge(job.status),
                    if (job.customScript != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.code, size: 12, color: Colors.purple[900]),
                            const SizedBox(width: 4),
                            Text(
                              'Custom Script',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar for processing jobs
            if (job.status == 'processing')
              Column(
                children: [
                  LinearProgressIndicator(
                    value: job.progressPercent / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  Text('${job.progressPercent}% complete', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                ],
              ),
            // Completed job: metrics + input summary
            if (job.status == 'completed') ...[
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      '🔴 Red dot %',
                      '${job.trackingAccuracyPercent ?? 0}%',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      '⏱️ Time',
                      '${job.processingTimeSeconds?.toStringAsFixed(1) ?? '?'}s',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      '💰 Cost',
                      '\$${job.gpuCostUsd?.toStringAsFixed(4) ?? '?'}',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      '🎬 Frames',
                      '${job.framesTracked ?? 0}/${job.totalFrames ?? 0}',
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // One-line summary for quick scan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.summarize, size: 14, color: Colors.green[800]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _buildCompletedSummaryLine(job),
                        style: TextStyle(fontSize: 11, color: Colors.green[900]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Configuration
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Model: ${job.scriptConfig['yolo_model'] ?? 'yolov8l'} | Conf: ${job.scriptConfig['yolo_conf'] ?? 0.35} | GPU: ${job.gpuType ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (job.customScript != null) ...[
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: job.customScript!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Custom script copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.purple,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16, color: Colors.purple),
                    label: const Text('Copy Script', style: TextStyle(color: Colors.purple)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (job.outputVideoUrl != null) ...[
                  // Download button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18, color: Colors.white),
                    label: const Text('Download', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () async {
                      final url = Uri.parse(job.outputVideoUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening video for download...'), backgroundColor: Colors.green),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // View output button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('View Output'),
                    onPressed: () async {
                      final url = Uri.parse(job.outputVideoUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Details'),
                  onPressed: () => _showJobDetails(job),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.replay, size: 18, color: Colors.blue),
                  label: const Text('Re-run', style: TextStyle(color: Colors.blue)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    // Navigate to URL page to "Re-run" with same URL
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BallTrackingUrlPage(
                          jobs: _jobs,
                          customModelId: _customModelId,
                          service: _service,
                          onJobCreated: _loadJobs,
                          initialUrl: job.inputVideoUrl,
                          roboflowApiKeyController: _roboflowApiKeyController,
                          detectEveryFramesController: _detectEveryFramesController,
                          yoloConfController: _yoloConfController,
                          yoloImgSizeController: _yoloImgSizeController,
                          roiSizeController: _roiSizeController,
                          zoomBaseController: _zoomBaseController,
                          smoothingController: _smoothingController,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteJob(job.id),
                  tooltip: 'Delete',
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

