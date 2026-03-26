import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';

class MatchRecordingWidget extends StatefulWidget {
  final Booking booking;

  const MatchRecordingWidget({
    super.key,
    required this.booking,
  });

  @override
  State<MatchRecordingWidget> createState() => _MatchRecordingWidgetState();
}

class _MatchRecordingWidgetState extends State<MatchRecordingWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  
  Map<String, dynamic>? _recordingSchedule;
  StreamSubscription? _scheduleSubscription;
  bool _isLoadingSchedule = true;
  final SupabaseService _supabaseService = SupabaseService();

  /// For demo bookings, we scale the 5-min video to appear as 60 minutes
  bool get _isDemoBooking => widget.booking.id == 'demo_past_match';
  static const Duration _fakeDuration = Duration(minutes: 60);

  /// Timer for updating the fake progress display in demo mode
  Timer? _demoProgressTimer;

  @override
  void initState() {
    super.initState();
    _loadRecordingSchedule();
  }
  
  Future<void> _loadRecordingSchedule() async {
    if (widget.booking.id == 'demo_past_match') {
      if (mounted) {
        setState(() {
          _recordingSchedule = {
            'id': 'demo_schedule_1',
            'status': 'completed',
            'final_video_url': 'https://upooyypqhftzzwjrfyra.supabase.co/storage/v1/object/public/videos/ball-tracking-output/bc352762-5e34-4de8-9212-fcd7dfec4b5e.mp4',
            'total_chunks': 1,
          };
          _isLoadingSchedule = false;
        });
        _initializeVideoPlayer('https://upooyypqhftzzwjrfyra.supabase.co/storage/v1/object/public/videos/ball-tracking-output/bc352762-5e34-4de8-9212-fcd7dfec4b5e.mp4');
      }
      return;
    }

    if (!widget.booking.isRecordingEnabled) {
      if (mounted) setState(() => _isLoadingSchedule = false);
      return;
    }
    
    try {
      Map<String, dynamic>? schedule;
      
      // First try to get schedule by recordingScheduleId if available
      if (widget.booking.recordingScheduleId != null) {
        print('🔍 Trying to fetch schedule by recordingScheduleId: ${widget.booking.recordingScheduleId}');
        schedule = await _supabaseService.getRecordingScheduleById(widget.booking.recordingScheduleId!);
      }
      
      // If not found, try by booking ID
      if (schedule == null) {
        print('🔍 Trying to fetch schedule by booking_id: ${widget.booking.id}');
        schedule = await _supabaseService.getRecordingScheduleForBooking(widget.booking.id);
      }
      
      // If still not found, try by field_id and date/time match
      if (schedule == null) {
        print('🔍 Trying to fetch schedule by field and time match');
        schedule = await _supabaseService.getRecordingScheduleByFieldAndTime(
          widget.booking.footballFieldId,
          widget.booking.date,
          widget.booking.timeSlot,
        );
      }
      
      if (schedule != null) {
        print('✅ Found recording schedule: ${schedule['id']} with status: ${schedule['status']}');
        setState(() {
          _recordingSchedule = schedule;
          _isLoadingSchedule = false;
        });
        
        // Get best available video URL
        final videoUrl = _getBestVideoUrl(schedule);
        
        // Initialize video player immediately if we have a video
        if (videoUrl != null) {
          _initializeVideoPlayer(videoUrl);
        }
        
        // Start streaming updates if schedule exists
        final scheduleId = schedule['id'];
        if (scheduleId != null) {
          _scheduleSubscription = _supabaseService
              .streamRecordingSchedule(scheduleId)
              .listen((data) {
            if (mounted && data != null) {
              setState(() {
                _recordingSchedule = data;
              });
              
              // Get best available video URL from updated data
              final updatedVideoUrl = _getBestVideoUrl(data);
              if (updatedVideoUrl != null) {
                _initializeVideoPlayer(updatedVideoUrl);
              }
            }
          });
        }
      } else {
        print('⚠️ No recording schedule found for booking');
        setState(() => _isLoadingSchedule = false);
      }
    } catch (e) {
      print('Error loading recording schedule: $e');
      setState(() => _isLoadingSchedule = false);
    }
  }
  
  /// Gets the best available video URL from the schedule
  /// Priority: final_video_url > merged_video_url > first processed chunk URL
  String? _getBestVideoUrl(Map<String, dynamic> schedule) {
    // Check for final video URL
    if (schedule['final_video_url'] != null) {
      return schedule['final_video_url'] as String;
    }
    
    // Check for merged video URL
    if (schedule['merged_video_url'] != null) {
      return schedule['merged_video_url'] as String;
    }
    
    // Check for processed chunks
    final chunks = schedule['camera_recording_chunks'] as List?;
    if (chunks != null && chunks.isNotEmpty) {
      // Find chunks with processed URLs
      final processedChunks = chunks
          .where((c) => c['processed_url'] != null)
          .toList();
      
      if (processedChunks.isNotEmpty) {
        // Sort by chunk number and get first
        processedChunks.sort((a, b) => 
          ((a['chunk_number'] ?? 0) as int).compareTo((b['chunk_number'] ?? 0) as int)
        );
        return processedChunks.first['processed_url'] as String?;
      }
    }
    
    return null;
  }
  
  /// Determines if the recording is effectively completed
  /// Returns true if status is 'completed' OR if we have a video URL
  bool _isEffectivelyCompleted() {
    if (_recordingSchedule == null) return false;
    
    final status = _recordingSchedule!['status'];
    if (status == 'completed') return true;
    
    // Also consider completed if we have a video URL
    return _getBestVideoUrl(_recordingSchedule!) != null;
  }

  /// For demo bookings, scale the actual position to the fake 60-minute duration
  Duration _scaledPosition(Duration actualPosition, Duration actualDuration) {
    if (actualDuration.inMilliseconds == 0) return Duration.zero;
    final ratio = actualPosition.inMilliseconds / actualDuration.inMilliseconds;
    return Duration(milliseconds: (_fakeDuration.inMilliseconds * ratio).round());
  }

  /// Format duration as mm:ss or hh:mm:ss
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    if (_isInitialized) return;
    
    try {
      print('Loading video from URL: $videoUrl');
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );
      await videoController.initialize();
      
      if (_isDemoBooking) {
        // For demo: use a custom Chewie controller without the built-in controls,
        // then overlay our own controls that show the fake 60-minute duration
        final chewieController = ChewieController(
          videoPlayerController: videoController,
          autoPlay: false,
          looping: false,
          aspectRatio: videoController.value.aspectRatio,
          allowFullScreen: true,
          showControls: false, // We'll overlay our own controls
          deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
          deviceOrientationsOnEnterFullScreen: const [DeviceOrientation.portraitUp],
          placeholder: const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        if (mounted) {
          setState(() {
            _videoController = videoController;
            _chewieController = chewieController;
            _isInitialized = true;
          });
          // Start a timer to update our custom progress bar
          _demoProgressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
            if (mounted) setState(() {});
          });
        }
      } else {
        // Normal (non-demo) video player
        final chewieController = ChewieController(
          videoPlayerController: videoController,
          autoPlay: false,
          looping: false,
          aspectRatio: videoController.value.aspectRatio,
          allowFullScreen: true,
          deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
          deviceOrientationsOnEnterFullScreen: const [DeviceOrientation.portraitUp],
          placeholder: const Center(
            child: CircularProgressIndicator(),
          ),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                'Error: $errorMessage',
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        );
        
        if (mounted) {
          setState(() {
            _videoController = videoController;
            _chewieController = chewieController;
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error loading video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  /// Build a custom video player overlay for demo mode that shows fake 60-min duration
  Widget _buildDemoVideoPlayer() {
    final controller = _videoController!;
    final actualDuration = controller.value.duration;
    final actualPosition = controller.value.position;
    final isPlaying = controller.value.isPlaying;

    final fakePosition = _scaledPosition(actualPosition, actualDuration);
    final fakeProgress = actualDuration.inMilliseconds > 0
        ? actualPosition.inMilliseconds / actualDuration.inMilliseconds
        : 0.0;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Video
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          // Play/Pause overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
              },
              child: AnimatedOpacity(
                opacity: isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black38,
                  child: const Center(
                    child: Icon(Icons.play_arrow, color: Colors.white, size: 60),
                  ),
                ),
              ),
            ),
          ),
          // Bottom controls with fake duration
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seekbar
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: const Color(0xFF00BF63),
                      inactiveTrackColor: Colors.white30,
                      thumbColor: const Color(0xFF00BF63),
                      overlayColor: const Color(0xFF00BF63).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: fakeProgress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        // Seek to the proportional position in the actual video
                        final seekTo = Duration(
                          milliseconds: (value * actualDuration.inMilliseconds).round(),
                        );
                        controller.seekTo(seekTo);
                      },
                    ),
                  ),
                  // Time labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(fakePosition),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            // Play/Pause button
                            GestureDetector(
                              onTap: () {
                                if (isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
                              },
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Fullscreen button
                            GestureDetector(
                              onTap: () {
                                _chewieController?.enterFullScreen();
                              },
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatDuration(_fakeDuration),
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _demoProgressTimer?.cancel();
    _scheduleSubscription?.cancel();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
  
  String _getStatusText(String? status) {
    // If we have a video URL, show as ready regardless of status
    if (_recordingSchedule != null && _getBestVideoUrl(_recordingSchedule!) != null) {
      return 'Ready to Watch';
    }
    
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'recording':
        return 'Recording in Progress';
      case 'uploading':
        return 'Uploading Recording';
      case 'processing':
        return 'Processing Video';
      case 'completed':
        return 'Ready to Watch';
      case 'error':
      case 'failed':
        return 'Error';
      default:
        return 'Preparing';
    }
  }
  
  Color _getStatusColor(String? status) {
    // If we have a video URL, show green regardless of status
    if (_recordingSchedule != null && _getBestVideoUrl(_recordingSchedule!) != null) {
      return const Color(0xFF00BF63);
    }
    
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'recording':
        return Colors.red;
      case 'uploading':
        return Colors.orange;
      case 'processing':
        return Colors.purple;
      case 'completed':
        return const Color(0xFF00BF63);
      case 'error':
      case 'failed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
  
  IconData _getStatusIcon(String? status) {
    // If we have a video URL, show check icon regardless of status
    if (_recordingSchedule != null && _getBestVideoUrl(_recordingSchedule!) != null) {
      return Icons.check_circle;
    }
    
    switch (status) {
      case 'scheduled':
        return Icons.schedule;
      case 'recording':
        return Icons.fiber_manual_record;
      case 'uploading':
        return Icons.cloud_upload;
      case 'processing':
        return Icons.sync;
      case 'completed':
        return Icons.check_circle;
      case 'error':
      case 'failed':
        return Icons.error;
      default:
        return Icons.schedule;
    }
  }
  
  String _getEstimatedReadyTime() {
    if (_recordingSchedule == null) return '';
    
    final endTimeStr = _recordingSchedule!['end_time'];
    if (endTimeStr == null) return '';
    
    try {
      final endTime = DateTime.parse(endTimeStr).toLocal();
      // Estimate: recording ends + 20-30 minutes for processing
      final estimatedReady = endTime.add(const Duration(minutes: 30));
      
      final now = DateTime.now();
      if (estimatedReady.isBefore(now)) {
        return 'Should be ready soon';
      }
      
      final diff = estimatedReady.difference(now);
      if (diff.inHours > 0) {
        return 'Ready in ~${diff.inHours}h ${diff.inMinutes % 60}m';
      } else if (diff.inMinutes > 0) {
        return 'Ready in ~${diff.inMinutes}m';
      } else {
        return 'Ready soon';
      }
    } catch (e) {
      return '';
    }
  }
  
  String _getRecordingTimeInfo() {
    if (_recordingSchedule == null) return '';
    
    final startTimeStr = _recordingSchedule!['start_time'];
    final endTimeStr = _recordingSchedule!['end_time'];
    
    if (startTimeStr == null || endTimeStr == null) return '';
    
    try {
      final startTime = DateTime.parse(startTimeStr).toLocal();
      final endTime = DateTime.parse(endTimeStr).toLocal();
      
      final dateFormat = DateFormat('MMM d');
      final timeFormat = DateFormat('h:mm a');
      
      return '${dateFormat.format(startTime)} • ${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}';
    } catch (e) {
      return '';
    }
  }
  
  int _getProgressPercentage() {
    if (_recordingSchedule == null) return 0;
    
    final status = _recordingSchedule!['status'];
    if (status == 'completed') return 100;
    if (status == 'scheduled') return 0;
    
    final totalChunks = _recordingSchedule!['total_chunks'] ?? 1;
    final chunks = _recordingSchedule!['camera_recording_chunks'] as List?;
    
    if (chunks == null || chunks.isEmpty) return 5;
    
    int completedChunks = 0;
    int uploadedChunks = 0;
    
    for (final chunk in chunks) {
      if (chunk['status'] == 'completed' || chunk['gpu_status'] == 'completed') {
        completedChunks++;
      } else if (chunk['status'] == 'uploaded' || chunk['video_url'] != null) {
        uploadedChunks++;
      }
    }
    
    // Progress calculation:
    // Recording: 0-30%
    // Uploading: 30-50%
    // GPU Processing: 50-90%
    // Merging: 90-100%
    
    if (status == 'recording') {
      return ((chunks.length / totalChunks) * 30).round().clamp(5, 30);
    } else if (status == 'processing') {
      final uploadProgress = (uploadedChunks + completedChunks) / totalChunks;
      final gpuProgress = completedChunks / totalChunks;
      
      if (gpuProgress > 0.5) {
        return (50 + (gpuProgress * 40)).round().clamp(50, 90);
      } else {
        return (30 + (uploadProgress * 20)).round().clamp(30, 50);
      }
    }
    
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.booking.isRecordingEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BF63).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    color: Color(0xFF00BF63),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match Recording',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      if (_getRecordingTimeInfo().isNotEmpty)
                        Text(
                          _getRecordingTimeInfo(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Content based on state
            if (_isLoadingSchedule)
              _buildLoadingState()
            else if (_recordingSchedule == null)
              _buildNoScheduleState()
            else
              _buildScheduleContent(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00BF63),
        ),
      ),
    );
  }
  
  Widget _buildNoScheduleState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule,
            color: Colors.grey[400],
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'Recording Scheduled',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your match will be recorded automatically',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScheduleContent() {
    final status = _recordingSchedule!['status'] as String?;
    final videoUrl = _getBestVideoUrl(_recordingSchedule!);
    final isCompleted = _isEffectivelyCompleted();
    
    // Show video player if we have video and it's ready
    if (isCompleted && videoUrl != null && _isInitialized) {
      return Column(
        children: [
          // Status indicator - show 'completed' since we have video
          _buildStatusBadge('completed'),
          const SizedBox(height: 16),
          // For demo bookings, use custom player with fake 60-min duration
          if (_isDemoBooking)
            _buildDemoVideoPlayer()
          else
            // Normal video player
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black,
              ),
              clipBehavior: Clip.hardEdge,
              child: _chewieController != null 
                  ? Chewie(controller: _chewieController!)
                  : const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    
    // Show video player loading if we have video URL but not initialized yet
    if (videoUrl != null && !_isInitialized && !_hasError) {
      return Column(
        children: [
          _buildStatusBadge('completed'),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black87,
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // Show error state
    if (_hasError) {
      return Column(
        children: [
          _buildStatusBadge('error'),
          const SizedBox(height: 16),
          _buildErrorState(),
        ],
      );
    }
    
    // Show progress state
    return Column(
      children: [
        _buildStatusBadge(status),
        const SizedBox(height: 16),
        _buildProgressCard(status),
      ],
    );
  }
  
  Widget _buildStatusBadge(String? status) {
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final statusIcon = _getStatusIcon(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: GoogleFonts.inter(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressCard(String? status) {
    final progress = _getProgressPercentage();
    final estimatedTime = _getEstimatedReadyTime();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(status)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          
          // Progress info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$progress% complete',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              if (estimatedTime.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      estimatedTime,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Status message
          _buildStatusMessage(status),
        ],
      ),
    );
  }
  
  Widget _buildStatusMessage(String? status) {
    String message;
    IconData icon;
    
    switch (status) {
      case 'scheduled':
        message = 'Recording will start at the match time';
        icon = Icons.info_outline;
        break;
      case 'recording':
        message = 'Recording your match in progress...';
        icon = Icons.fiber_manual_record;
        break;
      case 'processing':
        message = 'Processing video with AI ball tracking';
        icon = Icons.auto_awesome;
        break;
      default:
        message = 'Preparing your recording';
        icon = Icons.hourglass_empty;
    }
    
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red[50],
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load video',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _hasError = false;
              });
              final videoUrl = _recordingSchedule?['final_video_url'];
              if (videoUrl != null) {
                _initializeVideoPlayer(videoUrl);
              }
            },
            child: Text(
              'Retry',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF00BF63),
              ),
            ),
          ),
        ],
      ),
    );
  }
}