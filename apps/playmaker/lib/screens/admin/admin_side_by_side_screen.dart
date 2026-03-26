import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:playmakerappstart/services/ball_tracking_service.dart';

class AdminSideBySideComparisonScreen extends StatefulWidget {
  final BallTrackingJob jobA;
  final BallTrackingJob jobB;

  const AdminSideBySideComparisonScreen({
    Key? key,
    required this.jobA,
    required this.jobB,
  }) : super(key: key);

  @override
  State<AdminSideBySideComparisonScreen> createState() => _AdminSideBySideComparisonScreenState();
}

class _AdminSideBySideComparisonScreenState extends State<AdminSideBySideComparisonScreen> {
  late VideoPlayerController _controllerA;
  late VideoPlayerController _controllerB;
  ChewieController? _chewieA;
  ChewieController? _chewieB;
  bool _isInitialized = false;
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }

  Future<void> _initializePlayers() async {
    _controllerA = VideoPlayerController.network(widget.jobA.outputVideoUrl!);
    _controllerB = VideoPlayerController.network(widget.jobB.outputVideoUrl!);

    await Future.wait([
      _controllerA.initialize(),
      _controllerB.initialize(),
    ]);

    _chewieA = ChewieController(
      videoPlayerController: _controllerA,
      aspectRatio: _controllerA.value.aspectRatio,
      autoPlay: false,
      looping: false,
      placeholder: const Center(child: CircularProgressIndicator()),
    );

    _chewieB = ChewieController(
      videoPlayerController: _controllerB,
      aspectRatio: _controllerB.value.aspectRatio,
      autoPlay: false,
      looping: false,
      placeholder: const Center(child: CircularProgressIndicator()),
    );

    setState(() {
      _isInitialized = true;
    });
  }

  void _syncPlay() {
    _controllerA.play();
    _controllerB.play();
  }

  void _syncPause() {
    _controllerA.pause();
    _controllerB.pause();
  }

  void _syncSeek(Duration position) {
    _controllerA.seekTo(position);
    _controllerB.seekTo(position);
  }

  @override
  void dispose() {
    _controllerA.dispose();
    _controllerB.dispose();
    _chewieA?.dispose();
    _chewieB?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Model Benchmarking: Side-by-Side'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          Row(
            children: [
              const Text('Sync playback', style: TextStyle(fontSize: 12)),
              Switch(
                value: _isSyncing,
                onChanged: (val) => setState(() => _isSyncing = val),
                activeColor: const Color(0xFF00BF63),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BF63)))
          : Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Video A
                      Expanded(
                        child: Column(
                          children: [
                            _buildInfoOverlay(widget.jobA, Colors.blue),
                            Expanded(child: Chewie(controller: _chewieA!)),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 2, color: Colors.white24),
                      // Video B
                      Expanded(
                        child: Column(
                          children: [
                            _buildInfoOverlay(widget.jobB, const Color(0xFF00BF63)),
                            Expanded(child: Chewie(controller: _chewieB!)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Global Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[900],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                        onPressed: () {
                          final pos = _controllerA.value.position - const Duration(seconds: 10);
                          _syncSeek(pos < Duration.zero ? Duration.zero : pos);
                        },
                      ),
                      const SizedBox(width: 24),
                      FloatingActionButton(
                        onPressed: () {
                          if (_controllerA.value.isPlaying) {
                            _syncPause();
                          } else {
                            _syncPlay();
                          }
                          setState(() {});
                        },
                        backgroundColor: const Color(0xFF00BF63),
                        child: Icon(_controllerA.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                        onPressed: () {
                          _syncSeek(_controllerA.value.position + const Duration(seconds: 10));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoOverlay(BallTrackingJob job, Color accentColor) {
    final isCustom = job.scriptConfig['yolo_model']?.toString().contains('roboflow') == true;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        border: Border(bottom: BorderSide(color: accentColor.withOpacity(0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                isCustom ? 'CUSTOM MODEL' : 'STANDARD MODEL',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: accentColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${job.scriptConfig['yolo_model'] ?? 'Standard'} • ${job.trackingAccuracyPercent}% Red Dot',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
