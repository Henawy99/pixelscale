import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class BallTrackingJob {
  final String id;
  final DateTime createdAt;
  final String inputVideoUrl;
  final String? outputVideoUrl;
  final String videoName;
  final double? videoDurationSeconds;
  final double? videoSizeMb;
  final String status;
  final int progressPercent;
  final String? errorMessage;
  final Map<String, dynamic> scriptConfig;
  final String scriptVersion;
  final int? trackingAccuracyPercent;
  final int? framesTracked;
  final int? totalFrames;
  final double? processingTimeSeconds;
  final double? gpuCostUsd;
  final String? gpuType;
  final String? processingLogs;
  final String? customScript;
  final String? modelName;

  BallTrackingJob({
    required this.id,
    required this.createdAt,
    required this.inputVideoUrl,
    this.outputVideoUrl,
    required this.videoName,
    this.videoDurationSeconds,
    this.videoSizeMb,
    required this.status,
    required this.progressPercent,
    this.errorMessage,
    required this.scriptConfig,
    required this.scriptVersion,
    this.trackingAccuracyPercent,
    this.framesTracked,
    this.totalFrames,
    this.processingTimeSeconds,
    this.gpuCostUsd,
    this.gpuType,
    this.processingLogs,
    this.customScript,
    this.modelName,
  });

  factory BallTrackingJob.fromJson(Map<String, dynamic> json) {
    return BallTrackingJob(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      inputVideoUrl: json['input_video_url'],
      outputVideoUrl: json['output_video_url'],
      videoName: json['video_name'],
      videoDurationSeconds: json['video_duration_seconds']?.toDouble(),
      videoSizeMb: json['video_size_mb']?.toDouble(),
      status: json['status'] ?? 'pending',
      progressPercent: json['progress_percent'] ?? 0,
      errorMessage: json['error_message'],
      scriptConfig: json['script_config'] ?? {},
      scriptVersion: json['script_version'] ?? '1.0',
      trackingAccuracyPercent: json['tracking_accuracy_percent'],
      framesTracked: json['frames_tracked'],
      totalFrames: json['total_frames'],
      processingTimeSeconds: json['processing_time_seconds']?.toDouble(),
      gpuCostUsd: json['gpu_cost_usd']?.toDouble(),
      gpuType: json['gpu_type'],
      processingLogs: json['processing_logs'],
      customScript: json['custom_script'],
      modelName: json['model_name'],
    );
  }
}

class ScriptConfig {
  final double zoomBase;
  final double zoomFar;
  final double smoothing;
  final double zoomSmooth;
  final int detectEveryFrames;
  final double yoloConf;
  final int memory;
  final double predictFactor;
  final int roiSize;
  final String yoloModel;
  final int yoloImgSize;
  final List<List<double>>? fieldMaskPoints;
  final bool showFieldMask;
  final bool showRedBall;

  ScriptConfig({
    this.zoomBase = 1.75,
    this.zoomFar = 2.1,
    this.smoothing = 0.07,
    this.zoomSmooth = 0.1,
    this.detectEveryFrames = 2,
    this.yoloConf = 0.35,
    this.memory = 6,
    this.predictFactor = 0.25,
    this.roiSize = 400,
    this.yoloModel = 'yolov8l',
    this.yoloImgSize = 960,
    this.fieldMaskPoints,
    this.showFieldMask = true,
    this.showRedBall = false,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
        'zoom_base': zoomBase,
        'zoom_far': zoomFar,
        'smoothing': smoothing,
        'zoom_smooth': zoomSmooth,
        'detect_every_frames': detectEveryFrames,
        'yolo_conf': yoloConf,
        'memory': memory,
        'predict_factor': predictFactor,
        'roi_size': roiSize,
        'yolo_model': yoloModel,
        'yolo_img_size': yoloImgSize,
        'show_field_mask': showFieldMask,
        'show_red_ball': showRedBall,
      };
    if (fieldMaskPoints != null && fieldMaskPoints!.isNotEmpty) {
      map['field_mask_points'] = fieldMaskPoints;
    }
    return map;
  }

  factory ScriptConfig.fromJson(Map<String, dynamic> json) => ScriptConfig(
        zoomBase: (json['zoom_base'] ?? 1.75).toDouble(),
        zoomFar: (json['zoom_far'] ?? 2.1).toDouble(),
        smoothing: (json['smoothing'] ?? 0.07).toDouble(),
        zoomSmooth: (json['zoom_smooth'] ?? 0.1).toDouble(),
        detectEveryFrames: json['detect_every_frames'] ?? 2,
        yoloConf: (json['yolo_conf'] ?? 0.35).toDouble(),
        memory: json['memory'] ?? 6,
        predictFactor: (json['predict_factor'] ?? 0.25).toDouble(),
        roiSize: json['roi_size'] ?? 400,
        yoloModel: json['yolo_model'] ?? 'yolov8l',
        yoloImgSize: json['yolo_img_size'] ?? 960,
        showFieldMask: json['show_field_mask'] ?? true,
        showRedBall: json['show_red_ball'] ?? false,
        fieldMaskPoints: json['field_mask_points'] != null
            ? (json['field_mask_points'] as List).map<List<double>>((p) => (p as List).map<double>((v) => (v as num).toDouble()).toList()).toList()
            : null,
      );

  // Preset configurations
  static ScriptConfig get balanced => ScriptConfig();
  
  static ScriptConfig get highAccuracy => ScriptConfig(
        detectEveryFrames: 1,
        yoloConf: 0.25,
        yoloModel: 'yolov8x',
        yoloImgSize: 1280,
      );
  
  static ScriptConfig get fast => ScriptConfig(
        detectEveryFrames: 4,
        yoloConf: 0.4,
        yoloModel: 'yolov8n',
        yoloImgSize: 640,
      );
  
  static ScriptConfig get debug => ScriptConfig(
        detectEveryFrames: 1,  // Check every frame
        yoloConf: 0.15,  // Very low confidence - detect everything!
        yoloModel: 'yolov8l',  // Large model for better detection
        yoloImgSize: 1280,  // Higher resolution
        roiSize: 800,  // Larger search area
      );
  
  // FAST PRECISION: 5x faster! Optimized settings + perspective correction
  static ScriptConfig get fastPrecision => ScriptConfig(
        detectEveryFrames: 2,  // 2x faster (detect every 2nd frame)
        yoloConf: 0.12,  // Low confidence - good detection
        yoloModel: 'yolov8l',  // Large model for accuracy
        yoloImgSize: 960,  // 1.7x faster than 1280, still excellent
        roiSize: 1200,  // 1.5x faster than 2000, sufficient coverage
        // Uses fast_precision_ball_tracking.py with perspective correction
        // for high-mounted cameras (near side vs far side handling)
      );
  
  // TRACKNET ULTRA: Maximum accuracy with physics-based tracking
  // Uses 6-state Kalman (acceleration model), spring-damper camera,
  // multi-scale detection, second-pass refinement, temporal confirmation
  static ScriptConfig get tracknetUltra => ScriptConfig(
        detectEveryFrames: 1,    // Detect every frame
        yoloConf: 0.08,          // Very low — temporal filtering handles false positives
        yoloModel: 'tracknet',   // Activates TrackNet v5.0 pipeline
        yoloImgSize: 1280,       // High-res primary detection
        smoothing: 0.0,          // Physics-based camera (spring-damper)
        zoomSmooth: 0.0,         // Adaptive zoom handled by camera system
      );
}

class BallTrackingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Modal.com configuration
  // Webhook URL - uses the playmakerstart Modal app (same as camera monitoring)
  // This ensures the ball tracking uses the same reliable infrastructure
  static const String _modalWebhookUrl = 'https://youssefelhenawy0--ball-tracking-processor-api.modal.run/webhook';

  /// Creates a robust stream that automatically handles errors and reconnects.
  /// This prevents RealtimeSubscribeException from crashing the app.
  Stream<T> _createRobustStream<T>({
    required Stream<T> Function() streamFactory,
    int maxRetries = 5,
    int initialDelay = 1000,
    int maxDelay = 30000,
  }) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    int retryCount = 0;
    Timer? retryTimer;
    bool isControllerClosed = false;

    void subscribe() {
      if (isControllerClosed) return;
      
      subscription?.cancel();
      subscription = streamFactory().listen(
        (data) {
          if (!isControllerClosed) {
            retryCount = 0;
            controller.add(data);
          }
        },
        onError: (error, stackTrace) {
          print('⚠️ BallTracking stream error: $error');
          
          if (isControllerClosed) return;
          
          final errorString = error.toString().toLowerCase();
          final isChannelError = errorString.contains('realtimesubscribe') ||
              errorString.contains('channel') ||
              errorString.contains('timeout') ||
              errorString.contains('connection');
          
          if (isChannelError && retryCount < maxRetries) {
            retryCount++;
            final delay = (initialDelay * (1 << (retryCount - 1)))
                .clamp(initialDelay, maxDelay);
            final jitter = (delay * 0.1 * (DateTime.now().millisecondsSinceEpoch % 10) / 10).toInt();
            final totalDelay = delay + jitter;
            
            print('🔄 Attempting to reconnect stream (attempt $retryCount/$maxRetries) in ${totalDelay}ms...');
            
            retryTimer?.cancel();
            retryTimer = Timer(Duration(milliseconds: totalDelay), () {
              if (!isControllerClosed) {
                subscribe();
              }
            });
          } else if (!isControllerClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          if (!isControllerClosed && retryCount < maxRetries) {
            retryCount++;
            final delay = (initialDelay * (1 << (retryCount - 1)))
                .clamp(initialDelay, maxDelay);
            
            retryTimer?.cancel();
            retryTimer = Timer(Duration(milliseconds: delay), () {
              if (!isControllerClosed) {
                subscribe();
              }
            });
          } else if (!isControllerClosed) {
            controller.close();
          }
        },
        cancelOnError: false,
      );
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        subscribe();
      },
      onCancel: () {
        isControllerClosed = true;
        retryTimer?.cancel();
        subscription?.cancel();
      },
    );

    return controller.stream;
  }
  
  /// Upload video to Supabase Storage with progress tracking (supports web and mobile)
  Future<String> uploadVideo(
    dynamic videoFileOrBytes, 
    String fileName,
    {Function(double)? onProgress}
  ) async {
    try {
      late Uint8List bytes;
      
      // Handle both File (mobile) and Uint8List/bytes (web)
      if (videoFileOrBytes is File) {
        if (onProgress != null) onProgress(0.1); // Reading file
        bytes = await videoFileOrBytes.readAsBytes();
      } else if (videoFileOrBytes is Uint8List) {
        bytes = videoFileOrBytes;
      } else if (videoFileOrBytes is List<int>) {
        bytes = Uint8List.fromList(videoFileOrBytes);
      } else {
        throw Exception('Invalid video file type');
      }
      
      final fileSizeMb = bytes.length / (1024 * 1024);
      
      print('Uploading video: $fileName (${fileSizeMb.toStringAsFixed(2)} MB)');
      
      if (onProgress != null) onProgress(0.2); // Starting upload
      
      final path = 'ball-tracking-input/$fileName';
      
      // Simulate progress for large files (Supabase doesn't provide real-time upload progress)
      final uploadFuture = _supabase.storage.from('videos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: true,
            ),
          );
      
      // Simulate progress updates while uploading
      if (onProgress != null) {
        // Much more conservative estimate based on file size
        // Small files: 3 sec/MB, Medium: 5 sec/MB, Large: 8 sec/MB, Very large: 12 sec/MB
        double estimatedDuration;
        if (fileSizeMb < 50) {
          estimatedDuration = fileSizeMb * 3; // Small files
        } else if (fileSizeMb < 150) {
          estimatedDuration = fileSizeMb * 5; // Medium files
        } else if (fileSizeMb < 300) {
          estimatedDuration = fileSizeMb * 8; // Large files
        } else {
          estimatedDuration = fileSizeMb * 12; // Very large files
        }
        
        // Clamp to reasonable range (min 5 sec, max 30 minutes)
        estimatedDuration = estimatedDuration.clamp(5.0, 1800.0);
        
        print('Upload estimate: ${estimatedDuration.toInt()}s for ${fileSizeMb.toStringAsFixed(1)} MB');
        
        final progressTimer = Timer.periodic(
          Duration(milliseconds: 500),
          (timer) {
            final elapsed = timer.tick * 0.5; // seconds
            
            // More realistic progress curve
            final rawProgress = elapsed / estimatedDuration;
            
            double progress;
            if (rawProgress < 0.6) {
              // First 60% of time: linear to 70%
              progress = 0.2 + (rawProgress / 0.6 * 0.5); // 20% to 70%
            } else if (rawProgress < 1.0) {
              // 60-100% of time: slow progress to 90%
              progress = 0.7 + ((rawProgress - 0.6) / 0.4 * 0.2); // 70% to 90%
            } else if (rawProgress < 1.5) {
              // Overtime 0-50%: creep to 95%
              progress = 0.9 + ((rawProgress - 1.0) / 0.5 * 0.05); // 90% to 95%
            } else if (rawProgress < 2.5) {
              // Overtime 50-150%: creep to 97%
              progress = 0.95 + ((rawProgress - 1.5) / 1.0 * 0.02); // 95% to 97%
            } else {
              // Way over time: asymptotic to 98%
              final overtime = rawProgress - 2.5;
              progress = 0.97 + (0.01 * (1 - (1 / (1 + overtime * 0.5)))); // Asymptotic to 98%
            }
            
            onProgress(progress.clamp(0.2, 0.98));
          },
        );
        
        try {
          await uploadFuture;
          progressTimer.cancel();
          onProgress(1.0); // Upload complete
        } catch (e) {
          progressTimer.cancel();
          rethrow;
        }
      } else {
        await uploadFuture;
      }

      final url = _supabase.storage.from('videos').getPublicUrl(path);
      return url;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Create a new tracking job
  Future<BallTrackingJob> createJob({
    required String inputVideoUrl,
    required String videoName,
    required ScriptConfig config,
    double? videoSizeMb,
    String? scriptVersion,
    String? customScript,
  }) async {
    try {
      final response = await _supabase.from('ball_tracking_jobs').insert({
        'input_video_url': inputVideoUrl,
        'video_name': videoName,
        'video_size_mb': videoSizeMb,
        'script_config': config.toJson(),
        'script_version': scriptVersion ?? '1.0',
        'status': 'pending',
        'progress_percent': 0,
        if (customScript != null) 'custom_script': customScript,
      }).select().single();

      return BallTrackingJob.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create job: $e');
    }
  }

  /// Generate a preview of the AI frame extension
  Future<String> generateAIExtensionPreview(String videoUrl) async {
    try {
      final baseUrl = _modalWebhookUrl.replaceAll('/webhook', '/preview');
      print('🚀 Requesting AI extension preview: $baseUrl');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'video_url': videoUrl}),
      ).timeout(const Duration(minutes: 2));

      if (response.statusCode != 200) {
        throw Exception('Failed to generate preview (${response.statusCode}): ${response.body}');
      }
      
      final result = jsonDecode(response.body);
      if (result['status'] == 'success') {
        return result['preview_url'];
      } else {
        throw Exception(result['message'] ?? 'Failed to generate preview');
      }
    } catch (e) {
      throw Exception('Preview generation failed: $e');
    }
  }

  /// Trigger Modal.com processing
  Future<void> triggerProcessing(String jobId, {String? roboflowApiKey}) async {
    try {
      final job = await getJob(jobId);
      
      // Update status to queued
      await _supabase.from('ball_tracking_jobs').update({
        'status': 'processing',
        'progress_percent': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', jobId);

      print('🚀 Submitting to Modal.com webhook');
      
      // Check if webhook URL is configured
      if (_modalWebhookUrl == 'YOUR_MODAL_WEBHOOK_URL_HERE') {
        throw Exception('Modal webhook URL not configured. Please deploy modal_app.py first and update _modalWebhookUrl');
      }
      
      // Call Modal webhook endpoint
      final requestBody = {
        'job_id': jobId,
        'video_url': job.inputVideoUrl,
        'config': job.scriptConfig,
        if (job.customScript != null) 'custom_script': job.customScript,
        if (roboflowApiKey != null) 'roboflow_api_key': roboflowApiKey,
      };
      
      final response = await http.post(
        Uri.parse(_modalWebhookUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(minutes: 3),  // Allow 3 minutes for cold start
        onTimeout: () {
          throw Exception('Modal webhook request timed out after 3 minutes. This can happen on first call when Modal is starting up. Please try again in a few seconds.');
        },
      );

      print('📡 Modal response status: ${response.statusCode}');
      print('📡 Modal response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Modal request failed (${response.statusCode}): ${response.body}');
      }
      
      final result = jsonDecode(response.body);
      print('✅ Modal job queued: ${result['status']}');
      
    } catch (e) {
      // Update job with error
      await _supabase.from('ball_tracking_jobs').update({
        'status': 'failed',
        'error_message': e.toString(),
      }).eq('id', jobId);
      
      throw Exception('Failed to trigger processing: $e');
    }
  }

  /// Get a single job
  Future<BallTrackingJob> getJob(String jobId) async {
    try {
      final response = await _supabase
          .from('ball_tracking_jobs')
          .select()
          .eq('id', jobId)
          .single();
      return BallTrackingJob.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get job: $e');
    }
  }

  /// Get all jobs (sorted by newest first)
  Future<List<BallTrackingJob>> getAllJobs() async {
    try {
      final response = await _supabase
          .from('ball_tracking_jobs')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => BallTrackingJob.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get jobs: $e');
    }
  }

  /// Subscribe to job updates (realtime) - with auto-reconnect
  Stream<BallTrackingJob> subscribeToJob(String jobId) {
    return _createRobustStream<BallTrackingJob>(
      streamFactory: () => _supabase
          .from('ball_tracking_jobs')
          .stream(primaryKey: ['id'])
          .eq('id', jobId)
          .map((data) => BallTrackingJob.fromJson(data.first)),
    );
  }

  /// Subscribe to all jobs (realtime) - with auto-reconnect
  Stream<List<BallTrackingJob>> subscribeToAllJobs() {
    return _createRobustStream<List<BallTrackingJob>>(
      streamFactory: () => _supabase
          .from('ball_tracking_jobs')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => BallTrackingJob.fromJson(json)).toList()),
    );
  }

  /// Delete a job
  Future<void> deleteJob(String jobId) async {
    try {
      await _supabase.from('ball_tracking_jobs').delete().eq('id', jobId);
    } catch (e) {
      throw Exception('Failed to delete job: $e');
    }
  }

  /// Update job progress (for testing)
  Future<void> updateJobProgress(String jobId, int progress) async {
    await _supabase.from('ball_tracking_jobs').update({
      'progress_percent': progress,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }
}
