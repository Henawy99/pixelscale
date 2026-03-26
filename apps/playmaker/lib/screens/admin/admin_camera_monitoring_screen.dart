import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'field_mask_editor_screen.dart';
import 'script_editor_screen.dart';

/// Camera monitoring screen for the ADMIN app
/// Shows real-time status of all Raspberry Pi camera recorders
class AdminCameraMonitoringScreen extends StatefulWidget {
  const AdminCameraMonitoringScreen({Key? key}) : super(key: key);

  @override
  State<AdminCameraMonitoringScreen> createState() => _AdminCameraMonitoringScreenState();
}


/// Embedded description of the active GPU ball tracking script.
/// Shown when CDN/Supabase record is stale or expired.
const String _kBallTrackingV4Description = '''
# ══════════════════════════════════════════════════════════════
# ACTIVE GPU PIPELINE: BROADCAST_BALL_TRACKING_V4_SCRIPT v4.2
# Bundled in Modal container — all recordings use this.
# ══════════════════════════════════════════════════════════════
#
# Algorithm: Dynamic Lookahead-Backtrack + Native Resolution
#
# KEY FEATURES:
#   - All 4 detection strategies:
#       1. ROI crop every 3rd frame (tight crop around predicted position)
#       2. Full-frame every 10th frame (catches wide-angle events)
#       3. Zone-split (3 overlapping zones when ball lost > 5 frames)
#       4. Motion detection (optical flow when ball lost > 8 frames)
#   - Dynamic 5→15 frame backtrack buffer:
#       Extends automatically when ball is lost longer
#   - Cubic-smooth interpolation on re-detection:
#       All missed frames get retroactively smooth positions
#   - Kalman filter with kick-detection (adaptive noise on acceleration spike)
#   - Native resolution output (no scaling, full input quality = output quality)
#   - SmoothCamera: velocity-limited, acceleration-damped broadcast camera
#   - ~0.4 YOLO calls/frame → 10min footage processes in ~6-8min GPU time
#   - Field mask support, 9:16 Reels/TikTok output
#   - Red ball overlay support
#
# COST TARGET: 10 min footage ≤ 10 min processing
#
# To update this script: Edit BROADCAST_BALL_TRACKING_V4_SCRIPT.py
# and run: modal deploy modal_gpu_function/chunk_processor.py
''';

class _AdminCameraMonitoringScreenState extends State<AdminCameraMonitoringScreen> {

  final _supabase = Supabase.instance.client;
  List<CameraStatus> _cameras = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription? _realtimeSubscription;
  
  // Recording schedules
  List<Map<String, dynamic>> _schedules = [];
  StreamSubscription? _schedulesSubscription;
  // Pagination for completed jobs
  int _completedJobsLimit = 20;
  bool _hasMoreJobs = true;
  bool _isLoadingMoreJobs = false;
  
  // Chunks data for progress tracking
  Map<String, List<Map<String, dynamic>>> _chunksData = {};
  StreamSubscription? _chunksSubscription;

  // Pipeline Script Management (Pi Script)
  String _pipelineScript = '';
  String _pipelineVersion = '1.0';
  bool _isPipelineLoading = false;
  String? _lastScriptUrl;
  DateTime? _pipelineLastDeployed;

  // Ball Tracking Script Management (Modal/GPU Script)
  String _ballTrackingScript = '';
  String _ballTrackingVersion = '1.0';
  bool _isBallTrackingLoading = false;
  String? _lastBallTrackingScriptUrl;
  DateTime? _ballTrackingLastDeployed;

  String? _expandedScriptType; // 'pipeline' or 'ball_tracking' or null

  // Script history
  List<Map<String, dynamic>> _pipelineHistory = [];
  List<Map<String, dynamic>> _ballTrackingHistory = [];
  bool _showPipelineHistory = false;
  bool _showBallTrackingHistory = false;
  String? _previewingHistoryUrl; // url of a historic version being previewed
  String? _previewingHistoryContent; // cached content of previewed version
  bool _isPreviewLoading = false;

  bool _showFieldMaskGlobal = true;
  bool _showRedBallGlobal = true;

  @override
  void initState() {
    super.initState();
    _loadCameras();
    _setupRealtime();
    _setupChunksRealtime();
    // Load schedules first, THEN load chunks (chunks depend on _schedules)
    _loadSchedules().then((_) => _loadChunksData());
    _loadPipelineConfig();
    _loadScriptHistory();
    // Refresh every 3 seconds for active recordings
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_hasActiveRecordings()) {
        _loadSchedules();
        _loadChunksData(); // Also refresh chunks!
      }
    });
  }
  
  // Fetch chunks from database (backup for realtime)
  Future<void> _loadChunksData() async {
    try {
      // Get all chunks for active AND recent completed schedules (last 10)
      final relevantScheduleIds = _schedules
          .where((s) => 
            s['status'] == 'recording' || 
            s['status'] == 'uploading' || 
            s['status'] == 'processing' ||
            s['status'] == 'completed' ||
            s['status'] == 'replay_requested'  // SD replay: Pi will create chunks
          )
          .take(15) // Limit to prevent too many queries
          .map((s) => s['id'] as String)
          .toList();
      
      if (relevantScheduleIds.isEmpty) return;
      
      final data = await _supabase
          .from('camera_recording_chunks')
          .select('*')
          .inFilter('schedule_id', relevantScheduleIds)
          .order('chunk_number', ascending: true);
      
      if (data != null) {
        _updateChunksData(List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      print('Error loading chunks: $e');
    }
  }

  bool _hasActiveRecordings() {
    return _schedules.any((s) => 
      s['status'] == 'scheduled' ||  // Include scheduled jobs for refresh
      s['status'] == 'recording' || 
      s['status'] == 'processing' || 
      s['status'] == 'uploading' ||
      s['status'] == 'replay_requested'  // SD replay in progress
    );
  }

  /// True if schedule's end time is in the past (so "Add footage" for former recording makes sense).
  bool _isSchedulePast(Map<String, dynamic> job) {
    final endStr = job['end_time'] ?? job['end_time_old'];
    if (endStr == null) return false;
    try {
      final end = DateTime.parse(endStr.toString());
      return end.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtimeSubscription?.cancel();
    _schedulesSubscription?.cancel();
    _chunksSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtime() {
    _setupCameraStatusStream();
    _setupSchedulesStream();
  }
  
  void _setupCameraStatusStream() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _supabase
        .from('camera_status')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            if (mounted) {
              _loadCameras();
            }
          },
          onError: (e) {
            print('⚠️ Camera status stream error: $e');
            // Retry connection after delay
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                _setupCameraStatusStream();
              }
            });
          },
          cancelOnError: false,
        );
  }
  
  void _setupSchedulesStream() {
    _schedulesSubscription?.cancel();
    _schedulesSubscription = _supabase
        .from('camera_recording_schedules')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            if (mounted) {
              print('🔄 Realtime: Schedules stream fired with ${data.length} items');
              _loadSchedules();
            }
          },
          onError: (e) {
            print('⚠️ Schedules stream error: $e');
            // Retry connection after delay
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                _setupSchedulesStream();
              }
            });
          },
          cancelOnError: false,
        );
  }
  
  void _setupChunksRealtime() {
    _setupChunksStream();
  }
  
  void _setupChunksStream() {
    try {
      _chunksSubscription?.cancel();
      _chunksSubscription = _supabase
          .from('camera_recording_chunks')
          .stream(primaryKey: ['id'])
          .listen(
            (data) {
              if (mounted) {
                _updateChunksData(data);
              }
            }, 
            onError: (e) {
              print('⚠️ Chunks stream error: $e');
              // Retry connection after delay
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  _setupChunksStream();
                }
              });
            },
            cancelOnError: false,
          );
    } catch (e) {
      print('Failed to setup chunks realtime: $e');
    }
  }
  
  void _updateChunksData(List<Map<String, dynamic>> chunks) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final chunk in chunks) {
      final scheduleId = chunk['schedule_id'] as String?;
      if (scheduleId != null) {
        grouped.putIfAbsent(scheduleId, () => []);
        grouped[scheduleId]!.add(chunk);
      }
    }
    
    // Deduplicate by chunk_number (keep latest based on updated_at or created_at)
    for (final scheduleId in grouped.keys) {
      final chunksByNumber = <int, Map<String, dynamic>>{};
      for (final chunk in grouped[scheduleId]!) {
        final chunkNum = chunk['chunk_number'] as int? ?? 0;
        final existing = chunksByNumber[chunkNum];
        if (existing == null) {
          chunksByNumber[chunkNum] = chunk;
        } else {
          // Keep the one with higher upload_progress or processed_url
          final existingProgress = existing['upload_progress'] ?? 0;
          final newProgress = chunk['upload_progress'] ?? 0;
          if (newProgress > existingProgress || chunk['processed_url'] != null) {
            chunksByNumber[chunkNum] = chunk;
          }
        }
      }
      grouped[scheduleId] = chunksByNumber.values.toList();
    }
    
    // Sort chunks by chunk_number
    for (final list in grouped.values) {
      list.sort((a, b) => (a['chunk_number'] ?? 0).compareTo(b['chunk_number'] ?? 0));
    }
    setState(() {
      _chunksData = grouped;
    });
    
    // Auto-detect and mark completed jobs
    _checkAndMarkCompletedJobs(grouped);
  }
  
  /// Automatically marks jobs as 'completed' when all processable chunks are GPU done.
  /// Key rules:
  ///  - `recording_failed` chunks are counted as terminal (skipped, not pending).
  ///  - Jobs are only marked completed if a final_video_url is present OR if the Pi 
  ///    provided a mergedURL (set by the Pi after merging).
  ///  - We compare GPU-completed count against ACTUAL chunks in DB (not total_chunks 
  ///    expected), because the Pi sometimes records fewer chunks than planned.
  Future<void> _checkAndMarkCompletedJobs(Map<String, List<Map<String, dynamic>>> chunksData) async {
    for (final schedule in _schedules) {
      final scheduleId = schedule['id'] as String?;
      final status = schedule['status'] as String?;

      // Only try to auto-complete jobs in active/processing states
      if (scheduleId == null) continue;
      if (status == 'completed' || status == 'cancelled' || status == 'failed') continue;
      if (status != 'recording' && status != 'processing' && status != 'uploading') continue;

      // If there's already a final video URL, trust the Pi and mark as completed
      final existingFinalUrl = schedule['final_video_url'] ?? schedule['merged_video_url'];
      if (existingFinalUrl != null) {
        print('✅ Schedule $scheduleId has final_video_url set — marking as completed.');
        try {
          await _supabase.from('camera_recording_schedules').update({
            'status': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', scheduleId);
          _loadSchedules();
        } catch (e) {
          print('⚠️ Failed to mark schedule as completed: $e');
        }
        continue;
      }

      final chunks = chunksData[scheduleId] ?? [];
      if (chunks.isEmpty) continue;

      // Categorize chunks
      final gpuCompleted = chunks.where((c) =>
        c['gpu_status'] == 'completed' || c['processed_url'] != null
      ).length;
      final recordingFailed = chunks.where((c) =>
        c['status'] == 'recording_failed'
      ).length;
      final totalInDb = chunks.length;

      // A chunk is "terminal" if it's GPU-completed or recording-failed (can't be processed)
      final terminalCount = gpuCompleted + recordingFailed;

      // Use expected total for comparison, but fall back to DB count if expected is 0 or lower
      int expectedTotal = schedule['total_chunks'] as int? ?? 0;
      if (expectedTotal == 0 || totalInDb > expectedTotal) {
        expectedTotal = totalInDb;
        print('ℹ️ Using actual DB chunk count ($totalInDb) for schedule $scheduleId');
      }

      print('📊 Schedule $scheduleId: $gpuCompleted GPU done, $recordingFailed recording_failed, '
            '$totalInDb in DB, $expectedTotal expected, $terminalCount terminal');

      // Only auto-complete if ALL chunks in DB are terminal AND we have at least one processed URL
      if (terminalCount >= totalInDb && totalInDb > 0 && gpuCompleted > 0) {
        // Don't auto-complete if we're clearly still missing chunks (less than 80% of expected in DB)
        final inDbRatio = totalInDb / expectedTotal;
        if (inDbRatio < 0.8) {
          print('⏳ Waiting for more chunks: $totalInDb/$expectedTotal in DB — not completing yet.');
          continue;
        }

        // Collect the first processed URL to save as final_video_url
        String? finalVideoUrl;
        final processedChunks = chunks
            .where((c) => c['processed_url'] != null)
            .toList()
          ..sort((a, b) => (a['chunk_number'] ?? 0).compareTo(b['chunk_number'] ?? 0));
        if (processedChunks.isNotEmpty) {
          finalVideoUrl = processedChunks.first['processed_url'];
        }

        // Without any processed URL, don't mark as completed — wait for merge
        if (finalVideoUrl == null) {
          print('⏳ Schedule $scheduleId: All chunks terminal but no processed_url yet — skipping.');
          continue;
        }

        print('🎉 Auto-completing schedule $scheduleId: $gpuCompleted/$totalInDb GPU done, $recordingFailed failed chunks skipped.');
        try {
          await _supabase.from('camera_recording_schedules').update({
            'status': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'final_video_url': finalVideoUrl,
          }).eq('id', scheduleId);
          print('✅ Schedule $scheduleId auto-marked as completed.');
          _loadSchedules();
        } catch (e) {
          print('⚠️ Failed to mark schedule as completed: $e');
        }
      }
    }
  }

  Future<void> _loadCameras() async {
    try {
      // Get camera status with field info
      List<dynamic> statusData = [];
      try {
        statusData = await _supabase
          .from('camera_status')
          .select('*')
          .order('last_heartbeat', ascending: false);
      } catch (e) {
        print('Error loading camera_status: $e');
      }

      // Get all fields with cameras
      final fieldsData = await _supabase
          .from('football_fields')
          .select('id, football_field_name, location_name, camera_ip_address, raspberry_pi_ip, has_camera')
          .not('camera_ip_address', 'is', null);

      // Merge data
      final Map<String, dynamic> statusMap = {};
      for (var status in statusData) {
        if (status['field_id'] != null) {
        statusMap[status['field_id']] = status;
        }
      }

      final cameras = <CameraStatus>[];
      for (var field in fieldsData) {
        final fieldId = field['id'];
        if (fieldId == null) continue;
        
        final status = statusMap[fieldId];
        
        // Parse details safely
        Map<String, dynamic> details = {};
        if (status?['details'] != null) {
          try {
            if (status!['details'] is String && status['details'].toString().isNotEmpty) {
              details = Map<String, dynamic>.from(jsonDecode(status['details']));
            } else if (status['details'] is Map) {
              details = Map<String, dynamic>.from(status['details']);
            }
          } catch (e) {
            print('Error parsing details: $e');
          }
        }
        
        cameras.add(CameraStatus(
          fieldId: fieldId,
          fieldName: field['football_field_name'] ?? 'Unknown Field',
          location: field['location_name'] ?? '',
          cameraIp: field['camera_ip_address'],
          piIp: field['raspberry_pi_ip'],
          status: status?['status'] ?? 'offline',
          lastHeartbeat: status?['last_heartbeat'] != null 
              ? DateTime.tryParse(status['last_heartbeat']) 
              : null,
          details: details,
        ));
      }

      if (mounted) {
        setState(() {
          _cameras = cameras;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading cameras: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadSchedules() async {
    try {
      // Load active/recent jobs (non-completed) + last 20 completed
      final data = await _supabase
          .from('camera_recording_schedules')
          .select('*')
          .order('created_at', ascending: false)
          .limit(_completedJobsLimit);
      
      if (mounted) {
        final newSchedules = List<Map<String, dynamic>>.from(data);
        
        if (_schedules.length != newSchedules.length) {
          print('📋 Schedules changed: ${_schedules.length} -> ${newSchedules.length}');
        }
        
        if (_schedules.isNotEmpty && newSchedules.isEmpty) {
          print('⚠️ Warning: Received empty schedules list, keeping existing ${_schedules.length} schedules');
          return;
        }
        
        setState(() {
          _schedules = newSchedules;
          _hasMoreJobs = newSchedules.length >= _completedJobsLimit;
        });
      }
    } catch (e) {
      print('❌ Error loading schedules: $e');
    }
  }

  Future<void> _loadMoreJobs() async {
    if (_isLoadingMoreJobs || !_hasMoreJobs) return;
    setState(() => _isLoadingMoreJobs = true);
    try {
      final newLimit = _completedJobsLimit + 20;
      final data = await _supabase
          .from('camera_recording_schedules')
          .select('*')
          .order('created_at', ascending: false)
          .limit(newLimit);
      final fetched = List<Map<String, dynamic>>.from(data);
      setState(() {
        _completedJobsLimit = newLimit;
        _schedules = fetched;
        _hasMoreJobs = fetched.length >= newLimit;
        _isLoadingMoreJobs = false;
      });
    } catch (e) {
      print('❌ Error loading more jobs: $e');
      setState(() => _isLoadingMoreJobs = false);
    }
  }

  Future<void> _loadPipelineConfig() async {
    setState(() {
      _isPipelineLoading = true;
      _isBallTrackingLoading = true;
    });
    
    try {
      // 1. Load Pipeline (Pi) script
      var piResult;
      try {
        piResult = await _supabase
            .from('pi_script_updates')
            .select('*')
            .eq('script_type', 'pipeline')
            .order('pushed_at', ascending: false)
            .limit(1);
      } catch (e) {
        if (e.toString().contains('42703')) {
          // Column missing fallback
          piResult = await _supabase
              .from('pi_script_updates')
              .select('*')
              .order('pushed_at', ascending: false)
              .limit(1);
        } else {
          rethrow;
        }
      }
      
      if ((piResult as List).isNotEmpty) {
        final latest = piResult[0];
        _pipelineVersion = latest['version']?.toString() ?? '1.0';
        _lastScriptUrl = latest['script_url'];
        if (latest['pushed_at'] != null) {
          _pipelineLastDeployed = DateTime.tryParse(latest['pushed_at'])?.toLocal();
        }
        
        // Try CDN first, fall back to stored script_content in Supabase
        bool loaded = false;
        if (_lastScriptUrl != null) {
          try {
            final response = await http.get(Uri.parse(_lastScriptUrl!)).timeout(const Duration(seconds: 10));
            if (response.statusCode == 200) {
              _pipelineScript = response.body;
              loaded = true;
            }
          } catch (e) {
            // CDN failed, try fallback
          }
        }
        
        if (!loaded) {
          // Fallback 1: script_content column in Supabase
          final storedContent = latest['script_content']?.toString();
          if (storedContent != null && storedContent.isNotEmpty && !storedContent.startsWith('# Error')) {
            _pipelineScript = storedContent;
          } else {
            // Fallback 2: show actionable message
            _pipelineScript = '# Pi Pipeline Script v$_pipelineVersion\n'
                '# CDN link has expired. Click "Edit & Deploy" to push a fresh version.\n'
                '# The Pi already has this script cached locally — recordings still work.';
          }
        }
      }

      // 2. Load Ball Tracking (GPU) script
      var btResult;
      try {
        btResult = await _supabase
            .from('pi_script_updates')
            .select('*')
            .eq('script_type', 'ball_tracking')
            .order('pushed_at', ascending: false)
            .limit(1);
        
        if ((btResult as List).isNotEmpty) {
          final latestBt = btResult[0];
          _ballTrackingVersion = latestBt['version']?.toString() ?? '1.0';
          _lastBallTrackingScriptUrl = latestBt['script_url'];
          if (latestBt['pushed_at'] != null) {
            _ballTrackingLastDeployed = DateTime.tryParse(latestBt['pushed_at'])?.toLocal();
          }
          
          // Try CDN first, fall back to stored script_content
          bool btLoaded = false;
          if (_lastBallTrackingScriptUrl != null) {
            try {
              final response = await http.get(Uri.parse(_lastBallTrackingScriptUrl!)).timeout(const Duration(seconds: 10));
              if (response.statusCode == 200) {
                _ballTrackingScript = response.body;
                btLoaded = true;
              }
            } catch (e) {
              // CDN failed
            }
          }
          
          if (!btLoaded) {
            // Fallback 1: script_content column in Supabase
            final storedContent = latestBt['script_content']?.toString();
            // Accept storedContent only if it's real script code (not CDN-expired placeholder)
            final isRealScript = storedContent != null &&
                storedContent.isNotEmpty &&
                !storedContent.startsWith('# Error') &&
                !storedContent.startsWith('# GPU Ball Tracking Script') &&
                !storedContent.startsWith('# CDN link');
            if (isRealScript) {
              _ballTrackingScript = storedContent!;
            } else {
              // Fallback 2: Show embedded v4.2 description
              // The REAL script is BROADCAST_BALL_TRACKING_V4_SCRIPT.py bundled in Modal.
              // Attempt to save it back so future fetches work.
              _ballTrackingScript = _kBallTrackingV4Description;
              // Silently try to update the Supabase record with the real description
              _supabase.from('pi_script_updates')
                  .update({'script_content': _kBallTrackingV4Description})
                  .eq('id', latestBt['id']).catchError((_) {});
            }
          }
        } else {
          _ballTrackingVersion = '1.0';
          _ballTrackingScript = '# No ball tracking script entries found.\n'
              '# ACTIVE PIPELINE: BROADCAST_BALL_TRACKING_V4_SCRIPT (bundled in Modal container)';
        }
      } catch (e) {
        print('Warning: Failed to load ball tracking script: $e');
        _ballTrackingVersion = '1.0';
        _ballTrackingScript = '# ACTIVE PIPELINE: BROADCAST_BALL_TRACKING_V4_SCRIPT (bundled in Modal container)';
      }
    } catch (e) {
      print('Error loading pipeline config: $e');
      try {
        final result = await _supabase
            .from('pi_script_updates')
            .select('*')
            .order('pushed_at', ascending: false)
            .limit(1);
        if ((result as List).isNotEmpty) {
          final latest = result[0];
          _pipelineVersion = latest['version']?.toString() ?? '1.0';
          _lastScriptUrl = latest['script_url'];
        }
      } catch (e2) {
        print('Fallback also failed: $e2');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPipelineLoading = false;
          _isBallTrackingLoading = false;
        });
      }

    }
  }

  /// Loads all past versions from pi_script_updates for history display
  Future<void> _loadScriptHistory() async {
    try {
      final piHistory = await _supabase
          .from('pi_script_updates')
          .select('id, version, pushed_at, script_url, script_type')
          .eq('script_type', 'pipeline')
          .order('pushed_at', ascending: false)
          .limit(20);
      
      final btHistory = await _supabase
          .from('pi_script_updates')
          .select('id, version, pushed_at, script_url, script_type')
          .eq('script_type', 'ball_tracking')
          .order('pushed_at', ascending: false)
          .limit(20);
      
      if (mounted) {
        setState(() {
          _pipelineHistory = List<Map<String, dynamic>>.from(piHistory);
          _ballTrackingHistory = List<Map<String, dynamic>>.from(btHistory);
        });
      }
    } catch (e) {
      print('Error loading script history: $e');
    }
  }

  Future<void> _deployNewVersion({required String type}) async {
    // Deterministic versioning
    String currentVersion = type == 'pipeline' ? _pipelineVersion : _ballTrackingVersion;
    String nextVersion;
    if (currentVersion == '1.0') {
      nextVersion = '1.1';
    } else {
      double currentVer = double.tryParse(currentVersion) ?? 1.0;
      nextVersion = (currentVer + 0.1).toStringAsFixed(1);
    }
    
    final refresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ScriptEditorScreen(
          supabase: _supabase,
          scriptType: type,
          initialScript: type == 'pipeline' ? _pipelineScript : _ballTrackingScript,
          initialVersion: nextVersion,
          initialShowFieldMask: _showFieldMaskGlobal,
          initialShowRedBall: _showRedBallGlobal,
          onlineCount: _cameras.where((c) => c.healthStatus == HealthStatus.healthy).length,
        ),
      ),
    );
    
    if (refresh == true) {
      _loadPipelineConfig();
    }
  }

  void _showSetupInstructions() {
    showDialog(
      context: context,
      builder: (context) => const _SetupInstructionsDialog(),
    );
  }

  Future<void> _showLogsDialog(CameraStatus camera) async {
    await showDialog(
      context: context,
      builder: (context) => _CameraLogsDialog(camera: camera),
    );
  }

  void _showStatsDialog(CameraStatus camera) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.bar_chart, color: Colors.green, size: 24),
            const SizedBox(width: 10),
            Text(
              'Pi Stats',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field name
              Text(
                camera.fieldName,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                camera.location,
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              
              // Status card
              _buildStatCard(
                icon: Icons.circle,
                iconColor: camera.status == 'online' || camera.status == 'idle' ? Colors.green : 
                         camera.status == 'recording' ? Colors.red : Colors.orange,
                label: 'Status',
                value: camera.status.toUpperCase(),
              ),
              const SizedBox(height: 10),
              
              // Last heartbeat
              if (camera.lastHeartbeat != null)
                _buildStatCard(
                  icon: Icons.favorite,
                  iconColor: Colors.pink,
                  label: 'Last Heartbeat',
                  value: _formatHeartbeat(camera.lastHeartbeat!),
                ),
              
              const SizedBox(height: 10),
              
              // Camera check
              _buildStatCard(
                icon: Icons.videocam,
                iconColor: camera.details['camera_ok'] == true ? Colors.green : Colors.red,
                label: 'Camera Connection',
                value: camera.details['camera_ok'] == true ? 'Connected' : 'Not Checked',
              ),
              
              const SizedBox(height: 10),
              
              // Pi IP
              if (camera.piIp != null)
                _buildStatCard(
                  icon: Icons.router,
                  iconColor: Colors.blue,
                  label: 'Pi IP Address',
                  value: camera.piIp!,
                ),
              
              const SizedBox(height: 10),
              
              // Camera IP
              if (camera.cameraIp != null)
                _buildStatCard(
                  icon: Icons.camera_alt,
                  iconColor: Colors.purple,
                  label: 'Camera IP',
                  value: camera.cameraIp!,
                ),
              
              // Additional details from the details map
              if (camera.details.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Current Activity',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                
                if (camera.details['schedule_id'] != null)
                  _buildStatCard(
                    icon: Icons.event,
                    iconColor: Colors.orange,
                    label: 'Active Schedule',
                    value: camera.details['schedule_id'].toString().substring(0, 8),
                  ),
                  
                if (camera.details['message'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            camera.details['message'].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                if (camera.details['last_recording'] != null) ...[
                  const SizedBox(height: 8),
                  _buildStatCard(
                    icon: Icons.history,
                    iconColor: Colors.grey,
                    label: 'Last Recording',
                    value: camera.details['last_recording'].toString().substring(0, 8),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatHeartbeat(DateTime heartbeat) {
    final diff = DateTime.now().difference(heartbeat);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    }
  }

  Future<void> _showScheduleRecordingDialog(CameraStatus camera) async {
    await showDialog(
      context: context,
      builder: (context) => _ScheduleRecordingDialog(
        pipelineVersion: _pipelineVersion,
        ballTrackingVersion: _ballTrackingVersion,
        camera: camera,
        onPastDateScheduleCreated: ({
          required String scheduleId,
          required String fieldId,
          required String fieldName,
          required bool enableBallTracking,
          required bool showFieldMask,
          required int totalChunks,
        }) {
          _showAddFootageDialog(
            scheduleId: scheduleId,
            fieldId: fieldId,
            fieldName: fieldName,
            enableBallTracking: enableBallTracking,
            showFieldMask: showFieldMask,
            showRedBall: _showRedBallGlobal,
            totalChunks: totalChunks,
          );
        },
        initialEnableBallTracking: true,
        initialShowFieldMask: _showFieldMaskGlobal,
        initialShowRedBall: _showRedBallGlobal,
      ),
    );
  }

  /// Modal chunk processor webhook (same as Pi uses)
  static const String _chunkProcessorWebhookUrl =
      'https://youssefelhenawy0--playmakerstart-process-chunk-webhook.modal.run';

  Future<void> _showAddFootageDialog({
    required String scheduleId,
    required String fieldId,
    required String fieldName,
    required bool enableBallTracking,
    required bool showFieldMask,
    required bool showRedBall,
    required int totalChunks,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => _AddFootageDialog(
        scheduleId: scheduleId,
        fieldId: fieldId,
        fieldName: fieldName,
        enableBallTracking: enableBallTracking,
        showFieldMask: showFieldMask,
        showRedBall: showRedBall,
        totalChunks: totalChunks,
        chunkProcessorWebhookUrl: _chunkProcessorWebhookUrl,
        supabase: _supabase,
        onComplete: () {
          _loadSchedules();
          _loadChunksData();
        },
      ),
    );
  }

  /// Request a screenshot from the Pi and open the field mask editor
  Future<void> _requestScreenshotAndEditMask(CameraStatus camera) async {
    final isOnline = camera.healthStatus == HealthStatus.healthy || camera.healthStatus == HealthStatus.warning;
    
    if (!isOnline) {
      // Pi is offline - go straight to editor (manual URL mode)
      _openFieldMaskEditor(camera, null);
      return;
    }
    
    // Pi is online - try to request a screenshot
    String? screenshotUrl;
    bool cancelled = false;
    bool dialogOpen = true;
    
    // Record the existing screenshot_url so we can detect a NEW one
    String? existingScreenshotUrl;
    try {
      final existing = await _supabase
          .from('camera_status')
          .select('*')
          .eq('field_id', camera.fieldId)
          .maybeSingle();
      existingScreenshotUrl = existing?['screenshot_url'] as String?;
    } catch (_) {}
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF00BF63)),
            ),
            const SizedBox(height: 20),
            Text(
              'Requesting screenshot...',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for ${camera.fieldName} Pi to capture a frame',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.pop(ctx);
              dialogOpen = false;
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.pop(ctx);
              dialogOpen = false;
              // Open editor without screenshot
              _openFieldMaskEditor(camera, null);
            },
            child: Text('Skip & Open Editor', style: TextStyle(color: Colors.blue.shade700)),
          ),
        ],
      ),
    );
    
    try {
      // Try to set screenshot_requested = true
      bool requestSent = false;
      try {
        await _supabase.from('camera_status').update({
          'screenshot_requested': true,
        }).eq('field_id', camera.fieldId);
        requestSent = true;
        print('✅ Screenshot request sent to Pi');
      } catch (e) {
        // Column likely doesn't exist - tell the user
        print('⚠️ Screenshot request failed (columns may not exist): $e');
      }
      
      if (!requestSent) {
        // Columns don't exist - dismiss dialog and go straight to editor
        if (dialogOpen && mounted) {
          Navigator.pop(context);
          dialogOpen = false;
        }
        if (!cancelled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ Screenshot columns not set up yet. Opening editor manually.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'How to fix',
                textColor: Colors.white,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Setup Required'),
                      content: SelectableText(
                        'Run this SQL in Supabase SQL Editor:\n\n'
                        'ALTER TABLE camera_status\n'
                        '  ADD COLUMN IF NOT EXISTS screenshot_requested BOOLEAN DEFAULT FALSE,\n'
                        '  ADD COLUMN IF NOT EXISTS screenshot_url TEXT,\n'
                        '  ADD COLUMN IF NOT EXISTS screenshot_at TIMESTAMPTZ;\n\n'
                        'Then update the Pi script with the latest version.',
                        style: GoogleFonts.robotoMono(fontSize: 12),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: 'ALTER TABLE camera_status ADD COLUMN IF NOT EXISTS screenshot_requested BOOLEAN DEFAULT FALSE, ADD COLUMN IF NOT EXISTS screenshot_url TEXT, ADD COLUMN IF NOT EXISTS screenshot_at TIMESTAMPTZ;',
                            ));
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Copied SQL to clipboard!'), backgroundColor: Colors.green),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy SQL'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
          _openFieldMaskEditor(camera, null);
        }
        return;
      }
      
      // Poll for screenshot_url (Pi checks every 5s, so wait up to 30s)
      for (int i = 0; i < 15; i++) {
        if (cancelled || !mounted) return;
        
        await Future.delayed(const Duration(seconds: 2));
        
        if (cancelled || !mounted) return;
        
        // Check if screenshot is ready - use select('*') to avoid column errors
        try {
          final result = await _supabase
              .from('camera_status')
              .select('*')
              .eq('field_id', camera.fieldId)
              .maybeSingle();
          
          if (result != null) {
            final currentUrl = result['screenshot_url'] as String?;
            final stillRequested = result['screenshot_requested'];
            
            // Screenshot is ready if:
            // 1. screenshot_url exists AND is different from before (new screenshot)
            // 2. screenshot_requested is no longer true (Pi cleared it)
            if (currentUrl != null && 
                currentUrl.isNotEmpty &&
                (currentUrl != existingScreenshotUrl || stillRequested == false)) {
              screenshotUrl = currentUrl;
              break;
            }
          }
        } catch (e) {
          print('Screenshot poll error: $e');
        }
      }
    } catch (e) {
      print('Screenshot request error: $e');
    } finally {
      // ALWAYS dismiss the loading dialog
      if (dialogOpen && mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
        dialogOpen = false;
      }
    }
    
    if (cancelled || !mounted) return;
    
    if (screenshotUrl != null) {
      // Open field mask editor with live screenshot
      _openFieldMaskEditor(camera, screenshotUrl);
    } else {
      // Screenshot timed out - open editor without screenshot
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Screenshot timed out — opening editor without live image. You can load a video URL manually.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      _openFieldMaskEditor(camera, null);
    }
  }
  
  /// Open the field mask editor with optional screenshot
  Future<void> _openFieldMaskEditor(CameraStatus camera, String? screenshotUrl) async {
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FieldMaskEditorScreen(
          fieldId: camera.fieldId,
          fieldName: camera.fieldName,
          screenshotUrl: screenshotUrl,
          cameraFieldId: camera.fieldId,
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Field mask saved! Pi will apply it on next job.'), backgroundColor: Colors.green),
      );
    }
  }

  /// Show screen to push a script update to all Pis
  Future<void> _showPushScriptUpdateDialog() async {
    final refresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ScriptEditorScreen(
          supabase: _supabase,
          scriptType: 'pipeline',
          initialScript: _pipelineScript,
          initialVersion: _pipelineVersion == '1.0' ? '1.1' : (double.tryParse(_pipelineVersion)! + 0.1).toStringAsFixed(1),
          initialShowFieldMask: _showFieldMaskGlobal,
          initialShowRedBall: _showRedBallGlobal,
          onlineCount: _cameras.where((c) => 
            c.healthStatus == HealthStatus.healthy || c.healthStatus == HealthStatus.warning
          ).length,
        ),
      ),
    );
    
    if (refresh == true) {
      _loadPipelineConfig();
    }
  }

  /// Manually mark a job as completed (for admin use)
  Future<void> _markJobAsCompleted(String scheduleId, List<Map<String, dynamic>> chunks) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Job as Completed?'),
        content: const Text('This will mark the recording job as completed. Use this if all chunks are processed but the status wasn\'t updated automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      // Get the first processed URL as final video URL
      String? finalVideoUrl;
      final processedChunks = chunks.where((c) => c['processed_url'] != null).toList();
      if (processedChunks.isNotEmpty) {
        processedChunks.sort((a, b) => (a['chunk_number'] ?? 0).compareTo(b['chunk_number'] ?? 0));
        finalVideoUrl = processedChunks.first['processed_url'];
      }
      
      await _supabase.from('camera_recording_schedules').update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        if (finalVideoUrl != null) 'final_video_url': finalVideoUrl,
      }).eq('id', scheduleId);
      
      // Also update camera status to idle
      final schedule = _schedules.firstWhere((s) => s['id'] == scheduleId, orElse: () => {});
      if (schedule.isNotEmpty && schedule['field_id'] != null) {
        await _supabase
            .from('camera_status')
            .update({'status': 'idle'})
            .eq('field_id', schedule['field_id']);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Job marked as completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Refresh data
      _loadSchedules();
      _loadChunksData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to mark job as completed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _cancelSchedule(String scheduleId) async {
    try {
      await _supabase
          .from('camera_recording_schedules')
          .update({'status': 'cancelled'})
          .eq('id', scheduleId);
      
      // Also update camera status to idle
      final schedule = _schedules.firstWhere((s) => s['id'] == scheduleId, orElse: () => {});
      if (schedule.isNotEmpty && schedule['field_id'] != null) {
        await _supabase
            .from('camera_status')
            .update({'status': 'idle'})
            .eq('field_id', schedule['field_id']);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule cancelled'), backgroundColor: Colors.orange),
      );
      _loadSchedules();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _cameras.where((c) => c.healthStatus == HealthStatus.healthy).length;
    final warningCount = _cameras.where((c) => c.healthStatus == HealthStatus.warning).length;
    final offlineCount = _cameras.where((c) => c.healthStatus == HealthStatus.critical || c.healthStatus == HealthStatus.offline).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          '📹 Camera Monitoring',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update),
            onPressed: _showPushScriptUpdateDialog,
            tooltip: 'Push Script Update to Pis',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showSetupInstructions,
            tooltip: 'Setup Instructions',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCameras();
              _loadSchedules();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats bar
                _buildStatsBar(onlineCount, warningCount, offlineCount),
                
                // Camera list
                Expanded(
                  child: _cameras.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadCameras();
                            await _loadSchedules();
                          },
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              // ACTIVE JOBS SECTION (at the very top!)
                              if (_schedules.where((s) => 
                                s['status'] == 'scheduled' || 
                                s['status'] == 'recording' || 
                                s['status'] == 'uploading' || 
                                s['status'] == 'processing' ||
                                s['status'] == 'failed' ||
                                s['status'] == 'replay_requested'
                              ).isNotEmpty) ...[
                                _buildActiveJobsSection(),
                                const SizedBox(height: 24),
                              ],
                              
                              // PIPELINE SCRIPT MANAGEMENT SECTION
                              _buildPipelineManagementSection(),
                              const SizedBox(height: 24),

                              // Cameras section header
                              _buildSectionHeader('📹 Cameras', _cameras.length),
                              const SizedBox(height: 12),
                              
                              // Camera cards
                              ..._cameras.map((camera) => _buildCameraCard(camera)).toList(),
                              
                              // Completed jobs section
                              if (_schedules.where((s) => s['status'] == 'completed').isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _buildCompletedJobsSection(),
                              ],
                              
                              const SizedBox(height: 100), // Bottom padding
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsBar(int online, int warning, int offline) {
    final activeJobs = _schedules.where((s) => 
      s['status'] == 'scheduled' || s['status'] == 'recording' || s['status'] == 'uploading' || s['status'] == 'processing' || s['status'] == 'replay_requested'
    ).length;
    final total = _cameras.length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('$online', 'Online', Colors.green),
          _buildStatColumn('$offline', 'Offline', Colors.red),
          _buildStatColumn('$activeJobs', 'Active Jobs', Colors.orange),
          _buildStatColumn('$total', 'Total', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label, MaterialColor color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Cameras Configured',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure cameras in the Football Fields section',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineManagementSection() {
    final bool piCdnOk = _pipelineScript.isNotEmpty && !_pipelineScript.startsWith('# Pi Pipeline Script') && !_pipelineScript.startsWith('# Error');
    final bool btCdnOk = _ballTrackingScript.isNotEmpty && !_ballTrackingScript.startsWith('# GPU Ball Tracking') && !_ballTrackingScript.startsWith('# Error') && !_ballTrackingScript.startsWith('# ACTIVE') && !_ballTrackingScript.startsWith('# No ball');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.rocket_launch, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pipeline & Script Management',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Active scripts for recording & AI processing',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isPipelineLoading || _isBallTrackingLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  )
                else
                  IconButton(
                    onPressed: () {
                      _loadPipelineConfig();
                      _loadScriptHistory();
                    },
                    icon: const Icon(Icons.sync, size: 18, color: Colors.white70),
                    tooltip: 'Refresh scripts',
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════════════════════════════════
                // GPU PIPELINE BANNER — always-on clarity
                // ═══════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade50, Colors.indigo.shade50],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.memory, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'GPU PIPELINE — ALWAYS ACTIVE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'RUNNING',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'BROADCAST_BALL_TRACKING_V4',
                        style: GoogleFonts.firaCode(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bundled in Modal container — used automatically for ALL scheduled recordings',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.purple.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Feature chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildFeatureChip('Kalman Filter', Icons.linear_scale),
                          _buildFeatureChip('ROI YOLO Detection', Icons.search),
                          _buildFeatureChip('Field Mask', Icons.crop_landscape),
                          _buildFeatureChip('Smooth Camera', Icons.videocam),
                          _buildFeatureChip('9:16 Reels/TikTok', Icons.crop_portrait),
                          _buildFeatureChip('Red Ball Overlay', Icons.circle, color: Colors.red.shade400),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // ═══════════════════════════════════════════
                // TWO SCRIPT CARDS: Pi Pipeline + Ball Tracking
                // ═══════════════════════════════════════════
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pi Pipeline Script
                    Expanded(
                      child: _buildCompactScriptCard(
                        title: 'Pi Pipeline',
                        subtitle: 'Recording & chunking',
                        icon: Icons.developer_board,
                        accentColor: Colors.blue.shade700,
                        bgColor: Colors.blue.shade50,
                        version: _pipelineVersion,
                        lastDeployed: _pipelineLastDeployed,
                        isLoaded: piCdnOk,
                        isLoading: _isPipelineLoading,
                        scriptContent: _pipelineScript,
                        onDeploy: () => _deployNewVersion(type: 'pipeline'),
                        onViewScript: () => setState(() => _expandedScriptType = _expandedScriptType == 'pipeline' ? null : 'pipeline'),
                        isExpanded: _expandedScriptType == 'pipeline',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Ball Tracking Script (references to Supabase registry)
                    Expanded(
                      child: _buildCompactScriptCard(
                        title: 'Ball Track Registry',
                        subtitle: 'Version log & deploy',
                        icon: Icons.sports_soccer,
                        accentColor: Colors.purple.shade700,
                        bgColor: Colors.purple.shade50,
                        version: _ballTrackingVersion,
                        lastDeployed: _ballTrackingLastDeployed,
                        isLoaded: btCdnOk,
                        isLoading: _isBallTrackingLoading,
                        scriptContent: _ballTrackingScript,
                        onDeploy: () => _deployNewVersion(type: 'ball_tracking'),
                        onViewScript: () => setState(() => _expandedScriptType = _expandedScriptType == 'ball_tracking' ? null : 'ball_tracking'),
                        isExpanded: _expandedScriptType == 'ball_tracking',
                      ),
                    ),
                  ],
                ),

                // Expanded script viewer
                if (_expandedScriptType != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e1e2e),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.code, size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 6),
                              Text(
                                _expandedScriptType == 'pipeline' ? 'Pi Pipeline Script' : 'Ball Tracking Script',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Clipboard.setData(ClipboardData(
                                  text: _expandedScriptType == 'pipeline' ? _pipelineScript : _ballTrackingScript
                                )),
                                icon: Icon(Icons.copy, size: 14, color: Colors.grey.shade400),
                                tooltip: 'Copy to clipboard',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: Colors.grey.shade800, height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              _expandedScriptType == 'pipeline' ? _pipelineScript : _ballTrackingScript,
                              style: GoogleFonts.firaCode(
                                fontSize: 11,
                                color: Colors.greenAccent.shade100,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // History sections
                if (_showPipelineHistory && _pipelineHistory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildHistorySection(_pipelineHistory, Colors.blue.shade700, 'Pipeline History'),
                ],
                if (_showBallTrackingHistory && _ballTrackingHistory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildHistorySection(_ballTrackingHistory, Colors.purple.shade700, 'Ball Tracking History'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color ?? Colors.purple.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactScriptCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required String version,
    required DateTime? lastDeployed,
    required bool isLoaded,
    required bool isLoading,
    required String scriptContent,
    required VoidCallback onDeploy,
    required VoidCallback onViewScript,
    required bool isExpanded,
  }) {
    String deployedText = 'Never';
    if (lastDeployed != null) {
      final diff = DateTime.now().difference(lastDeployed);
      if (diff.inDays > 1) {
        deployedText = DateFormat('MMM d').format(lastDeployed);
      } else if (diff.inHours >= 1) {
        deployedText = '${diff.inHours}h ago';
      } else {
        deployedText = '${diff.inMinutes}m ago';
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'v$version',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isLoaded ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 12,
                color: isLoaded ? Colors.green.shade600 : Colors.orange.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isLoaded ? 'Loaded from CDN' : 'CDN expired',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isLoaded ? Colors.green.shade600 : Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.access_time, size: 10, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text(
                deployedText,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onViewScript,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isExpanded ? accentColor.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isExpanded ? accentColor.withOpacity(0.4) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isExpanded ? Icons.code_off : Icons.code, size: 12, color: isExpanded ? accentColor : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          isExpanded ? 'Hide' : 'View',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isExpanded ? accentColor : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: onDeploy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rocket_launch, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Deploy',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(List<Map<String, dynamic>> history, Color accentColor, String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ...history.take(5).map((entry) {
            final version = entry['version']?.toString() ?? '?';
            final pushedAt = entry['pushed_at'] != null
                ? DateFormat('MMM d, HH:mm').format(DateTime.tryParse(entry['pushed_at'])?.toLocal() ?? DateTime.now())
                : '';
            final changelog = entry['changelog']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'v$version',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      changelog.isNotEmpty ? changelog : 'No changelog',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    pushedAt,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }



  /// Parse a named constant from a Python script string
  String? _parseScriptParam(String script, String paramName) {
    final regex = RegExp(r'^' + paramName + r'\s*=\s*([^\s#\n]+)', multiLine: true);
    final match = regex.firstMatch(script);
    return match?.group(1)?.trim();
  }

  /// Build a user-friendly card for a script with parameter chips and history
  Widget _buildScriptCard({
    required String title,
    required String subtitle,
    required String version,
    required DateTime? lastDeployed,
    required String scriptContent,
    required List<Map<String, dynamic>> history,
    required bool showHistory,
    required VoidCallback onToggleHistory,
    required VoidCallback onReset,
    required VoidCallback onDeploy,
    required Color accentColor,
    required Color bgColor,
    required IconData icon,
    required String type,
  }) {
    // Calculate next version string
    String nextVersion;
    if (version == '1.0') {
      nextVersion = '1.1';
    } else {
      double currentVer = double.tryParse(version) ?? 1.0;
      nextVersion = (currentVer + 0.1).toStringAsFixed(1);
    }

    final isExpanded = _expandedScriptType == type;

    // Parse key parameters from script content for display
    final Map<String, String> params = {};
    if (scriptContent.isNotEmpty) {
      if (type == 'ball_tracking') {
        final detSize = _parseScriptParam(scriptContent, 'DETECTION_SIZE');
        final detConf = _parseScriptParam(scriptContent, 'DETECTION_CONF');
        final cropRatio = _parseScriptParam(scriptContent, 'CROP_RATIO');
        final extendFrame = _parseScriptParam(scriptContent, 'EXTEND_FRAME');
        final everyN = _parseScriptParam(scriptContent, 'DETECT_EVERY_N_FRAMES');
        if (detSize != null) params['Detection Size'] = detSize;
        if (detConf != null) params['Min Confidence'] = detConf;
        if (cropRatio != null) params['Crop Ratio'] = cropRatio;
        if (extendFrame != null) params['9:16 Output'] = extendFrame == 'True' ? '✅' : '❌';
        if (everyN != null) params['Every N Frames'] = everyN;
      }
    }

    // Format last deployed
    String deployedText = 'Never deployed';
    if (lastDeployed != null) {
      final diff = DateTime.now().difference(lastDeployed);
      if (diff.inDays > 1) {
        deployedText = DateFormat('MMM d, yyyy').format(lastDeployed);
      } else if (diff.inHours >= 1) {
        deployedText = '${diff.inHours}h ago';
      } else {
        deployedText = '${diff.inMinutes}m ago';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with icon, title, version badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'v$version',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        deployedText,
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // Parameter chips (for ball tracking)
        if (params.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, size: 13, color: accentColor),
                    const SizedBox(width: 5),
                    Text(
                      'Current Parameters',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: params.entries.map((e) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.key,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            e.value,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // ⚠️ CDN Error Banner (appears when script failed to load from CDN)
        if (scriptContent.startsWith('# Error'))
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.link_off, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CDN Link Expired (403)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        'The stored script URL is no longer accessible. Tap "Edit & Deploy" to push a fresh version.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Action row: View Script | History | Deploy
        Row(
          children: [
            // View Code button
            if (scriptContent.isNotEmpty)
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedScriptType = isExpanded ? null : type;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isExpanded ? accentColor.withOpacity(0.08) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isExpanded ? accentColor.withOpacity(0.3) : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpanded ? Icons.code_off : Icons.code,
                        size: 13,
                        color: isExpanded ? accentColor : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isExpanded ? 'Hide Code' : 'View Code',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isExpanded ? accentColor : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // History button
            InkWell(
              onTap: onToggleHistory,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: showHistory ? Colors.amber.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: showHistory ? Colors.amber.shade300 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 13,
                      color: showHistory ? Colors.amber.shade700 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'History',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: showHistory ? Colors.amber.shade700 : Colors.grey.shade600,
                      ),
                    ),
                    if (history.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${history.length}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Deploy button
            ElevatedButton.icon(
              onPressed: onDeploy,
              icon: const Icon(Icons.rocket_launch, size: 14),
              label: Text(
                'DEPLOY v$nextVersion',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),

        // Expanded code view
        if (isExpanded && scriptContent.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Code bar header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.code, size: 13, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        '$title v$version',
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: scriptContent));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Script copied to clipboard'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      scriptContent,
                      style: GoogleFonts.firaCode(
                        fontSize: 10.5,
                        color: const Color(0xFFCDD6F4),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // History timeline
        if (showHistory) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Version History',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No history found',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final ver = entry['version']?.toString() ?? '?';
                      final pushedAtStr = entry['pushed_at'] as String?;
                      DateTime? pushedAt = pushedAtStr != null ? DateTime.tryParse(pushedAtStr)?.toLocal() : null;
                      final scriptUrl = entry['script_url'] as String?;
                      final isLatest = index == 0;

                      String dateLabel = 'Unknown date';
                      if (pushedAt != null) {
                        dateLabel = DateFormat('MMM d, yyyy • HH:mm').format(pushedAt);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            // Timeline dot
                            Column(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: isLatest ? accentColor : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'v$ver',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isLatest ? accentColor : Colors.black87,
                                        ),
                                      ),
                                      if (isLatest) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: accentColor,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'CURRENT',
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // View button
                            if (scriptUrl != null)
                              TextButton.icon(
                                onPressed: () => _showHistoryPreviewDialog(
                                  version: ver,
                                  scriptUrl: scriptUrl,
                                  accentColor: accentColor,
                                ),
                                icon: Icon(Icons.visibility_outlined, size: 14, color: accentColor),
                                label: Text(
                                  'View',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],

        // Reset version link
        if (version != '1.0') ...[
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: onReset,
              child: Text(
                'Reset version counter to 1.0',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Shows a dialog to preview a historical script version
  Future<void> _showHistoryPreviewDialog({
    required String version,
    required String scriptUrl,
    required Color accentColor,
  }) async {
    // Load the script content
    String? content;
    bool isLoading = true;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Kick off the load if needed
          if (isLoading && content == null && error == null) {
            Future<void> fetchScript() async {
              try {
                // Try direct fetch
                final response = await http.get(Uri.parse(scriptUrl)).timeout(const Duration(seconds: 10));
                if (response.statusCode == 200) {
                  if (context.mounted) setDialogState(() { content = response.body; isLoading = false; });
                  return;
                }
                throw Exception('HTTP ${response.statusCode}');
              } catch (e) {
                // If direct fetch fails (likely CORS on Web), try proxy
                try {
                  final proxyUrl = 'https://corsproxy.io/?' + Uri.encodeComponent(scriptUrl);
                  final proxyRes = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 10));
                  if (context.mounted) {
                    setDialogState(() {
                      if (proxyRes.statusCode == 200) {
                        content = proxyRes.body;
                      } else {
                        error = 'Failed to load via Proxy (HTTP ${proxyRes.statusCode})';
                      }
                      isLoading = false;
                    });
                  }
                } catch (e2) {
                  if (context.mounted) setDialogState(() { error = 'Error: $e\nProxy Error: $e2'; isLoading = false; });
                }
              }
            }
            fetchScript();
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Icon(Icons.history, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Version v$version',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                if (!isLoading && content != null)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)),
                      );
                    },
                    tooltip: 'Copy script',
                  ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                  ? Center(child: Text(error!, style: GoogleFonts.inter(color: Colors.red)))
                  : Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          content!,
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: const Color(0xFFCDD6F4),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScriptRow({
    required String title,
    required String version,
    required String scriptContent,
    required VoidCallback onReset,
    required VoidCallback onDeploy,
    required Color color,
    required IconData icon,
    required String type,
  }) {
    // Legacy fallback — not used anymore but kept for safety
    return const SizedBox.shrink();
  }
  

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00BF63),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00BF63).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00BF63),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActiveJobsSection() {
    final activeJobs = _schedules.where((s) => 
      s['status'] == 'scheduled' || 
      s['status'] == 'recording' || 
      s['status'] == 'uploading' || 
      s['status'] == 'processing' ||
      s['status'] == 'failed' ||
      s['status'] == 'replay_requested'
    ).toList();
    if (activeJobs.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header - Red for active
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Active Jobs',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${activeJobs.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Active job cards
        ...activeJobs.map((job) => _buildActiveJobCard(job)).toList(),
      ],
    );
  }
  
  Widget _buildActiveJobCard(Map<String, dynamic> job) {
    final scheduleId = job['id'] as String;
    final status = job['status'] ?? 'scheduled';
    final chunks = _chunksData[scheduleId] ?? [];
    final int totalChunks = (job['total_chunks'] ?? 1) as int;
    final enableBallTracking = job['enable_ball_tracking'] ?? false;
    final chunkDurationMinutes = (job['chunk_duration_minutes'] ?? 10) as int;
    final showFieldMask = (job['show_field_mask'] ?? false) as bool;
    final showRedBall = (job['show_red_ball'] ?? false) as bool;
    
    DateTime? startTime;
    DateTime? endTime;
    try {
      final startStr = job['start_time'] ?? job['start_time_old'];
      final endStr = job['end_time'] ?? job['end_time_old'];
      if (startStr != null) startTime = DateTime.tryParse(startStr.toString())?.toLocal();
      if (endStr != null) endTime = DateTime.tryParse(endStr.toString())?.toLocal();
    } catch (e) {}
    
    final now = DateTime.now();
    
    // Recording progress
    double recordingProgress = 0.0;
    int currentlyRecordingChunk = 0;
    String recordingLabel = '0/$totalChunks';
    if (startTime != null && endTime != null) {
      final totalDuration = endTime.difference(startTime).inSeconds;
      final elapsed = now.difference(startTime).inSeconds;
      if (status == 'recording') {
        if (now.isBefore(startTime)) {
          recordingProgress = 0.0;
        } else if (now.isAfter(endTime)) {
          recordingProgress = 1.0;
          recordingLabel = '$totalChunks/$totalChunks';
        } else {
          recordingProgress = (elapsed / totalDuration).clamp(0.0, 1.0);
          final chunkDurationSeconds = chunkDurationMinutes * 60;
          currentlyRecordingChunk = (elapsed / chunkDurationSeconds).floor() + 1;
          currentlyRecordingChunk = currentlyRecordingChunk.clamp(1, totalChunks);
          final completedChunks = (currentlyRecordingChunk - 1).clamp(0, totalChunks);
          recordingLabel = '$completedChunks/$totalChunks';
        }
      } else {
        recordingProgress = 1.0;
        recordingLabel = '$totalChunks/$totalChunks';
      }
    }
    
    // Upload progress
    double uploadProgress = 0.0;
    int uploadedChunksCount = 0;
    if (chunks.isNotEmpty) {
      double totalUploadProgress = 0;
      for (final chunk in chunks) {
        final progress = (chunk['upload_progress'] ?? 0) as num;
        totalUploadProgress += progress.toDouble();
        if (progress >= 100 || chunk['video_url'] != null) uploadedChunksCount++;
      }
      uploadProgress = totalUploadProgress / (totalChunks * 100);
    }

    // GPU progress
    double gpuProgress = 0.0;
    int gpuCompletedCount = 0;
    int gpuProcessingCount = 0;
    for (final chunk in chunks) {
      final gpuStatus = chunk['gpu_status'];
      if (gpuStatus == 'completed' || chunk['processed_url'] != null) {
        gpuCompletedCount++;
      } else if (gpuStatus == 'processing') {
        gpuProcessingCount++;
      }
    }
    if (totalChunks > 0) {
      gpuProgress = (gpuCompletedCount + gpuProcessingCount * 0.5) / totalChunks;
    }
    
    // Status
    Color statusColor = Colors.blue;
    String statusText = 'SCHEDULED';
    if (status == 'recording') { statusColor = Colors.red; statusText = 'RECORDING'; }
    else if (status == 'uploading') { statusColor = Colors.orange; statusText = 'UPLOADING'; }
    else if (status == 'processing') { statusColor = Colors.purple; statusText = 'GPU'; }
    else if (status == 'failed') { statusColor = Colors.red.shade700; statusText = 'FAILED'; }
    else if (status == 'replay_requested') { statusColor = Colors.teal.shade700; statusText = 'SD REPLAY'; }
    
    String? remainingTime;
    if (status == 'recording' && endTime != null && now.isBefore(endTime)) {
      final remaining = endTime.difference(now);
      remainingTime = remaining.inMinutes > 0
          ? '${remaining.inMinutes}m ${remaining.inSeconds % 60}s'
          : '${remaining.inSeconds}s';
    }
    
    // Script version info
    final scriptVersion = job['pipeline_version']?.toString() ?? job['ball_tracking_version']?.toString() ?? 'V4';
    
    // Compute GPU time from chunks
    String gpuTimeStr = '—';
    int totalGpuSeconds = 0;
    for (final chunk in chunks) {
      final gpuTime = chunk['gpu_processing_time_seconds'] ?? chunk['processing_duration_seconds'];
      if (gpuTime != null) totalGpuSeconds += (gpuTime as num).toInt();
    }
    if (totalGpuSeconds > 0) {
      if (totalGpuSeconds >= 60) {
        gpuTimeStr = '${totalGpuSeconds ~/ 60}m ${totalGpuSeconds % 60}s';
      } else {
        gpuTimeStr = '${totalGpuSeconds}s';
      }
    }

    // Size from chunks
    String sizeStr = '—';
    int totalBytes = 0;
    for (final chunk in chunks) {
      final size = chunk['file_size_bytes'] ?? chunk['size_bytes'];
      if (size != null) totalBytes += (size as num).toInt();
    }
    if (totalBytes > 0) {
      if (totalBytes >= 1024 * 1024 * 1024) {
        sizeStr = '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      } else if (totalBytes >= 1024 * 1024) {
        sizeStr = '${(totalBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
      } else {
        sizeStr = '${(totalBytes / 1024).toStringAsFixed(0)} KB';
      }
    }

    // Output link (first processed chunk URL or final video)
    String? outputUrl = job['final_video_url']?.toString();
    if (outputUrl == null) {
      for (final chunk in chunks) {
        if (chunk['processed_url'] != null) {
          outputUrl = chunk['processed_url'].toString();
          break;
        }
      }
    }

    // Duration
    String durationStr = '—';
    if (startTime != null && endTime != null) {
      final dur = endTime.difference(startTime);
      durationStr = dur.inHours > 0
          ? '${dur.inHours}h ${dur.inMinutes % 60}m'
          : '${dur.inMinutes}m';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── COMPACT HEADER ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Pulsing dot / status dot
                if (status == 'recording')
                  _AnimatedPulsingDot(color: statusColor)
                else
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 9),
                // Time range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (startTime != null && endTime != null)
                        Text(
                          '${DateFormat('MMM d, HH:mm').format(startTime)} → ${DateFormat('HH:mm').format(endTime)}  ($durationStr)',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                        )
                      else
                        Text('Scheduled', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        '${scheduleId.substring(0, 8)}',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                // Remaining time pill
                if (remainingTime != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(remainingTime, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  ),
                  const SizedBox(width: 6),
                ],
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                // Action icons
                if ((status == 'processing' || status == 'uploading') && chunks.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _markJobAsCompleted(scheduleId, chunks),
                    child: Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade500),
                  ),
                ],
                if (_isSchedulePast(job)) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showAddFootageDialog(
                      scheduleId: scheduleId,
                      fieldId: (job['field_id'] ?? '') as String,
                      fieldName: (job['field_id'] ?? scheduleId) as String,
                      enableBallTracking: (job['enable_ball_tracking'] ?? true) as bool,
                      showFieldMask: showFieldMask,
                      showRedBall: showRedBall,
                      totalChunks: (job['total_chunks'] ?? 1) as int,
                    ),
                    child: Icon(Icons.link, size: 18, color: Colors.blue.shade500),
                  ),
                ],
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _cancelSchedule(scheduleId),
                  child: Icon(Icons.close, size: 18, color: Colors.red.shade300),
                ),
              ],
            ),
          ),

          // ── 3 SLIM PROGRESS BARS ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildMiniProgressBar('REC', recordingProgress, Colors.red, status == 'recording'),
                const SizedBox(width: 6),
                _buildMiniProgressBar('UP', uploadProgress, Colors.orange, status == 'uploading'),
                const SizedBox(width: 6),
                _buildMiniProgressBar('GPU', gpuProgress, Colors.purple, status == 'processing'),
              ],
            ),
          ),

          // ── INFO GRID ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Chunks
                _buildInfoChip(Icons.splitscreen, '$totalChunks×${chunkDurationMinutes}m', Colors.blue.shade700),
                // GPU Time
                if (totalGpuSeconds > 0)
                  _buildInfoChip(Icons.memory, 'GPU: $gpuTimeStr', Colors.purple.shade700),
                // Size
                if (totalBytes > 0)
                  _buildInfoChip(Icons.storage, sizeStr, Colors.grey.shade700),
                // Script button
                GestureDetector(
                  onTap: () => _showJobScriptDialog(job),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.code, size: 11, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text('Script', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                      ],
                    ),
                  ),
                ),
                // Output link
                if (outputUrl != null)
                  GestureDetector(
                    onTap: () async {
                      try {
                        // ignore: deprecated_member_use
                        await launchUrl(Uri.parse(outputUrl!), mode: LaunchMode.externalApplication);
                      } catch (e) {
                        // Clipboard fallback
                        await Clipboard.setData(ClipboardData(text: outputUrl!));
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied!')));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline, size: 11, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text('Output', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                        ],
                      ),
                    ),
                  ),
                // Feature flags
                if (enableBallTracking) _buildInfoChip(Icons.sports_soccer, 'Ball Track', Colors.green.shade700),
                if (showFieldMask) _buildInfoChip(Icons.crop_landscape, 'Field Mask', Colors.teal.shade700),
                if (showRedBall) _buildInfoChip(Icons.circle, 'Red Ball', Colors.red.shade600),
              ],
            ),
          ),

          // ── WARNINGS (compact) ──
          if (status == 'failed' && job['error_message'] != null)
            _buildJobWarningBanner(Icons.error_outline, job['error_message'].toString(), Colors.red),
          if (status == 'recording' && endTime != null && now.isAfter(endTime) && chunks.isEmpty)
            _buildJobWarningBanner(Icons.warning_amber_rounded, 'Recording time passed — no chunks yet. Check Pi.', Colors.amber),
          if (chunks.any((c) => c['status'] == 'recording_failed'))
            _buildJobWarningBanner(Icons.broken_image_outlined, '${chunks.where((c) => c['status'] == 'recording_failed').length} chunk(s) failed recording', Colors.orange),
          if ((status == 'processing' || status == 'uploading') && chunks.isNotEmpty &&
              chunks.every((c) => c['gpu_status'] == 'completed' || c['processed_url'] != null || c['status'] == 'recording_failed'))
            _buildJobWarningBanner(Icons.hourglass_disabled, 'Job appears stuck — use ✓ to force complete', Colors.purple),

          // ── CHUNK STATUS ──
          _buildChunkStatusCardsWithTime(
            chunks: chunks,
            totalChunks: totalChunks,
            jobStatus: status,
            startTime: startTime,
            endTime: endTime,
            chunkDurationMinutes: chunkDurationMinutes,
          ),

          // ── LOGS ──
          _buildJobLogsSection(scheduleId, job['field_id'] as String?),
        ],
      ),
    );
  }

  Widget _buildMiniProgressBar(String label, double progress, Color color, bool isActive) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: isActive ? color : Colors.grey.shade400)),
              const Spacer(),
              Text('${(progress * 100).round()}%', style: GoogleFonts.inter(fontSize: 9, color: isActive ? color : Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.grey.shade100,
              color: isActive ? color : color.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildJobWarningBanner(IconData icon, String message, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(message, style: GoogleFonts.inter(fontSize: 11, color: color.withOpacity(0.9))),
          ),
        ],
      ),
    );
  }

  void _showJobScriptDialog(Map<String, dynamic> job) {
    final scriptContent = _ballTrackingScript.isNotEmpty ? _ballTrackingScript : _pipelineScript;
    final scriptVersion = job['ball_tracking_version']?.toString() ?? _ballTrackingVersion;
    final pipelineVersion = job['pipeline_version']?.toString() ?? _pipelineVersion;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 700,
          height: 540,
          decoration: BoxDecoration(
            color: const Color(0xFF1e1e2e),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Dialog header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF2a2a3e),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code, color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Script Used for This Job',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            'Pi Pipeline v$pipelineVersion · GPU Ball Tracking v$scriptVersion · BROADCAST_BALL_TRACKING_V4',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Clipboard.setData(ClipboardData(text: scriptContent)),
                      icon: const Icon(Icons.copy, size: 16, color: Colors.white54),
                      tooltip: 'Copy',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              // Active GPU pipeline banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Colors.purple.withOpacity(0.2),
                child: Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Active GPU Pipeline: BROADCAST_BALL_TRACKING_V4 (bundled in Modal container)',
                      style: GoogleFonts.firaCode(fontSize: 11, color: Colors.greenAccent.shade100),
                    ),
                  ],
                ),
              ),
              // Script content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    scriptContent.isNotEmpty ? scriptContent : '# Script content not cached.\n# The GPU pipeline BROADCAST_BALL_TRACKING_V4 is bundled\n# in the Modal container and runs automatically.',
                    style: GoogleFonts.firaCode(fontSize: 11, color: Colors.greenAccent.shade100, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
  Widget _buildJobLogsSection(String scheduleId, String? fieldId, {bool autoRefresh = true}) {
    // Use a StatefulBuilder for auto-refresh
    return _JobLogsSection(
      key: ValueKey('logs_$scheduleId'),
      scheduleId: scheduleId,
      fieldId: fieldId,
      supabase: _supabase,
      autoRefresh: autoRefresh,
    );
  }

  Widget _buildCompletedJobsSection() {
    final completedJobs = _schedules.where((s) => s['status'] == 'completed').toList();
    if (completedJobs.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text('✅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Completed',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${completedJobs.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              // Copy Debug Info button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _copyLast10JobsDebugInfo(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Copy Last 10 Jobs Debug',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Completed job cards — show all loaded
        ...completedJobs.map((job) => _buildCompletedJobCard(job)).toList(),
        
        // Load More footer
        if (_hasMoreJobs || _isLoadingMoreJobs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isLoadingMoreJobs
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : OutlinedButton.icon(
                      onPressed: _loadMoreJobs,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load older jobs'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(color: Colors.green.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
  
  /// Generates debug info for last 10 jobs and copies to clipboard
  void _copyLast10JobsDebugInfo() {
    final allJobs = _schedules.take(10).toList();
    if (allJobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No jobs to copy')),
      );
      return;
    }
    
    final buffer = StringBuffer();
    buffer.writeln('=' * 80);
    buffer.writeln('DEBUG INFO - Last ${allJobs.length} Jobs');
    buffer.writeln('Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 80);
    buffer.writeln();
    
    for (int i = 0; i < allJobs.length; i++) {
      final job = allJobs[i];
      final scheduleId = job['id'] as String? ?? 'unknown';
      final chunks = _chunksData[scheduleId] ?? [];
      
      buffer.writeln('-' * 60);
      buffer.writeln('JOB ${i + 1}: ${scheduleId}');
      buffer.writeln('-' * 60);
      
      // Job basic info
      buffer.writeln('Status: ${job['status']}');
      buffer.writeln('Field ID: ${job['field_id']}');
      buffer.writeln('Created At: ${job['created_at']}');
      buffer.writeln('Started At: ${job['started_at']}');
      buffer.writeln('Recording Ended At: ${job['recording_ended_at']}');
      buffer.writeln('Completed At: ${job['completed_at']}');
      buffer.writeln('Start Time: ${job['start_time']}');
      buffer.writeln('End Time: ${job['end_time']}');
      buffer.writeln('Total Chunks (expected): ${job['total_chunks']}');
      buffer.writeln('Enable Ball Tracking: ${job['enable_ball_tracking']}');
      buffer.writeln('Final Video URL: ${job['final_video_url']}');
      buffer.writeln('Merged Video URL: ${job['merged_video_url']}');
      buffer.writeln('Error Message: ${job['error_message']}');
      buffer.writeln('GPU Error: ${job['gpu_error']}');
      buffer.writeln('Merge Time (s): ${job['merge_time_seconds']}');
      buffer.writeln('Merge Cost (USD): ${job['merge_cost_usd']}');
      buffer.writeln('Total Processing Time (s): ${job['total_processing_time_seconds']}');
      buffer.writeln('Total GPU Cost (USD): ${job['total_gpu_cost_usd']}');
      buffer.writeln();
      
      // Chunks info
      buffer.writeln('CHUNKS DATA (${chunks.length} found in memory):');
      if (chunks.isEmpty) {
        buffer.writeln('  [No chunks data loaded]');
      } else {
        // Sort chunks by chunk number
        final sortedChunks = List<Map<String, dynamic>>.from(chunks);
        sortedChunks.sort((a, b) => (a['chunk_number'] ?? 0).compareTo(b['chunk_number'] ?? 0));
        
        for (final chunk in sortedChunks) {
          buffer.writeln('  --- Chunk ${chunk['chunk_number']} ---');
          buffer.writeln('    ID: ${chunk['id']}');
          buffer.writeln('    Status: ${chunk['status']}');
          buffer.writeln('    Upload Progress: ${chunk['upload_progress']}%');
          buffer.writeln('    Video URL: ${chunk['video_url'] != null ? "SET (${(chunk['video_url'] as String?)?.length ?? 0} chars)" : "NULL"}');
          buffer.writeln('    GPU Status: ${chunk['gpu_status']}');
          buffer.writeln('    GPU Job ID: ${chunk['gpu_job_id']}');
          buffer.writeln('    Processed URL: ${chunk['processed_url'] != null ? "SET (${(chunk['processed_url'] as String?)?.length ?? 0} chars)" : "NULL"}');
          buffer.writeln('    File Size MB: ${chunk['file_size_mb']}');
          buffer.writeln('    Output Size MB: ${chunk['output_size_mb']}');
          buffer.writeln('    Processing Time (s): ${chunk['processing_time_seconds']}');
          buffer.writeln('    GPU Cost USD: ${chunk['gpu_cost_usd']}');
          buffer.writeln('    Error Message: ${chunk['error_message']}');
          buffer.writeln('    GPU Error: ${chunk['gpu_error']}');
          buffer.writeln('    Created At: ${chunk['created_at']}');
          buffer.writeln('    Updated At: ${chunk['updated_at']}');
          buffer.writeln('    Upload Started At: ${chunk['upload_started_at']}');
          buffer.writeln('    Upload Completed At: ${chunk['upload_completed_at']}');
          buffer.writeln('    GPU Started At: ${chunk['gpu_started_at']}');
          buffer.writeln('    GPU Completed At: ${chunk['gpu_completed_at']}');
        }
      }
      
      // Summary stats
      final uploadedCount = chunks.where((c) => 
        (c['upload_progress'] ?? 0) >= 100 || c['video_url'] != null
      ).length;
      final gpuCompletedCount = chunks.where((c) => 
        c['gpu_status'] == 'completed' || c['processed_url'] != null
      ).length;
      final gpuPendingCount = chunks.where((c) => 
        c['gpu_status'] == 'pending' || c['gpu_status'] == null
      ).length;
      final gpuProcessingCount = chunks.where((c) => 
        c['gpu_status'] == 'processing'
      ).length;
      final gpuErrorCount = chunks.where((c) => 
        c['gpu_status'] == 'error' || c['error_message'] != null || c['gpu_error'] != null
      ).length;
      
      buffer.writeln();
      buffer.writeln('SUMMARY:');
      buffer.writeln('  Expected Chunks: ${job['total_chunks']}');
      buffer.writeln('  Chunks in DB: ${chunks.length}');
      buffer.writeln('  Uploaded: $uploadedCount');
      buffer.writeln('  GPU Pending: $gpuPendingCount');
      buffer.writeln('  GPU Processing: $gpuProcessingCount');
      buffer.writeln('  GPU Completed: $gpuCompletedCount');
      buffer.writeln('  GPU Errors: $gpuErrorCount');
      buffer.writeln();
    }
    
    buffer.writeln('=' * 80);
    buffer.writeln('END OF DEBUG INFO');
    buffer.writeln('=' * 80);
    
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Copied debug info for ${allJobs.length} jobs to clipboard!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  Widget _buildCompletedJobCard(Map<String, dynamic> job) {
    final scheduleId = job['id'] as String;
    final chunks = _chunksData[scheduleId] ?? [];
    final totalChunks = (job['total_chunks'] ?? chunks.length) as int;
    final enableBallTracking = (job['enable_ball_tracking'] ?? false) as bool;
    final showFieldMask = (job['show_field_mask'] ?? false) as bool;
    final showRedBall = (job['show_red_ball'] ?? false) as bool;

    DateTime? startTime, endTime, completedAt;
    try {
      final startStr = job['start_time'] ?? job['start_time_old'];
      final endStr = job['end_time'] ?? job['end_time_old'];
      if (startStr != null) startTime = DateTime.tryParse(startStr.toString())?.toLocal();
      if (endStr != null) endTime = DateTime.tryParse(endStr.toString())?.toLocal();
      if (job['completed_at'] != null) completedAt = DateTime.tryParse(job['completed_at'].toString())?.toLocal();
    } catch (e) {}

    // Duration
    String durationStr = '—';
    if (startTime != null && endTime != null) {
      final dur = endTime.difference(startTime);
      durationStr = dur.inHours > 0 ? '${dur.inHours}h ${dur.inMinutes % 60}m' : '${dur.inMinutes}m';
    }

    // "Ready X min after recording ended"
    String readyDelayStr = '';
    if (endTime != null && completedAt != null && completedAt.isAfter(endTime)) {
      final delay = completedAt.difference(endTime);
      readyDelayStr = 'ready ${delay.inMinutes}m after end';
    }

    // Stats
    double totalSizeMb = (job['merged_size_mb'] as num?)?.toDouble() ?? 0;
    double processingTime = (job['total_processing_time_seconds'] as num?)?.toDouble() ?? 0;
    double gpuCost = (job['total_gpu_cost_usd'] as num?)?.toDouble() ?? 0;
    double mergeCost = (job['merge_cost_usd'] as num?)?.toDouble() ?? 0;
    for (var c in chunks) {
      if (totalSizeMb == 0) totalSizeMb += (c['output_size_mb'] ?? c['file_size_mb'] ?? 0) as double;
      if (processingTime == 0) processingTime += (c['processing_time_seconds'] ?? 0) as double;
      if (gpuCost == 0) gpuCost += (c['gpu_cost_usd'] ?? 0) as double;
    }
    final totalCost = gpuCost + mergeCost;

    // Output URL
    String? finalVideoUrl = job['final_video_url']?.toString() ?? job['merged_video_url']?.toString();
    if (finalVideoUrl == null) {
      final processed = chunks.where((c) => c['processed_url'] != null).toList()
        ..sort((a, b) => (a['chunk_number'] ?? 0).compareTo(b['chunk_number'] ?? 0));
      if (processed.isNotEmpty) finalVideoUrl = processed.first['processed_url'].toString();
    }

    // GPU time string
    String gpuTimeStr = '';
    if (processingTime > 0) {
      final s = processingTime.toInt();
      gpuTimeStr = s >= 60 ? '${s ~/ 60}m ${s % 60}s' : '${s}s';
    }

    final timeStr = startTime != null && endTime != null
        ? '${DateFormat('MMM d, HH:mm').format(startTime)} → ${DateFormat('HH:mm').format(endTime)}'
        : 'Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Green checkmark dot
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                // Time + duration
                Expanded(
                  child: Text(
                    '$timeStr  ($durationStr)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
                // COMPLETED badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade200)),
                  child: Text('✓ DONE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                ),
                // Script button
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showJobScriptDialog(job),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.code, size: 10, color: Colors.blue.shade700),
                      const SizedBox(width: 3),
                      Text('Script', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                    ]),
                  ),
                ),
                // Output button
                if (finalVideoUrl != null) ...[
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () async {
                      try {
                        // ignore: deprecated_member_use
                        await launchUrl(Uri.parse(finalVideoUrl!), mode: LaunchMode.externalApplication);
                      } catch (e) {
                        await Clipboard.setData(ClipboardData(text: finalVideoUrl!));
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied!')));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade300)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.play_circle_outline, size: 10, color: Colors.green.shade700),
                        const SizedBox(width: 3),
                        Text('Output', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Info chips row
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (gpuTimeStr.isNotEmpty)
                  _buildInfoChip(Icons.memory, 'GPU $gpuTimeStr', Colors.purple.shade700),
                if (totalSizeMb > 0)
                  _buildInfoChip(Icons.storage, '${totalSizeMb.toStringAsFixed(0)} MB', Colors.grey.shade700),
                if (totalCost > 0)
                  _buildInfoChip(Icons.attach_money, '\$${totalCost.toStringAsFixed(3)}', Colors.teal.shade700),
                if (readyDelayStr.isNotEmpty)
                  _buildInfoChip(Icons.timer_outlined, readyDelayStr, Colors.orange.shade700),
                _buildInfoChip(Icons.splitscreen, '$totalChunks chunks', Colors.blue.shade700),
                if (enableBallTracking) _buildInfoChip(Icons.sports_soccer, 'Ball Track', Colors.green.shade700),
                if (showFieldMask) _buildInfoChip(Icons.crop_landscape, 'Field Mask', Colors.teal.shade700),
                if (showRedBall) _buildInfoChip(Icons.circle, 'Red Ball', Colors.red.shade600),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildChunkPipelineCard(List<Map<String, dynamic>> chunks, int totalChunks, int uploadedChunks, int gpuCompletedChunks) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('📦', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
                    'Chunk Pipeline',
            style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalChunks chunks',
                  style: GoogleFonts.inter(
                    fontSize: 12,
              fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Recording progress (red)
          _buildProgressRow(
            icon: Icons.fiber_manual_record,
            iconColor: Colors.red,
            label: 'Recording',
            current: totalChunks,
            total: totalChunks,
            progressColor: Colors.red,
          ),
          const SizedBox(height: 12),
          
          // Uploading progress (orange)
          _buildProgressRow(
            icon: Icons.cloud_upload,
            iconColor: Colors.orange,
            label: 'Uploading',
            current: uploadedChunks,
            total: totalChunks,
            progressColor: Colors.orange,
          ),
          const SizedBox(height: 12),
          
          // GPU Processing progress (blue)
          _buildProgressRow(
            icon: Icons.memory,
            iconColor: Colors.blue,
            label: 'GPU Processing',
            current: gpuCompletedChunks,
            total: totalChunks,
            progressColor: Colors.blue,
          ),
          const SizedBox(height: 16),
          
          // Chunk status grid
          Text(
            'Chunk Status:',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(totalChunks, (index) {
              final chunkNum = index + 1;
              final chunk = chunks.firstWhere(
                (c) => c['chunk_number'] == chunkNum,
                orElse: () => {},
              );
              
              Color bgColor = Colors.grey.shade300;
              Color textColor = Colors.grey.shade600;
              
              if (chunk.isNotEmpty) {
                final gpuStatus = chunk['gpu_status'];
                final uploadProgress = chunk['upload_progress'] ?? 0;
                
                if (gpuStatus == 'completed' || chunk['processed_url'] != null) {
                  bgColor = Colors.grey.shade400;
                  textColor = Colors.white;
                } else if (gpuStatus == 'processing') {
                  bgColor = Colors.blue.shade300;
                  textColor = Colors.white;
                } else if (uploadProgress >= 100 || chunk['video_url'] != null) {
                  bgColor = Colors.orange.shade300;
                  textColor = Colors.white;
                }
              }
              
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$chunkNum',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              );
            }),
          ),
          
          // Final video ready indicator
          if (gpuCompletedChunks == totalChunks && totalChunks > 0) ...[
            const SizedBox(height: 12),
            Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
                color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text('🎬', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'Final video ready!',
                    style: GoogleFonts.inter(
              fontSize: 13,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
            ),
          ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int current,
    required int total,
    required Color progressColor,
  }) {
    final percentage = total > 0 ? (current / total * 100).round() : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Text(
              '$current/$total',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: progressColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$percentage%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? current / total : 0,
            backgroundColor: progressColor.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
  
  Widget _buildProgressRowWithPercentage({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int current,
    required int total,
    required Color progressColor,
    double? customProgress,
  }) {
    final progress = customProgress ?? (total > 0 ? current / total : 0.0);
    final percentage = (progress * 100).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(
              label,
            style: GoogleFonts.inter(
              fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Text(
              '$current/$total',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: progressColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$percentage%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
            ),
          ),
        ],
      ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: progressColor.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
  
  // Time-based progress row with better visuals
  Widget _buildTimeBasedProgressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double progress,
    required Color progressColor,
    required String subtitle,
    bool isActive = false,
  }) {
    final percentage = (progress * 100).round().clamp(0, 100);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Icon with pulse effect if active
            if (isActive)
              _AnimatedPulsingIcon(icon: icon, color: iconColor)
            else
              Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? progressColor : progressColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$percentage%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : progressColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            // Background
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: progressColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Progress
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: progressColor.withOpacity(0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ] : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Chunk status cards with TIME-BASED logic
  Widget _buildChunkStatusCardsWithTime({
    required List<Map<String, dynamic>> chunks,
    required int totalChunks,
    required String jobStatus,
    DateTime? startTime,
    DateTime? endTime,
    int chunkDurationMinutes = 10,
  }) {
    final now = DateTime.now();
    
    // Calculate which chunk is currently recording based on time
    int currentlyRecordingChunk = 0;
    if (jobStatus == 'recording' && startTime != null) {
      final elapsedSeconds = now.difference(startTime).inSeconds;
      final chunkDurationSeconds = chunkDurationMinutes * 60;
      currentlyRecordingChunk = (elapsedSeconds / chunkDurationSeconds).floor() + 1;
      currentlyRecordingChunk = currentlyRecordingChunk.clamp(1, totalChunks);
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
          Text(
                'Chunks Status',
            style: GoogleFonts.inter(
                  fontSize: 12,
              fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(totalChunks, (index) {
              final chunkNum = index + 1;
              final chunk = chunks.firstWhere(
                (c) => c['chunk_number'] == chunkNum,
                orElse: () => <String, dynamic>{},
              );
              
              return _buildSingleChunkCardWithTime(
                chunkNum: chunkNum,
                chunk: chunk,
                jobStatus: jobStatus,
                isCurrentlyRecording: chunkNum == currentlyRecordingChunk && jobStatus == 'recording',
                startTime: startTime,
                chunkDurationMinutes: chunkDurationMinutes,
              );
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSingleChunkCardWithTime({
    required int chunkNum,
    required Map<String, dynamic> chunk,
    required String jobStatus,
    required bool isCurrentlyRecording,
    DateTime? startTime,
    int chunkDurationMinutes = 10,
  }) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    String statusText;
    IconData statusIcon;
    double? progressPercent;
    
    if (chunk.isEmpty) {
      // No record in DB yet
      if (isCurrentlyRecording) {
        // This chunk is currently being recorded (based on time)
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade400;
        textColor = Colors.red.shade700;
        statusText = 'REC';
        statusIcon = Icons.fiber_manual_record;
        
        // Calculate progress within this chunk
        if (startTime != null) {
          final now = DateTime.now();
          final chunkStartTime = startTime.add(Duration(minutes: (chunkNum - 1) * chunkDurationMinutes));
          final elapsedInChunk = now.difference(chunkStartTime).inSeconds;
          final chunkDurationSeconds = chunkDurationMinutes * 60;
          progressPercent = ((elapsedInChunk / chunkDurationSeconds) * 100).clamp(0, 100);
        }
      } else if (jobStatus == 'recording') {
        // Future chunk - waiting
        bgColor = Colors.grey.shade100;
        borderColor = Colors.grey.shade300;
        textColor = Colors.grey.shade500;
        statusText = 'WAIT';
        statusIcon = Icons.schedule;
      } else {
        // Not recording - just pending
        bgColor = Colors.grey.shade100;
        borderColor = Colors.grey.shade300;
        textColor = Colors.grey.shade500;
        statusText = 'PEND';
        statusIcon = Icons.pending_outlined;
      }
    } else {
      // Chunk exists in DB - check BOTH status and gpu_status
      final status = chunk['status'] as String?;
      final gpuStatus = chunk['gpu_status'] as String?;
      final gpuProgress = (chunk['gpu_progress'] ?? 0) as num;
      final uploadProgress = (chunk['upload_progress'] ?? 0) as num;
      final hasVideoUrl = chunk['video_url'] != null;
      final hasProcessedUrl = chunk['processed_url'] != null;
      
      if (hasProcessedUrl || gpuStatus == 'completed' || status == 'completed') {
        // ✅ GPU complete
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade400;
        textColor = Colors.green.shade700;
        statusText = 'DONE';
        statusIcon = Icons.check_circle;
        progressPercent = 100;
      } else if (gpuStatus == 'processing' || status == 'gpu_processing') {
        // 🔵 GPU processing - show actual GPU progress
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade400;
        textColor = Colors.blue.shade700;
        statusText = gpuProgress > 0 ? '${gpuProgress.toInt()}%' : 'GPU';
        statusIcon = Icons.memory;
        progressPercent = gpuProgress > 0 ? gpuProgress.toDouble() : 50;
      } else if (gpuStatus == 'queued' || gpuStatus == 'pending' || status == 'gpu_queued') {
        // 🔵 In GPU queue (after upload complete)
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        textColor = Colors.blue.shade600;
        statusText = 'QUEUE';
        statusIcon = Icons.hourglass_empty;
      } else if (hasVideoUrl || uploadProgress >= 100 || status == 'uploaded') {
        // ☁️ Upload complete, waiting for GPU
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade400;
        textColor = Colors.orange.shade700;
        statusText = '100%';
        statusIcon = Icons.cloud_done;
        progressPercent = 100;
      } else if (status == 'uploading' || uploadProgress > 0) {
        // 🟡 Currently UPLOADING - show progress in AMBER
        bgColor = Colors.amber.shade50;
        borderColor = Colors.amber.shade400;
        textColor = Colors.amber.shade800;
        statusText = uploadProgress > 0 ? '${uploadProgress.toInt()}%' : '0%';
        statusIcon = Icons.cloud_upload;
        progressPercent = uploadProgress.toDouble();
      } else if (status == 'recording') {
        // 🔴 Still recording
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade400;
        textColor = Colors.red.shade700;
        statusText = 'REC';
        statusIcon = Icons.fiber_manual_record;
      } else {
        // 🟠 Recorded, waiting in upload queue (status='recorded' or any other)
        // If chunk exists but no upload started, it's waiting in queue
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        textColor = Colors.orange.shade700;
        statusText = 'WAIT';
        statusIcon = Icons.schedule;
      }
    }
    
    return GestureDetector(
      onTap: chunk.isNotEmpty ? () => _showChunkDetailsDialog(context, chunk, chunkNum) : null,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isCurrentlyRecording ? 2 : 1.5),
          boxShadow: isCurrentlyRecording ? [
            BoxShadow(
              color: borderColor.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chunk number
            Text(
              'Chunk $chunkNum',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            // Status icon (animated if recording)
            if (isCurrentlyRecording)
              _AnimatedPulsingIcon(icon: statusIcon, color: textColor, size: 18)
            else
              Icon(statusIcon, size: 18, color: textColor),
            const SizedBox(height: 2),
            // Status text
            Text(
              statusText,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            // Progress bar if applicable
            if (progressPercent != null && progressPercent < 100) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  backgroundColor: borderColor.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(borderColor),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  void _showChunkDetailsDialog(BuildContext context, Map<String, dynamic> chunk, int chunkNum) {
    // Parse timestamps
    DateTime? recordingFinished;
    DateTime? uploadStarted;
    DateTime? uploadFinished;
    DateTime? gpuStarted;
    DateTime? gpuFinished;
    
    try {
      if (chunk['recording_finished_at'] != null) {
        recordingFinished = DateTime.tryParse(chunk['recording_finished_at'].toString())?.toLocal();
      }
      if (chunk['upload_started_at'] != null) {
        uploadStarted = DateTime.tryParse(chunk['upload_started_at'].toString())?.toLocal();
      }
      if (chunk['upload_finished_at'] != null) {
        uploadFinished = DateTime.tryParse(chunk['upload_finished_at'].toString())?.toLocal();
      }
      if (chunk['gpu_started_at'] != null) {
        gpuStarted = DateTime.tryParse(chunk['gpu_started_at'].toString())?.toLocal();
      }
      if (chunk['gpu_finished_at'] != null) {
        gpuFinished = DateTime.tryParse(chunk['gpu_finished_at'].toString())?.toLocal();
      }
    } catch (e) {}
    
    final uploadDuration = chunk['upload_duration_seconds'] as num?;
    final gpuDuration = chunk['processing_time_seconds'] as num?;
    final gpuCost = chunk['gpu_cost_usd'] as num?;
    final fileSizeMb = chunk['file_size_mb'] as num?;
    final status = chunk['status'] as String? ?? 'unknown';
    final gpuStatus = chunk['gpu_status'] as String? ?? 'pending';
    
    String formatTime(DateTime? dt) {
      if (dt == null) return '—';
      return DateFormat('HH:mm:ss').format(dt);
    }
    
    String formatDuration(num? seconds) {
      if (seconds == null) return '—';
      final mins = (seconds / 60).floor();
      final secs = (seconds % 60).round();
      return mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.info_outline, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Text('Chunk $chunkNum Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: gpuStatus == 'completed' ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
                    Icon(
                      gpuStatus == 'completed' ? Icons.check_circle : Icons.pending,
                      size: 18,
                      color: gpuStatus == 'completed' ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: gpuStatus == 'completed' ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 16),
              
              // Timeline
              _buildTimelineRow('🎬', 'Recording Finished', formatTime(recordingFinished), Colors.red),
              _buildTimelineRow('📤', 'Upload Started', formatTime(uploadStarted), Colors.orange),
              _buildTimelineRow('☁️', 'Upload Finished', formatTime(uploadFinished), Colors.orange),
              _buildTimelineRow('🧠', 'GPU Started', formatTime(gpuStarted), Colors.blue),
              _buildTimelineRow('✅', 'GPU Finished', formatTime(gpuFinished), Colors.green),
              
              const Divider(height: 24),
              
              // Stats
              Row(
                children: [
                  Expanded(child: _buildChunkStatCard('Upload Time', formatDuration(uploadDuration), Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildChunkStatCard('GPU Time', formatDuration(gpuDuration), Colors.blue)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildChunkStatCard('File Size', fileSizeMb != null ? '${fileSizeMb.toStringAsFixed(1)} MB' : '—', Colors.purple)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildChunkStatCard('GPU Cost', gpuCost != null ? '\$${gpuCost.toStringAsFixed(4)}' : '—', Colors.teal)),
                ],
              ),
              
              // Video URLs
              if (chunk['video_url'] != null) ...[
                const SizedBox(height: 16),
                _buildUrlRow('Raw Video', chunk['video_url'], context),
              ],
              if (chunk['processed_url'] != null) ...[
                const SizedBox(height: 8),
                _buildUrlRow('Processed', chunk['processed_url'], context),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimelineRow(String emoji, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChunkStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: color.withOpacity(0.8))),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
  
  Widget _buildUrlRow(String label, String url, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$label: ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              url.split('/').last,
              style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.blue),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 16),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label URL copied!'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChunkStatusCards(List<Map<String, dynamic>> chunks, int totalChunks, String jobStatus) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
          Text(
                'Chunks Status',
            style: GoogleFonts.inter(
                  fontSize: 12,
              fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(totalChunks, (index) {
              final chunkNum = index + 1;
              final chunk = chunks.firstWhere(
                (c) => c['chunk_number'] == chunkNum,
                orElse: () => <String, dynamic>{},
              );
              
              return _buildSingleChunkCard(chunkNum, chunk, jobStatus);
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSingleChunkCard(int chunkNum, Map<String, dynamic> chunk, String jobStatus) {
    // Determine chunk state and colors
    Color bgColor;
    Color borderColor;
    Color textColor;
    String statusText;
    IconData statusIcon;
    int? progressPercent;
    
    if (chunk.isEmpty) {
      // Not yet created - waiting or currently recording
      if (jobStatus == 'recording') {
        // First non-existent chunk during recording = currently recording
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        textColor = Colors.red.shade700;
        statusText = 'REC';
        statusIcon = Icons.fiber_manual_record;
      } else {
        bgColor = Colors.grey.shade100;
        borderColor = Colors.grey.shade300;
        textColor = Colors.grey.shade500;
        statusText = 'WAIT';
        statusIcon = Icons.schedule;
      }
    } else {
      final status = chunk['status'] as String?;
      final gpuStatus = chunk['gpu_status'] as String?;
      final gpuProgress = (chunk['gpu_progress'] ?? 0) as num;
      final uploadProgress = (chunk['upload_progress'] ?? 0) as num;
      final hasVideoUrl = chunk['video_url'] != null;
      final hasProcessedUrl = chunk['processed_url'] != null;
      
      if (hasProcessedUrl || gpuStatus == 'completed' || status == 'completed') {
        // ✅ GPU processing complete
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade400;
        textColor = Colors.green.shade700;
        statusText = 'DONE';
        statusIcon = Icons.check_circle;
        progressPercent = 100;
      } else if (gpuStatus == 'processing' || status == 'gpu_processing') {
        // 🔵 GPU processing in progress - show actual progress
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade400;
        textColor = Colors.blue.shade700;
        statusText = gpuProgress > 0 ? '${gpuProgress.toInt()}%' : 'GPU';
        statusIcon = Icons.memory;
        progressPercent = gpuProgress > 0 ? gpuProgress.toInt() : 50;
      } else if (gpuStatus == 'queued' || gpuStatus == 'pending' || status == 'gpu_queued') {
        // 🔵 In GPU queue
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        textColor = Colors.blue.shade600;
        statusText = 'QUEUE';
        statusIcon = Icons.hourglass_empty;
      } else if (hasVideoUrl || uploadProgress >= 100 || status == 'uploaded') {
        // ☁️ Upload complete, waiting for GPU
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade400;
        textColor = Colors.orange.shade700;
        statusText = '100%';
        statusIcon = Icons.cloud_done;
        progressPercent = 100;
      } else if (status == 'uploading' || uploadProgress > 0) {
        // 🟡 Currently UPLOADING - AMBER with progress
        bgColor = Colors.amber.shade50;
        borderColor = Colors.amber.shade400;
        textColor = Colors.amber.shade800;
        statusText = uploadProgress > 0 ? '${uploadProgress.toInt()}%' : '0%';
        statusIcon = Icons.cloud_upload;
        progressPercent = uploadProgress.toInt();
      } else if (status == 'recording') {
        // 🔴 Still recording
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade400;
        textColor = Colors.red.shade700;
        statusText = 'REC';
        statusIcon = Icons.fiber_manual_record;
      } else {
        // 🟠 Recorded, waiting in upload queue (any other status)
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        textColor = Colors.orange.shade700;
        statusText = 'WAIT';
        statusIcon = Icons.schedule;
      }
    }
    
    return GestureDetector(
      onTap: chunk.isNotEmpty ? () => _showChunkDetailsDialog(context, chunk, chunkNum) : null,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chunk number
            Text(
              'Chunk $chunkNum',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            // Status icon
            Icon(statusIcon, size: 18, color: textColor),
            const SizedBox(height: 2),
            // Status text/percentage
            Text(
              statusText,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            // Progress bar if applicable
            if (progressPercent != null && progressPercent < 100) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  backgroundColor: borderColor.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(borderColor),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFinalVideoCard(double sizeMb, double processingTime, double totalCost, int chunks, String? videoUrl, List<String> processedUrls, [double mergeTime = 0, bool isMergedVideo = false, double mergeCost = 0]) {
    final minutes = (processingTime / 60).floor();
    final seconds = processingTime % 60;
    final mergeMinutes = (mergeTime / 60).floor();
    final mergeSeconds = mergeTime % 60;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.movie, color: Colors.green.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(isMergedVideo ? '🎬' : '📹', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        isMergedVideo ? 'Merged Video Ready!' : 'Final Video Ready!',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade800,
                        ),
                      ),
                      if (isMergedVideo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'MERGED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Text('📦', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        isMergedVideo 
                            ? 'Size: ${sizeMb.toStringAsFixed(0)} MB • $chunks chunks merged'
                            : 'Size: ${sizeMb.toStringAsFixed(0)} MB • $chunks processed chunks',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Stats row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('${minutes}m ${seconds.toStringAsFixed(0)}s', 'GPU Time', Icons.memory),
                _buildStatItem('\$${totalCost.toStringAsFixed(3)}', 'Total Cost', Icons.attach_money),
                if (isMergedVideo && mergeTime > 0)
                  _buildStatItem('${mergeMinutes}m ${mergeSeconds.toStringAsFixed(0)}s', 'Merge', Icons.merge_type)
                else
                  _buildStatItem('$chunks', 'Chunks', Icons.grid_view),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Processed chunks URLs (expandable)
          if (processedUrls.isNotEmpty) ...[
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '📹 ${processedUrls.length} Processed Video URLs',
                style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.green.shade700,
                ),
              ),
              children: [
                ...processedUrls.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final url = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      url.split('/').last,
                      style: GoogleFonts.robotoMono(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.copy, size: 16, color: Colors.green),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Chunk $index URL copied!'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Action buttons
          Row(
            children: [
              // Download button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: videoUrl != null ? () async {
                    try {
                      // Open URL - this will trigger download in browser or open in external app
                      final url = Uri.parse(videoUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Opening video for download...'), backgroundColor: Colors.green),
                        );
                      } else {
                        throw Exception('Could not launch URL');
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } : null,
                  icon: Icon(Icons.download, color: Colors.white),
                  label: Text(
                    'Download Video',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Copy URL button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: videoUrl != null ? () {
                    Clipboard.setData(ClipboardData(text: videoUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('URL copied!'), backgroundColor: Colors.green),
                    );
                  } : null,
                  icon: Icon(Icons.copy, color: Colors.green.shade700),
                  label: Text(
                    'Copy URL',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Copy ALL URLs button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: IconButton(
                  icon: Icon(Icons.copy_all, color: Colors.green.shade700),
                  tooltip: 'Copy all URLs',
                  onPressed: processedUrls.isNotEmpty ? () {
                    final allUrls = processedUrls.join('\n');
                    Clipboard.setData(ClipboardData(text: allUrls));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('All ${processedUrls.length} URLs copied!'), backgroundColor: Colors.green),
                    );
                  } : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
          Text(
              label,
            style: GoogleFonts.inter(
                fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      ],
    );
  }

  Widget _buildCameraCard(CameraStatus camera) {
    final healthColor = _getHealthColor(camera.healthStatus);
    final isOnline = camera.healthStatus == HealthStatus.healthy || camera.healthStatus == HealthStatus.warning;
    
    // Get schedules for this camera (only active ones, not completed)
    final cameraSchedules = _schedules
        .where((s) => s['field_id'] == camera.fieldId && s['status'] != 'completed')
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: healthColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Green checkmark icon (like screenshot)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isOnline ? Icons.check_circle : Icons.error,
                    color: isOnline ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Field info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.fieldName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        camera.location,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // ONLINE/OFFLINE badge (like screenshot)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          boxShadow: isOnline ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                          ),
                          ] : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // IPs row
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        '📹 Camera IP',
                        camera.cameraIp ?? 'Not configured',
                        copyable: camera.cameraIp != null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailItem(
                        '🥧 Raspberry Pi',
                        camera.piIp ?? 'Not configured',
                        copyable: camera.piIp != null,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Last heartbeat
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        '💓 Last Heartbeat',
                        camera.lastHeartbeat != null
                            ? _formatTimeSince(camera.lastHeartbeat!)
                            : 'Never',
                        icon: Icons.favorite,
                        iconColor: camera.healthStatus == HealthStatus.healthy 
                            ? Colors.green 
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailItem(
                        '🎬 Status',
                        camera.status.toUpperCase(),
                        highlight: camera.status == 'recording',
                      ),
                    ),
                  ],
                ),
                
                // Recording Schedules Section
                if (cameraSchedules.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      try {
                        return _buildSchedulesSection(cameraSchedules);
                      } catch (e) {
                        print('Schedule section error: $e');
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text('⚠️ Schedule display error', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${cameraSchedules.length} jobs exist but can\'t be displayed'),
                              TextButton(
                                onPressed: _loadSchedules,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
                
                // Recording info (if available)
                if (camera.details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  // PIPELINE STATUS
                  if (camera.status == 'recording' || camera.status == 'processing' || camera.status == 'uploading')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PipelineStatusWidget(
                        currentStep: camera.details['step'] ?? 'rec',
                        message: camera.details['message'] ?? 'Processing...',
                        progress: camera.details['progress'],
                      ),
                    ),

                  Row(
                    children: [
                      if (camera.details['active'] != null)
                        _buildMiniStat('Active', camera.details['active'].toString(), Colors.blue),
                      if (camera.details['scheduled'] != null) ...[
                        const SizedBox(width: 12),
                        _buildMiniStat('Scheduled', camera.details['scheduled'].toString(), Colors.purple),
                      ],
                      if (camera.details['camera_ok'] != null) ...[
                        const SizedBox(width: 12),
                        _buildMiniStat(
                          'Camera',
                          camera.details['camera_ok'] == true ? 'OK' : 'Error',
                          camera.details['camera_ok'] == true ? Colors.green : Colors.red,
                        ),
                      ],
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                
                // Action Buttons Row (Stats, Logs, Record - like screenshot)
                Row(
                  children: [
                    // Stats button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showStatsDialog(camera),
                        icon: Icon(Icons.bar_chart, size: 18, color: Colors.black87),
                        label: Text('Stats', style: GoogleFonts.inter(color: Colors.black87)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Logs button
                    Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogsDialog(camera),
                        icon: Icon(Icons.receipt_long, size: 18, color: Colors.black87),
                        label: Text('Logs', style: GoogleFonts.inter(color: Colors.black87)),
                    style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                    const SizedBox(width: 8),
                    
                    // Record button (red like screenshot)
                    Expanded(
                  child: ElevatedButton.icon(
                        onPressed: () => _showScheduleRecordingDialog(camera),
                        icon: Icon(Icons.videocam, size: 18, color: Colors.white),
                        label: Text('Record', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade500,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Edit Field Mask button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _requestScreenshotAndEditMask(camera),
                    icon: Icon(Icons.crop_free, size: 18, color: Colors.blue.shade700),
                    label: Text(
                      'Edit Field Mask',
                      style: GoogleFonts.inter(color: Colors.blue.shade700),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSchedulesSection(List<Map<String, dynamic>> schedules) {
    // Group schedules by status
    final activeSchedules = schedules.where((s) => 
      s['status'] == 'recording' || s['status'] == 'scheduled' || 
      s['status'] == 'uploading' || s['status'] == 'processing'
    ).toList();
    
    final completedSchedules = schedules.where((s) => 
      s['status'] == 'completed'
    ).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Jobs
        if (activeSchedules.isNotEmpty) ...[
          _buildScheduleGroupHeader('🔴 Active', activeSchedules.length, Colors.red),
          const SizedBox(height: 8),
          ...activeSchedules.take(3).map((schedule) => _buildScheduleItem(schedule)).toList(),
          const SizedBox(height: 16),
        ],
        
        // Completed Jobs
        if (completedSchedules.isNotEmpty) ...[
          _buildScheduleGroupHeader('✅ Completed', completedSchedules.length, Colors.green),
          const SizedBox(height: 8),
          ...completedSchedules.take(5).map((schedule) => _buildScheduleItem(schedule)).toList(),
        ],
        
        // Show message if no schedules
        if (schedules.isEmpty)
          Center(
            child: Text(
              'No recording jobs yet',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
      ],
    );
  }
  
  Widget _buildScheduleGroupHeader(String title, int count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
      ),
    );
  }
  
  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final status = schedule['status'] ?? 'unknown';
    
    // Safe date parsing (with fallback to old columns)
    DateTime? startTime;
    DateTime? endTime;
    try {
      final startStr = schedule['start_time'] ?? schedule['start_time_old'];
      final endStr = schedule['end_time'] ?? schedule['end_time_old'];
      if (startStr != null) {
        startTime = DateTime.tryParse(startStr.toString())?.toLocal();
      }
      if (endStr != null) {
        endTime = DateTime.tryParse(endStr.toString())?.toLocal();
      }
    } catch (e) {
      print('Date parse error: $e');
    }
    final totalChunks = schedule['total_chunks'] ?? 1;
    final enableBallTracking = schedule['enable_ball_tracking'] ?? false;
    final scheduleId = schedule['id'] as String;
    
    // Get chunks for this schedule
    final chunks = _chunksData[scheduleId] ?? [];
    
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'recording':
        statusColor = Colors.red;
        statusIcon = Icons.fiber_manual_record;
        break;
      case 'processing':
      case 'uploading':
        statusColor = Colors.orange;
        statusIcon = Icons.cloud_upload;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case 'scheduled':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  startTime != null && endTime != null
                      ? '${DateFormat('MMM d, HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}'
                      : 'Unknown time',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Cancel button for active jobs
              if (status == 'recording' || status == 'scheduled' || status == 'processing' || status == 'uploading') ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showCancelConfirmation(scheduleId),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.close, size: 16, color: Colors.red.shade700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMiniTag('$totalChunks chunks', Colors.blue),
              const SizedBox(width: 8),
              if (enableBallTracking)
                _buildMiniTag('🎯 Ball Tracking', Colors.purple),
              if (schedule['booking_id'] != null) ...[
                const SizedBox(width: 8),
                _buildMiniTag('📅 Booking', Colors.teal),
              ],
            ],
          ),
          // Chunk Progress
          if (chunks.isNotEmpty || totalChunks > 0) ...[
            const SizedBox(height: 8),
            _buildChunkProgressWidget(scheduleId, totalChunks, chunks),
          ],
        ],
      ),
    );
  }
  
  Widget _buildChunkProgressWidget(String scheduleId, int totalChunks, List<Map<String, dynamic>> chunks) {
    // Calculate overall progress
    int uploadedChunks = 0;
    int gpuCompletedChunks = 0;
    int totalUploadProgress = 0;
    int totalGpuProgress = 0;
    
    for (final chunk in chunks) {
      final uploadProgress = chunk['upload_progress'] ?? 0;
      final gpuStatus = chunk['gpu_status'];
      final gpuProgress = chunk['gpu_progress'] ?? 0;
      final videoUrl = chunk['video_url'];
      
      totalUploadProgress += uploadProgress as int;
      totalGpuProgress += gpuProgress as int;
      
      if (uploadProgress >= 100 || videoUrl != null) uploadedChunks++;
      if (gpuStatus == 'completed') gpuCompletedChunks++;
    }
    
    final avgUpload = chunks.isNotEmpty ? (totalUploadProgress / chunks.length).round() : 0;
    final avgGpu = chunks.isNotEmpty ? (totalGpuProgress / chunks.length).round() : 0;
    
    // Calculate overall percentages
    final uploadPct = totalChunks > 0 ? (uploadedChunks / totalChunks * 100).round() : 0;
    final processingPct = totalChunks > 0 ? (totalGpuProgress / totalChunks).round() : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bars
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload: $uploadedChunks/$totalChunks ($avgUpload%)',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: uploadPct / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(Colors.blue.shade400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GPU: $gpuCompletedChunks/$totalChunks ($avgGpu%)',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: processingPct / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(Colors.purple.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Chunk grid
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(totalChunks, (index) {
            final chunkNum = index + 1;
            final chunk = chunks.firstWhere(
              (c) => c['chunk_number'] == chunkNum,
              orElse: () => {},
            );
            
            if (chunk.isEmpty) {
              // Pending chunk
              return _buildChunkIndicator(chunkNum, 'pending', 0, 0);
            }
            
            final uploadProgress = chunk['upload_progress'] ?? 0;
            final gpuStatus = chunk['gpu_status'] ?? 'pending';
            final gpuProgress = chunk['gpu_progress'] ?? 0;
            final videoUrl = chunk['video_url'];
            
            String status = 'pending';
            if (videoUrl != null || uploadProgress >= 100) {
              status = gpuStatus == 'completed' ? 'gpu_done' : 
                       gpuStatus == 'processing' ? 'gpu_processing' : 'uploaded';
            } else if (uploadProgress > 0) {
              status = 'uploading';
            }
            
            return _buildChunkIndicator(chunkNum, status, uploadProgress, gpuProgress);
          }),
        ),
      ],
    );
  }
  
  Widget _buildChunkIndicator(int chunkNum, String status, int uploadProgress, int gpuProgress) {
    Color bgColor;
    Color borderColor;
    Widget? overlay;
    
    switch (status) {
      case 'gpu_done':
        bgColor = Colors.green.shade100;
        borderColor = Colors.green;
        overlay = const Icon(Icons.check, size: 10, color: Colors.green);
        break;
      case 'gpu_processing':
        bgColor = Colors.purple.shade100;
        borderColor = Colors.purple;
        overlay = Text('$gpuProgress%', style: GoogleFonts.inter(fontSize: 8, color: Colors.purple, fontWeight: FontWeight.bold));
        break;
      case 'uploaded':
        bgColor = Colors.blue.shade100;
        borderColor = Colors.blue;
        overlay = const Icon(Icons.cloud_done, size: 10, color: Colors.blue);
        break;
      case 'uploading':
        bgColor = Colors.orange.shade100;
        borderColor = Colors.orange;
        overlay = Text('$uploadProgress%', style: GoogleFonts.inter(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold));
        break;
      default:
        bgColor = Colors.grey.shade100;
        borderColor = Colors.grey.shade300;
    }
    
    return Tooltip(
      message: 'Chunk $chunkNum: $status (Upload: $uploadProgress%, GPU: $gpuProgress%)',
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Center(
          child: overlay ?? Text(
            '$chunkNum',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
  
  void _showCancelConfirmation(String scheduleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Recording?'),
        content: const Text('Are you sure you want to cancel this recording job? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelSchedule(scheduleId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMiniTag(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: color.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 4 * value,
                spreadRadius: 1 * value,
              ),
            ],
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildDetailItem(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    bool copyable = false,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor ?? Colors.grey),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                  color: highlight ? Colors.green.shade700 : Colors.black87,
                ),
              ),
            ),
            if (copyable)
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied: $value'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(Icons.copy, size: 14, color: Colors.grey.shade400),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: color.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return Colors.green;
      case HealthStatus.warning:
        return Colors.orange;
      case HealthStatus.critical:
        return Colors.red;
      case HealthStatus.offline:
        return Colors.grey;
    }
  }

  IconData _getHealthIcon(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return Icons.check_circle;
      case HealthStatus.warning:
        return Icons.warning;
      case HealthStatus.critical:
        return Icons.error;
      case HealthStatus.offline:
        return Icons.cloud_off;
    }
  }

  String _getHealthLabel(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return 'ONLINE';
      case HealthStatus.warning:
        return 'WARNING';
      case HealthStatus.critical:
        return 'CRITICAL';
      case HealthStatus.offline:
        return 'OFFLINE';
    }
  }

  String _formatTimeSince(DateTime time) {
    final diff = DateTime.now().difference(time);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(time);
    }
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

// Data models
enum HealthStatus { healthy, warning, critical, offline }

class CameraStatus {
  final String fieldId;
  final String fieldName;
  final String location;
  final String? cameraIp;
  final String? piIp;
  final String status;
  final DateTime? lastHeartbeat;
  final Map<String, dynamic> details;

  CameraStatus({
    required this.fieldId,
    required this.fieldName,
    required this.location,
    this.cameraIp,
    this.piIp,
    required this.status,
    this.lastHeartbeat,
    this.details = const {},
  });

  HealthStatus get healthStatus {
    if (lastHeartbeat == null) {
      return HealthStatus.offline;
    }
    
    final diff = DateTime.now().difference(lastHeartbeat!);
    
    if (diff.inMinutes <= 2) {
      return HealthStatus.healthy;
    } else if (diff.inMinutes <= 5) {
      return HealthStatus.warning;
    } else {
      return HealthStatus.critical;
    }
  }
}

// =====================================================
// ANIMATED PULSING DOT WIDGET
// =====================================================
class _AnimatedPulsingDot extends StatefulWidget {
  final Color color;
  
  const _AnimatedPulsingDot({required this.color});
  
  @override
  State<_AnimatedPulsingDot> createState() => _AnimatedPulsingDotState();
}

class _AnimatedPulsingDotState extends State<_AnimatedPulsingDot> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================
// ANIMATED PULSING ICON WIDGET
// =====================================================
class _AnimatedPulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  
  const _AnimatedPulsingIcon({
    required this.icon,
    required this.color,
    this.size = 16,
  });
  
  @override
  State<_AnimatedPulsingIcon> createState() => _AnimatedPulsingIconState();
}

class _AnimatedPulsingIconState extends State<_AnimatedPulsingIcon> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        );
      },
    );
  }
}

// =====================================================
// JOB LOGS SECTION WIDGET
// =====================================================
class _JobLogsSection extends StatefulWidget {
  final String scheduleId;
  final String? fieldId;
  final SupabaseClient supabase;
  final bool autoRefresh;  // Whether to auto-refresh (false for completed jobs)

  const _JobLogsSection({
    Key? key,
    required this.scheduleId,
    required this.fieldId,
    required this.supabase,
    this.autoRefresh = true,  // Default to true for active jobs
  }) : super(key: key);

  @override
  State<_JobLogsSection> createState() => _JobLogsSectionState();
}

class _JobLogsSectionState extends State<_JobLogsSection> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    // Auto-refresh every 5 seconds (only for active jobs)
    if (widget.autoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _loadLogs();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    if (widget.fieldId == null) return;
    
    try {
      final data = await widget.supabase
          .from('camera_logs')
          .select('*')
          .eq('field_id', widget.fieldId!)
          .order('created_at', ascending: false)
          .limit(100);
      
      final allLogs = List<Map<String, dynamic>>.from(data);
      
      // Filter logs for THIS specific job
      // Check both: schedule_id column AND message text
      final schedulePrefix = widget.scheduleId.substring(0, 8);
      final filteredLogs = allLogs.where((log) {
        final message = log['message']?.toString() ?? '';
        final logScheduleId = log['schedule_id']?.toString() ?? '';
        final source = log['source']?.toString() ?? '';
        
        // Match if:
        // 1. schedule_id column matches (for GPU logs)
        // 2. OR message contains the schedule prefix (for Pi logs)
        return logScheduleId.startsWith(schedulePrefix) ||
               logScheduleId == widget.scheduleId ||
               message.contains('[$schedulePrefix]') || 
               message.contains(schedulePrefix) ||
               (source == 'modal_gpu' && logScheduleId == widget.scheduleId);
      }).take(50).toList();
      
      if (mounted) {
        setState(() {
          _logs = filteredLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Row(
          children: [
            Icon(Icons.terminal, size: 18, color: Colors.green.shade400),
            const SizedBox(width: 8),
            Text(
              'Live Logs',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _logs.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_logs.length}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green.shade400,
                ),
              ),
            ],
          ],
        ),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: _logs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _isLoading ? 'Loading logs...' : 'No logs yet for this job',
                      style: GoogleFonts.robotoMono(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final level = log['level'] ?? 'INFO';
                      final message = log['message'] ?? '';
                      final source = log['source'] ?? 'pi';
                      final time = log['created_at'] != null
                          ? DateTime.tryParse(log['created_at'])?.toLocal()
                          : null;
                      
                      Color levelColor = Colors.green;
                      if (level == 'WARNING') levelColor = Colors.orange;
                      if (level == 'ERROR') levelColor = Colors.red;
                      
                      // GPU logs get blue color
                      final isGpu = source == 'modal_gpu' || message.contains('[GPU]');
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Source icon (Pi or GPU)
                            Icon(
                              isGpu ? Icons.memory : Icons.developer_board,
                              size: 10,
                              color: isGpu ? Colors.blue.shade300 : Colors.green.shade300,
                            ),
                            const SizedBox(width: 4),
                            if (time != null)
                              Text(
                                '[${DateFormat('HH:mm:ss').format(time)}] ',
                                style: GoogleFonts.robotoMono(
                                  color: Colors.grey.shade500,
                                  fontSize: 10,
                                ),
                              ),
                            Text(
                              '[$level] ',
                              style: GoogleFonts.robotoMono(
                                color: levelColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                message,
                                style: GoogleFonts.robotoMono(
                                  color: isGpu ? Colors.blue.shade200 : Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _loadLogs,
                  icon: Icon(Icons.refresh, size: 14, color: Colors.green.shade400),
                  label: Text(
                    'Refresh',
                    style: GoogleFonts.inter(color: Colors.green.shade400, fontSize: 11),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final allLogs = _logs.map((l) => '[${l['level']}] ${l['message']}').join('\n');
                    await Clipboard.setData(ClipboardData(text: allLogs));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logs copied!'), duration: Duration(seconds: 1)),
                    );
                  },
                  icon: Icon(Icons.copy, size: 14, color: Colors.grey.shade400),
                  label: Text(
                    'Copy',
                    style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// PIPELINE STATUS WIDGET
// =====================================================
class _PipelineStatusWidget extends StatelessWidget {
  final String currentStep;
  final String message;
  final int? progress;

  const _PipelineStatusWidget({
    Key? key,
    required this.currentStep,
    required this.message,
    this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPulseIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              if (progress != null)
                Text(
                  '$progress%',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStepDot('recording', 'Recording'),
              _buildConnector('stitching'),
              _buildStepDot('stitching', 'Stitching'),
              _buildConnector('uploading'),
              _buildStepDot('uploading', 'Uploading'),
              _buildConnector('ai_trigger'),
              _buildStepDot('ai_trigger', 'AI Process'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPulseIcon() {
    if (currentStep == 'error') return const Icon(Icons.error, color: Colors.red);
    if (currentStep == 'completed') return const Icon(Icons.check_circle, color: Colors.green);
    
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade700),
    );
  }

  Widget _buildStepDot(String stepId, String label) {
    bool isActive = currentStep == stepId;
    bool isCompleted = _isStepCompleted(stepId);
    
    Color color = Colors.grey.shade300;
    if (isActive) color = Colors.blue;
    if (isCompleted) color = Colors.green;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isActive || isCompleted ? Colors.black87 : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(String nextStepId) {
    bool isCompleted = _isStepCompleted(nextStepId) || currentStep == nextStepId;
    return Container(
      width: 20,
      height: 2,
      color: isCompleted ? Colors.green : Colors.grey.shade300,
      margin: const EdgeInsets.only(bottom: 14),
    );
  }

  bool _isStepCompleted(String stepId) {
    const steps = ['recording', 'stitching', 'uploading', 'ai_trigger', 'completed'];
    final normalizedCurrent = currentStep == 'rec' ? 'recording' : currentStep;
    
    int currentIndex = steps.indexOf(normalizedCurrent);
    int stepIndex = steps.indexOf(stepId);
    if (currentIndex == -1) return false;
    return currentIndex > stepIndex;
  }
}

// =====================================================
// SCHEDULE RECORDING DIALOG
// =====================================================
class _ScheduleRecordingDialog extends StatefulWidget {
  final CameraStatus camera;
  final void Function({
    required String scheduleId,
    required String fieldId,
    required String fieldName,
    required bool enableBallTracking,
    required bool showFieldMask,
    required int totalChunks,
  })? onPastDateScheduleCreated;

  final bool initialEnableBallTracking;
  final bool initialShowFieldMask;
  final bool initialShowRedBall;
  final String pipelineVersion;
  final String ballTrackingVersion;

  const _ScheduleRecordingDialog({
    Key? key,
    required this.camera,
    this.onPastDateScheduleCreated,
    this.initialEnableBallTracking = true,
    this.initialShowFieldMask = true,
    this.initialShowRedBall = false,
    this.pipelineVersion = '',
    this.ballTrackingVersion = '',
  }) : super(key: key);

  @override
  State<_ScheduleRecordingDialog> createState() => _ScheduleRecordingDialogState();
}

class _ScheduleRecordingDialogState extends State<_ScheduleRecordingDialog> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  late bool _enableBallTracking;
  late bool _showFieldMask;
  late bool _showRedBall;
  bool _hasCustomFieldMask = false;  // Whether this field has a custom mask
  
  // Text controllers for time input
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _useSdStorage = false;  // When past date: use footage from camera/SD (Pi looks for files)
  
  @override
  void initState() {
    super.initState();
    // Default: start in 1 minute, end in 6 minutes (today)
    final now = DateTime.now();
    final start = now.add(const Duration(minutes: 1));
    final end = now.add(const Duration(minutes: 6));
    _startTimeController.text = DateFormat('HH:mm').format(start);
    _endTimeController.text = DateFormat('HH:mm').format(end);
    _enableBallTracking = widget.initialEnableBallTracking;
    _showFieldMask = widget.initialShowFieldMask;
    _showRedBall = widget.initialShowRedBall;
    _checkForCustomFieldMask();
  }
  
  Future<void> _checkForCustomFieldMask() async {
    try {
      final response = await _supabase
          .from('field_masks')
          .select('id')
          .eq('field_id', widget.camera.fieldId)
          .maybeSingle();
      
      if (mounted && response != null) {
        setState(() => _hasCustomFieldMask = true);
      }
    } catch (e) {
      // Field masks table might not exist yet, that's OK
      print('Field mask check: $e');
    }
  }
  
  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }
  
  /// Parse time string (HH:mm) using _selectedDate for the date part.
  DateTime? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
    } catch (e) {
      return null;
    }
  }
  
  bool get _isPastDate => _selectedDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

  Future<void> _createSchedule() async {
    // Validate times
    final startTime = _parseTime(_startTimeController.text);
    final endTime = _parseTime(_endTimeController.text);
    
    if (startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid start time. Use format HH:MM (e.g., 14:30)'), backgroundColor: Colors.red),
      );
      return;
    }
    if (endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid end time. Use format HH:MM (e.g., 15:00)'), backgroundColor: Colors.red),
      );
      return;
    }
    if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('End time must be after start time'), backgroundColor: Colors.red),
      );
      return;
    }
    
    final durationMinutes = endTime.difference(startTime).inMinutes;
    final isPast = startTime.isBefore(DateTime.now());
    final useSd = isPast && _useSdStorage;

    setState(() => _isLoading = true);

    try {
      final insertData = {
        'field_id': widget.camera.fieldId,
        'scheduled_date': DateFormat('yyyy-MM-dd').format(startTime),
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'status': useSd ? 'replay_requested' : (isPast ? 'scheduled' : 'scheduled'),
        'enable_ball_tracking': _enableBallTracking,
        'show_field_mask': _showFieldMask,
        'show_red_ball': _showRedBall,
        'total_chunks': (durationMinutes / 10).ceil().clamp(1, 100),
        'chunk_duration_minutes': 10,
      };
      final res = await _supabase.from('camera_recording_schedules').insert(insertData).select('id').single();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(useSd
                ? 'Replay requested. Pi will look for footage on SD/camera storage and run the pipeline.'
                : isPast
                    ? 'Schedule created. Add footage URLs to run through the pipeline.'
                    : 'Recording scheduled! ${_startTimeController.text} - ${_endTimeController.text} ($durationMinutes min)'),
            backgroundColor: Colors.green,
          ),
        );
        if (isPast && !useSd && res != null) {
          final scheduleId = res['id'] as String?;
          if (scheduleId != null && widget.onPastDateScheduleCreated != null) {
            widget.onPastDateScheduleCreated!(
              scheduleId: scheduleId,
              fieldId: widget.camera.fieldId,
              fieldName: widget.camera.fieldName,
              enableBallTracking: _enableBallTracking,
              showFieldMask: _showFieldMask,
              totalChunks: (durationMinutes / 10).ceil().clamp(1, 100),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Show copyable error dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: SelectableText(
              e.toString(),
              style: TextStyle(fontSize: 12),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: e.toString()));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error copied to clipboard')),
                  );
                },
                child: Text('Copy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.videocam, color: Colors.green.shade700),
          ),
          const SizedBox(width: 12),
          const Text('Schedule Recording'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Field: ${widget.camera.fieldName}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            
            // Date picker (for scheduling or former recording e.g. "10 Feb 7–9")
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) setState(() => _selectedDate = picked);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text('Tap to change', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            if (_isPastDate) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Past date: no live recording. Add footage URLs below, or use SD/camera storage.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text('Use footage from camera/SD storage', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
                subtitle: Text(
                  'Pi will look for files in SD_FOOTAGE_BASE_DIR for this date & time',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                ),
                value: _useSdStorage,
                onChanged: (v) => setState(() => _useSdStorage = v),
                activeColor: Colors.green,
              ),
            ],
            const SizedBox(height: 20),
            
            // Start and End time text fields
            Row(
              children: [
                // Start time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Time:', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _startTimeController,
                        decoration: InputDecoration(
                          hintText: 'HH:MM',
                          prefixIcon: Icon(Icons.play_arrow, color: Colors.green),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        keyboardType: TextInputType.datetime,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // End time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End Time:', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _endTimeController,
                        decoration: InputDecoration(
                          hintText: 'HH:MM',
                          prefixIcon: Icon(Icons.stop, color: Colors.red),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        keyboardType: TextInputType.datetime,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Duration preview
            Builder(
              builder: (context) {
                final start = _parseTime(_startTimeController.text);
                final end = _parseTime(_endTimeController.text);
                if (start != null && end != null && end.isAfter(start)) {
                  final duration = end.difference(start).inMinutes;
                  final chunks = (duration / 10).ceil();
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Duration: $duration minutes ($chunks chunks)',
                          style: GoogleFonts.inter(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            const SizedBox(height: 20),
            
            // Ball tracking toggle
            SwitchListTile(
              title: Text('🎯 Enable Ball Tracking', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              subtitle: Text('GPU processing for ball tracking overlay', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              value: _enableBallTracking,
              onChanged: (v) => setState(() => _enableBallTracking = v),
              activeColor: Colors.green,
            ),
            
            if (_enableBallTracking) ...[
              SwitchListTile(
                title: Text('📐 Show Field Mask', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
                subtitle: Text('Draw green field boundaries overlay', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                value: _showFieldMask,
                onChanged: (v) => setState(() => _showFieldMask = v),
                activeColor: Colors.blue,
              ),
              SwitchListTile(
                title: Text('🔴 Show Red Ball', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13)),
                subtitle: Text('Draw red dot on detected ball', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                value: _showRedBall,
                onChanged: (v) => setState(() => _showRedBall = v),
                activeColor: Colors.red,
              ),
            ],
            
            // Show current script versions when ball tracking enabled
            if (_enableBallTracking) ...[
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Active Scripts for this Recording',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
                            child: Row(
                              children: [
                                Icon(Icons.developer_board, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Expanded(child: Text('Pipeline v${widget.pipelineVersion}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.purple.shade200)),
                            child: Row(
                              children: [
                                Icon(Icons.sports_soccer, size: 14, color: Colors.purple.shade700),
                                const SizedBox(width: 4),
                                Expanded(child: Text('Tracking v${widget.ballTrackingVersion}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.shade800), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Edit Field Mask button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Navigate to field mask editor
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FieldMaskEditorScreen(
                          fieldId: widget.camera.fieldId,
                          fieldName: widget.camera.fieldName,
                          cameraFieldId: widget.camera.fieldId,
                        ),
                      ),
                    );
                    
                    // Refresh custom mask status if mask was saved
                    if (result == true) {
                      _checkForCustomFieldMask();
                    }
                  },
                  icon: Icon(
                    _hasCustomFieldMask ? Icons.edit : Icons.add_box_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _hasCustomFieldMask ? 'Edit Field Mask' : 'Create Field Mask',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _hasCustomFieldMask ? Colors.blue : Colors.orange,
                    side: BorderSide(
                      color: _hasCustomFieldMask ? Colors.blue : Colors.orange,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              
              // Custom mask indicator
              if (_hasCustomFieldMask)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Custom field mask configured',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createSchedule,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create Schedule', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
  
}

// =====================================================
// LOGS DIALOG
// =====================================================
class _CameraLogsDialog extends StatefulWidget {
  final CameraStatus camera;

  const _CameraLogsDialog({Key? key, required this.camera}) : super(key: key);

  @override
  State<_CameraLogsDialog> createState() => _CameraLogsDialogState();
}

class _CameraLogsDialogState extends State<_CameraLogsDialog> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _subscribeToLogs();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final response = await _supabase
          .from('camera_logs')
          .select()
          .eq('field_id', widget.camera.fieldId)
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading logs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToLogs() {
    _subscription?.cancel();
    _subscription = _supabase
        .from('camera_logs')
        .stream(primaryKey: ['id'])
        .eq('field_id', widget.camera.fieldId)
        .order('created_at', ascending: false)
        .limit(100)
        .listen(
          (data) {
            if (mounted) {
              setState(() {
                _logs = data;
              });
            }
          },
          onError: (e) {
            print('⚠️ Logs stream error: $e');
            // Retry connection after delay
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                _subscribeToLogs();
              }
            });
          },
          cancelOnError: false,
        );
  }
  
  Future<void> _exportLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Camera Logs: ${widget.camera.fieldName} ===');
    buffer.writeln('Exported: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('');
    
    for (final log in _logs.reversed) {
      final time = DateTime.parse(log['created_at']).toLocal();
      final level = log['level'] ?? 'INFO';
      final message = log['message'] ?? '';
      buffer.writeln('[${DateFormat('HH:mm:ss').format(time)}] [$level] $message');
    }
    
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.terminal, color: Colors.black87),
          const SizedBox(width: 12),
          const Text('Camera Logs'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_all),
            onPressed: _exportLogs,
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 600,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs found.',
                      style: GoogleFonts.robotoMono(color: Colors.grey),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                      reverse: true,
                    itemBuilder: (context, index) {
                      final log = _logs[_logs.length - 1 - index];
                      final level = log['level'] ?? 'INFO';
                      final message = log['message'] ?? '';
                      final time = DateTime.parse(log['created_at']).toLocal();
                      
                      Color color = Colors.green;
                      if (level == 'WARNING') color = Colors.orange;
                      if (level == 'ERROR') color = Colors.red;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: RichText(
                          text: TextSpan(
                              style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.white70),
                            children: [
                              TextSpan(
                                text: '[${DateFormat('HH:mm:ss').format(time)}] ',
                                  style: TextStyle(color: Colors.grey.shade500),
                              ),
                              TextSpan(
                                text: '[$level] ',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: message),
                            ],
                          ),
                        ),
                      );
                    },
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SetupInstructionsDialog extends StatelessWidget {
  const _SetupInstructionsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.build, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          const Text('Raspberry Pi Setup'),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: ListView(
          children: [
            _buildStep('1. Prepare SD Card', [
              'Download Raspberry Pi Imager',
              'Choose OS: Raspberry Pi OS (64-bit)',
              'Click Gear Icon ⚙️ to configure settings:',
              '• Hostname: playmaker-pi',
              '• Username: pi',
              '• Password: mancity99',
              '• Enable SSH (Password auth)',
              '• Set Timezone: Africa/Cairo',
              'Flash the SD card',
            ]),
            _buildStep('2. Connect Hardware', [
              'Insert SD card into Raspberry Pi',
              'Connect Ethernet cable to Router',
              'Connect Power',
              'Wait 3-4 minutes for first boot',
            ]),
            _buildStep('3. Find IP & Connect', [
              'Find Pi IP in router or use `arp -a`',
              'Open terminal on your computer',
              'Run: `ssh pi@<PI_IP_ADDRESS>`',
              'Password: `mancity99`',
            ]),
            _buildStep('4. Install Dependencies', [
              'Run: `sudo apt update && sudo apt upgrade -y`',
              'Run: `sudo apt install -y python3-pip ffmpeg`',
              'Run: `pip3 install supabase python-dotenv requests --break-system-packages`',
            ]),
            _buildStep('5. Install Script', [
              'Create directory: `mkdir -p ~/scripts`',
              'Create script: `nano ~/scripts/field_camera.py`',
              'Paste the script from the Field "Camera" tab',
              'Save: Ctrl+X, Y, Enter',
              'Create .env: `nano ~/scripts/.env`',
              'Paste the .env content from the Field "Camera" tab',
              'Save: Ctrl+X, Y, Enter',
            ]),
            _buildStep('6. Setup Auto-Run (Systemd)', [
              'Create service: `sudo nano /etc/systemd/system/camera.service`',
              'Paste service content (see below)',
              'Run: `sudo systemctl enable camera.service`',
              'Run: `sudo systemctl start camera.service`',
            ]),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                '''[Unit]
Description=Playmaker Camera Service
After=network.target

[Service]
User=pi
WorkingDirectory=/home/pi/scripts
ExecStart=/usr/bin/python3 /home/pi/scripts/field_camera.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target''',
                style: GoogleFonts.robotoMono(fontSize: 12),
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
    );
  }

  Widget _buildStep(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}


// =====================================================
// PUSH SCRIPT UPDATE DIALOG
// =====================================================

// =====================================================
// ADD FOOTAGE DIALOG (former recordings → pipeline)
// =====================================================
class _AddFootageDialog extends StatefulWidget {
  final String scheduleId;
  final String fieldId;
  final String fieldName;
  final bool enableBallTracking;
  final bool showFieldMask;
  final bool showRedBall;
  final int totalChunks;
  final String chunkProcessorWebhookUrl;
  final SupabaseClient supabase;
  final VoidCallback? onComplete;

  const _AddFootageDialog({
    Key? key,
    required this.scheduleId,
    required this.fieldId,
    required this.fieldName,
    required this.enableBallTracking,
    required this.showFieldMask,
    required this.showRedBall,
    required this.totalChunks,
    required this.chunkProcessorWebhookUrl,
    required this.supabase,
    this.onComplete,
  }) : super(key: key);

  @override
  State<_AddFootageDialog> createState() => _AddFootageDialogState();
}

class _AddFootageDialogState extends State<_AddFootageDialog> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submitFootage() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _message = 'Paste at least one video URL (one per line).';
        _isError = true;
      });
      return;
    }
    final urls = text.split(RegExp(r'\s+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final validUrls = urls.where((u) => u.startsWith('http://') || u.startsWith('https://')).toList();
    if (validUrls.isEmpty) {
      setState(() {
        _message = 'Enter valid video URLs (http or https).';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      for (int i = 0; i < validUrls.length; i++) {
        final videoUrl = validUrls[i];
        final chunkNumber = i + 1;
        final insertData = {
          'schedule_id': widget.scheduleId,
          'field_id': widget.fieldId,
          'chunk_number': chunkNumber,
          'status': 'uploaded',
          'upload_progress': 100,
          'video_url': videoUrl,
          'start_time': DateTime.now().toUtc().toIso8601String(),
        };
        final res = await widget.supabase.from('camera_recording_chunks').insert(insertData).select('id').single();
        final chunkId = res['id'] as String?;
        if (chunkId == null) continue;

        final response = await http.post(
          Uri.parse(widget.chunkProcessorWebhookUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chunk_id': chunkId,
            'video_url': videoUrl,
            'schedule_id': widget.scheduleId,
            'chunk_number': chunkNumber,
            'enable_ball_tracking': widget.enableBallTracking,
            'show_field_mask': widget.showFieldMask,
            'show_red_ball': widget.showRedBall,
          }),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode != 200) {
          setState(() {
            _message = 'Chunk $chunkNumber: GPU trigger failed (${response.statusCode})';
            _isError = true;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = '${validUrls.length} chunk(s) sent to pipeline. Processing on GPU.';
          _isError = false;
        });
        widget.onComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = 'Error: $e';
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.link, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          const Text('Add footage (former recording)'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Field: ${widget.fieldName}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste video URLs (one per line). They will be run through the ball-tracking pipeline.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'https://...\nhttps://...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: GoogleFonts.robotoMono(fontSize: 12),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isError ? Colors.red.shade200 : Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(_isError ? Icons.error_outline : Icons.check_circle_outline,
                        color: _isError ? Colors.red.shade700 : Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _message!,
                        style: GoogleFonts.inter(fontSize: 13, color: _isError ? Colors.red.shade800 : Colors.green.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submitFootage,
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow, size: 20),
          label: Text(_isLoading ? 'Sending...' : 'Run through pipeline'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
