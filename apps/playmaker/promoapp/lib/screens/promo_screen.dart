import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN PROMO SCREEN - Menu with two options
// ═══════════════════════════════════════════════════════════════════════════════
class PromoScreen extends StatefulWidget {
  const PromoScreen({super.key});

  @override
  State<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends State<PromoScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated background
          _buildAnimatedBackground(),
          
          // Main content - responsive for landscape
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = constraints.maxWidth > constraints.maxHeight;
                
                if (isLandscape) {
                  // LANDSCAPE LAYOUT - side by side
                  return Row(
                    children: [
                      // Left side - Logo
                      Expanded(
                        flex: 4,
                        child: _buildHeader(compact: true),
                      ),
                      // Right side - Buttons
                      Expanded(
                        flex: 6,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.3, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _slideController,
                            curve: Curves.easeOutCubic,
                          )),
                          child: FadeTransition(
                            opacity: _slideController,
                            child: _buildMenuButtons(compact: true),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                
                // PORTRAIT LAYOUT - stacked
                return Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    Expanded(
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _slideController,
                          curve: Curves.easeOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: _slideController,
                          child: _buildMenuButtons(),
                        ),
                      ),
                    ),
                    _buildFooter(),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [
                Color.lerp(
                  const Color(0xFF00BF63).withOpacity(0.2),
                  const Color(0xFF00BF63).withOpacity(0.05),
                  _pulseController.value,
                )!,
                const Color(0xFF0a0a0a),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({bool compact = false}) {
    final logoSize = compact ? 80.0 : 120.0;
    final titleSize = compact ? 32.0 : 48.0;
    final subtitleSize = compact ? 10.0 : 14.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: const Color(0xFF00BF63),
            borderRadius: BorderRadius.circular(logoSize * 0.25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BF63).withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Icon(
            Icons.sports_soccer,
            color: Colors.white,
            size: logoSize * 0.6,
          ),
        ),
        SizedBox(height: compact ? 15 : 30),
        
        // Title
        Text(
          'PLAYMAKER',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00BF63), width: 2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            'AI-POWERED MATCH RECORDING',
            style: GoogleFonts.inter(
              color: const Color(0xFF00BF63),
              fontSize: subtitleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: compact ? 1 : 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButtons({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 30 : 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // BOOK & RECORD - Main awareness promo
          _buildMenuButton(
            icon: Icons.smartphone,
            title: 'BOOK & RECORD',
            subtitle: 'Download the app now!',
            color: const Color(0xFF00BF63),
            compact: compact,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppAwarenessScreen()),
            ),
          ),
          
          SizedBox(height: compact ? 12 : 25),
          
          // AD VIDEO - Sponsor logos + promo video
          _buildMenuButton(
            icon: Icons.play_circle_outline,
            title: 'AD VIDEO',
            subtitle: 'Sponsors & promo',
            color: Colors.orange,
            compact: compact,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdVideoScreen()),
            ),
          ),
          
          SizedBox(height: compact ? 12 : 25),
          
          // AL BASEET SPORTS - Animated product showcase
          _buildMenuButton(
            icon: Icons.sports_tennis,
            title: 'AL BASEET SPORTS',
            subtitle: 'Premium sports gear',
            color: const Color(0xFFFFD700),
            compact: compact,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlBaseetPromoScreen()),
            ),
          ),
          
          SizedBox(height: compact ? 12 : 25),
          
          // PAST RECORDINGS Button
          _buildMenuButton(
            icon: Icons.video_library,
            title: 'PAST RECORDINGS',
            subtitle: 'View your match highlights',
            color: Colors.blue,
            compact: compact,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordingsListScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final iconBoxSize = compact ? 50.0 : 80.0;
    final iconSize = compact ? 28.0 : 45.0;
    final titleSize = compact ? 18.0 : 24.0;
    final subtitleSize = compact ? 12.0 : 16.0;
    final padding = compact ? 15.0 : 30.0;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: color.withOpacity(0.5 + _pulseController.value * 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(iconBoxSize * 0.25),
                    ),
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                  SizedBox(width: compact ? 15 : 25),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 5),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            color: Colors.white60,
                            fontSize: subtitleSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: color, size: compact ? 20 : 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Book your match • Get AI recording',
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber.withOpacity(0.6), size: 18),
            const SizedBox(width: 8),
            Text(
              'Powered by AI Ball Tracking',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// PROMO VIDEO SCREEN - Shows promo content with video fallback to slideshow
// ═══════════════════════════════════════════════════════════════════════════════
class PromoVideoScreen extends StatefulWidget {
  const PromoVideoScreen({super.key});

  @override
  State<PromoVideoScreen> createState() => _PromoVideoScreenState();
}

class _PromoVideoScreenState extends State<PromoVideoScreen> with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showSlideshow = false;
  int _currentSlide = 0;
  Timer? _slideTimer;
  late AnimationController _fadeController;

  // Promo slides content
  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'AI-POWERED RECORDING',
      'subtitle': 'Our cameras automatically track the ball\nand follow the action',
      'icon': Icons.auto_awesome,
      'color': const Color(0xFF00BF63),
    },
    {
      'title': 'BOOK & PLAY',
      'subtitle': 'Reserve your field through the app\nand your match gets recorded',
      'icon': Icons.calendar_today,
      'color': Colors.blue,
    },
    {
      'title': 'INSTANT HIGHLIGHTS',
      'subtitle': 'Get your match video processed\nwith professional broadcast quality',
      'icon': Icons.movie_creation,
      'color': Colors.orange,
    },
    {
      'title': 'SHARE & RELIVE',
      'subtitle': 'Download and share your best\nmoments with friends',
      'icon': Icons.share,
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initVideo();
  }

  Future<void> _initVideo() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final url = 'https://upooyypqhftzzwjrfyra.supabase.co/storage/v1/object/public/videos/promo/playmaker_promo.mp4';
      print('🎬 Trying video: $url');
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize().timeout(const Duration(seconds: 10));
      
      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
        controller.setLooping(true);
        controller.play();
        print('✅ Video playing!');
      }
    } catch (e) {
      print('❌ Video failed: $e - Showing slideshow instead');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _showSlideshow = true;
        });
        _startSlideshow();
      }
    }
  }

  void _startSlideshow() {
    _fadeController.forward();
    _slideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _fadeController.reverse().then((_) {
          setState(() {
            _currentSlide = (_currentSlide + 1) % _slides.length;
          });
          _fadeController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _slideTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _showSlideshow ? 'HOW IT WORKS' : 'PROMO VIDEO',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoading()
          : _showSlideshow
              ? _buildSlideshow()
              : _buildVideoPlayer(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00BF63)),
          const SizedBox(height: 20),
          Text(
            'Loading...',
            style: GoogleFonts.inter(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideshow() {
    final slide = _slides[_currentSlide];
    
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              (slide['color'] as Color).withOpacity(0.3),
              Colors.black,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: (slide['color'] as Color).withOpacity(0.2),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: slide['color'] as Color,
                  width: 3,
                ),
              ),
              child: Icon(
                slide['icon'] as IconData,
                color: slide['color'] as Color,
                size: 80,
              ),
            ),
            const SizedBox(height: 50),
            
            // Title
            Text(
              slide['title'] as String,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Subtitle
            Text(
              slide['subtitle'] as String,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 20,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 60),
            
            // Slide indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (index) {
                final isActive = index == _currentSlide;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isActive ? 40 : 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isActive ? slide['color'] as Color : Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return _buildSlideshow();
    }
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // FULL SCREEN VIDEO - fills the entire screen
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        
        // Play/Pause overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// RECORDINGS LIST SCREEN - Shows past recordings with thumbnails
// ═══════════════════════════════════════════════════════════════════════════════
class RecordingsListScreen extends StatefulWidget {
  const RecordingsListScreen({super.key});

  @override
  State<RecordingsListScreen> createState() => _RecordingsListScreenState();
}

class _RecordingsListScreenState extends State<RecordingsListScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _recordings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get recordings from last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final response = await _supabase
          .from('camera_recording_schedules')
          .select('*, camera_recording_chunks(*)')
          .gte('created_at', thirtyDaysAgo.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      final List<Map<String, dynamic>> recordings = [];

      for (final schedule in (response as List)) {
        final chunks = schedule['camera_recording_chunks'] as List? ?? [];
        
        // Get thumbnail from schedule or chunks
        String? thumbnailUrl = schedule['thumbnail_url'] as String?;
        String? videoUrl = schedule['final_video_url'] as String?;
        
        int uploadedChunks = 0;
        int processedChunks = 0;
        
        for (final chunk in chunks) {
          if (chunk['video_url'] != null) uploadedChunks++;
          if (chunk['processed_url'] != null) {
            processedChunks++;
            videoUrl ??= chunk['processed_url'];
          }
          thumbnailUrl ??= chunk['thumbnail_url'] as String?;
        }

        // Get field name
        String fieldName = 'Match Recording';
        final fieldId = schedule['field_id'] as String?;
        if (fieldId != null) {
          try {
            final fieldData = await _supabase
                .from('football_fields')
                .select('football_field_name')
                .eq('id', fieldId)
                .maybeSingle();
            if (fieldData != null) {
              fieldName = fieldData['football_field_name'] ?? 'Match Recording';
            }
          } catch (_) {}
        }

        // Format date
        String dateStr = '';
        String timeStr = '';
        final startTime = schedule['start_time'] as String?;
        if (startTime != null) {
          try {
            final start = DateTime.parse(startTime).toLocal();
            dateStr = DateFormat('MMM d, yyyy').format(start);
            timeStr = DateFormat('h:mm a').format(start);
          } catch (_) {}
        }

        recordings.add({
          'id': schedule['id'],
          'field_name': fieldName,
          'date': dateStr,
          'time': timeStr,
          'status': schedule['status'],
          'thumbnail_url': thumbnailUrl,
          'video_url': videoUrl,
          'total_chunks': schedule['total_chunks'] ?? chunks.length,
          'uploaded_chunks': uploadedChunks,
          'processed_chunks': processedChunks,
        });
      }

      if (mounted) {
        setState(() {
          _recordings = recordings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a1a),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PAST RECORDINGS',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRecordings,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _recordings.isEmpty
                  ? _buildEmpty()
                  : _buildRecordingsList(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF00BF63)),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.red, size: 60),
          const SizedBox(height: 20),
          Text(
            'Failed to load recordings',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? '',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _loadRecordings,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BF63)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, color: Colors.white24, size: 100),
          const SizedBox(height: 30),
          Text(
            'No Recordings Yet',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'Book a match to get your first\nAI-powered recording!',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 12,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _recordings.length,
      itemBuilder: (context, index) => _buildRecordingCard(_recordings[index]),
    );
  }

  Widget _buildRecordingCard(Map<String, dynamic> recording) {
    final status = recording['status'] as String?;
    final thumbnailUrl = recording['thumbnail_url'] as String?;
    final videoUrl = recording['video_url'] as String?;
    final isCompleted = status == 'completed';
    
    return GestureDetector(
      onTap: () {
        if (videoUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                videoUrl: videoUrl,
                title: recording['field_name'] ?? 'Recording',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video not ready yet - Status: ${status ?? "unknown"}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor(status).withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getStatusColor(status).withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // THUMBNAIL
              if (thumbnailUrl != null)
                Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(status),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildPlaceholder(status);
                  },
                )
              else
                _buildPlaceholder(status),
              
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              
              // Status badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _getStatusText(status),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Play button (if completed)
              if (isCompleted && videoUrl != null)
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.black, size: 40),
                  ),
                ),
              
              // Bottom info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recording['field_name'] ?? 'Recording',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white54, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            recording['date'] ?? '',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time, color: Colors.white54, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            recording['time'] ?? '',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String? status) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getStatusColor(status).withOpacity(0.3),
            const Color(0xFF1a1a1a),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.sports_soccer,
          color: Colors.white24,
          size: 60,
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return const Color(0xFF00BF63);
      case 'processing': return Colors.orange;
      case 'recording': return Colors.red;
      case 'uploading': return Colors.blue;
      default: return Colors.blueGrey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'completed': return 'READY';
      case 'processing': return 'PROCESSING';
      case 'recording': return 'LIVE';
      case 'uploading': return 'UPLOADING';
      default: return 'PENDING';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'completed': return Icons.check_circle;
      case 'processing': return Icons.auto_awesome;
      case 'recording': return Icons.fiber_manual_record;
      case 'uploading': return Icons.cloud_upload;
      default: return Icons.schedule;
    }
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// APP AWARENESS SCREEN - Animated promo to download the app
// ═══════════════════════════════════════════════════════════════════════════════
class AppAwarenessScreen extends StatefulWidget {
  const AppAwarenessScreen({super.key});

  @override
  State<AppAwarenessScreen> createState() => _AppAwarenessScreenState();
}

class _AppAwarenessScreenState extends State<AppAwarenessScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  int _currentPhase = 0;
  Timer? _phaseTimer;

  // Animation phases for 30-second loop
  final List<Map<String, dynamic>> _phases = [
    {'duration': 6, 'type': 'logo'},           // Show Playmaker logo
    {'duration': 8, 'type': 'message1'},       // Book & get recorded
    {'duration': 8, 'type': 'message2'},       // 30 minutes processing
    {'duration': 8, 'type': 'download'},       // Download now + stores
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0,
    );
    
    _startPhaseLoop();
  }

  void _startPhaseLoop() {
    _slideController.forward();
    _scheduleNextPhase();
  }

  void _scheduleNextPhase() {
    final phase = _phases[_currentPhase];
    _phaseTimer = Timer(Duration(seconds: phase['duration'] as int), () {
      if (mounted) {
        _fadeController.reverse().then((_) {
          setState(() {
            _currentPhase = (_currentPhase + 1) % _phases.length;
          });
          _slideController.reset();
          _slideController.forward();
          _fadeController.forward();
          _scheduleNextPhase();
        });
      }
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Animated background
            _buildAnimatedBackground(),
            
            // Content based on phase
            FadeTransition(
              opacity: _fadeController,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _slideController,
                  curve: Curves.easeOutCubic,
                )),
                child: _buildPhaseContent(),
              ),
            ),
            
            // Always visible: Tap to go back hint
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Tap anywhere to go back',
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                const Color(0xFF00BF63).withOpacity(0.15 + _pulseController.value * 0.1),
                const Color(0xFF0a0a0a),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhaseContent() {
    final phase = _phases[_currentPhase];
    switch (phase['type']) {
      case 'logo':
        return _buildLogoPhase();
      case 'message1':
        return _buildMessage1Phase();
      case 'message2':
        return _buildMessage2Phase();
      case 'download':
        return _buildDownloadPhase();
      default:
        return _buildLogoPhase();
    }
  }

  Widget _buildLogoPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big animated logo
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF63),
                  borderRadius: BorderRadius.circular(45),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BF63).withOpacity(0.5 + _pulseController.value * 0.3),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  color: Colors.white,
                  size: 100,
                ),
              );
            },
          ),
          const SizedBox(height: 50),
          
          Text(
            'PLAYMAKER',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00BF63), width: 2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              'AI-POWERED MATCH RECORDING',
              style: GoogleFonts.inter(
                color: const Color(0xFF00BF63),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage1Phase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Phone icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF00BF63).withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF00BF63), width: 3),
              ),
              child: const Icon(
                Icons.phone_android,
                color: Color(0xFF00BF63),
                size: 70,
              ),
            ),
            const SizedBox(height: 50),
            
            Text(
              'BOOK THROUGH',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00BF63), Color(0xFF00E676)],
              ).createShader(bounds),
              child: Text(
                'PLAYMAKER APP',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            Text(
              'And get your match',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam, color: Color(0xFF00BF63), size: 40),
                const SizedBox(width: 15),
                Text(
                  'RECORDED',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF00BF63),
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage2Phase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Clock icon with animation
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.2),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5 + _pulseController.value * 0.5),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(_pulseController.value * 0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.timer,
                  color: Colors.orange,
                  size: 80,
                ),
              );
            },
          ),
          const SizedBox(height: 50),
          
          Text(
            'YOUR VIDEO READY IN',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 15),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '30',
                style: GoogleFonts.inter(
                  color: Colors.orange,
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  ' MINUTES',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Text(
            'After your booking ends',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 30),
          
          // AI badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00BF63).withOpacity(0.3),
                  Colors.blue.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
                const SizedBox(width: 10),
                Text(
                  'AI Ball Tracking Camera',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
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

  Widget _buildDownloadPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'DOWNLOAD NOW',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 50),
          
          // App Store & Play Store
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStoreBadge(
                icon: Icons.apple,
                store: 'App Store',
                color: Colors.white,
              ),
              const SizedBox(width: 30),
              _buildStoreBadge(
                icon: Icons.shop,
                store: 'Google Play',
                color: const Color(0xFF00BF63),
              ),
            ],
          ),
          
          const SizedBox(height: 60),
          
          // Social media
          Text(
            'FOLLOW US',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialBadge(
                icon: Icons.camera_alt,
                platform: 'Instagram',
                color: const Color(0xFFE4405F),
              ),
              const SizedBox(width: 25),
              _buildSocialBadge(
                icon: Icons.music_note,
                platform: 'TikTok',
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 25),
          
          // Username
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alternate_email, color: Color(0xFF00BF63), size: 28),
                const SizedBox(width: 12),
                Text(
                  'playmakerapp.eg',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreBadge({
    required IconData icon,
    required String store,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
          decoration: BoxDecoration(
            color: color == Colors.white ? Colors.white : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: color.withOpacity(0.5 + _pulseController.value * 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: color == Colors.white ? Colors.black : color,
                size: 40,
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Download on',
                    style: GoogleFonts.inter(
                      color: color == Colors.white ? Colors.black54 : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    store,
                    style: GoogleFonts.inter(
                      color: color == Colors.white ? Colors.black : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSocialBadge({
    required IconData icon,
    required String platform,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Text(
            platform,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// AL BASEET PROMO SCREEN - Animated e-commerce product showcase
// ═══════════════════════════════════════════════════════════════════════════════
class AlBaseetPromoScreen extends StatefulWidget {
  const AlBaseetPromoScreen({super.key});

  @override
  State<AlBaseetPromoScreen> createState() => _AlBaseetPromoScreenState();
}

class _AlBaseetPromoScreenState extends State<AlBaseetPromoScreen> with TickerProviderStateMixin {
  int _activeIndex = 0;
  Timer? _cycleTimer;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _ctaController;
  late AnimationController _parallaxController;

  final List<Map<String, String>> _products = [
    {'image': 'assets/images/albassetpromoimage1.png', 'name': 'Court Tennis Balls', 'price': 'EGP 450'},
    {'image': 'assets/images/albaseetpromoimage2.png', 'name': 'Pro Sports Bag', 'price': 'EGP 2,850'},
    {'image': 'assets/images/albassetpromoimage3.png', 'name': 'Padel Racket Pro', 'price': 'EGP 4,200'},
  ];

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _ctaController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _parallaxController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 500), () => _ctaController.forward());
    _startCycle();
  }

  void _startCycle() {
    _cycleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _scaleController.reverse().then((_) {
          setState(() => _activeIndex = (_activeIndex + 1) % _products.length);
          _scaleController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _scaleController.dispose();
    _glowController.dispose();
    _ctaController.dispose();
    _parallaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFCD3A),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Solid yellow background - no gradient
            Container(
              color: const Color(0xFFFFCD3A),
            ),
            
            // Subtle decorative circle (very subtle)
            Positioned(
              top: -150,
              right: -150,
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) => Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08 + _glowController.value * 0.05),
                  ),
                ),
              ),
            ),
            // Another subtle circle bottom left
            Positioned(
              bottom: -100,
              left: -100,
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) => Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06 + _glowController.value * 0.04),
                  ),
                ),
              ),
            ),
            
            // Main content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo and header
                  _buildHeader(),
                  const Spacer(),
                  // Product cards
                  _buildProductGrid(),
                  const Spacer(),
                  // CTA
                  _buildCTA(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Bigger logo - no background container, just the logo on yellow
        Image.asset('assets/images/albaseetlogo.png', height: 150),
        const SizedBox(height: 20),
        Text('PREMIUM SPORTS GEAR',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 5,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_products.length, (index) => _buildProductCard(index)),
      ),
    );
  }

  Widget _buildProductCard(int index) {
    final isActive = index == _activeIndex;
    final product = _products[index];
    
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _glowController]),
      builder: (context, child) {
        double scale = 1.0;
        double opacity = 0.7;
        double glowOpacity = 0.0;
        
        if (isActive) {
          scale = 1.0 + (_scaleController.value * 0.15);
          opacity = 1.0;
          glowOpacity = 0.5 + (_glowController.value * 0.3);
        }
        
        return Transform.scale(
          scale: scale,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: opacity,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: isActive ? Border.all(color: Colors.black12, width: 2) : null,
                boxShadow: [
                  BoxShadow(
                    color: isActive 
                      ? Colors.white.withOpacity(glowOpacity)
                      : Colors.black.withOpacity(0.15),
                    blurRadius: isActive ? 50 : 20,
                    spreadRadius: isActive ? 8 : 0,
                    offset: const Offset(0, 10),
                  ),
                  if (isActive) BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 150,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset(product['image']!, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    product['name']!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['price']!,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCTA() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctaController, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(
        opacity: _ctaController,
        child: Padding(
          padding: const EdgeInsets.only(right: 50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Showroom around the corner',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visit us today',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// AD VIDEO SCREEN - Sponsor logos + looping promo video
// ═══════════════════════════════════════════════════════════════════════════════
class AdVideoScreen extends StatefulWidget {
  const AdVideoScreen({super.key});

  @override
  State<AdVideoScreen> createState() => _AdVideoScreenState();
}

class _AdVideoScreenState extends State<AdVideoScreen> with TickerProviderStateMixin {
  int _currentPhase = 0;
  Timer? _phaseTimer;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: 1.0);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _startPhaseSequence();
    _preloadVideo();
  }

  void _preloadVideo() async {
    try {
      print('🎬 Starting video preload...');
      _videoController = VideoPlayerController.asset('assets/images/promo_video.mp4');
      
      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Video initialization timed out');
        },
      );
      
      // Configure for Android TV
      _videoController!.setLooping(true);
      _videoController!.setVolume(1.0);
      
      print('✅ Video initialized: ${_videoController!.value.size}');
      print('   Duration: ${_videoController!.value.duration}');
      
      if (mounted) {
        setState(() => _videoInitialized = true);
      }
    } catch (e) {
      print('❌ Video preload error: $e');
      if (mounted) {
        setState(() => _videoError = true);
      }
    }
  }

  void _startPhaseSequence() {
    _scheduleNextPhase();
  }

  void _scheduleNextPhase() {
    // Loop through phases 0, 1, 2, 3 (BePro, Albaseet, AlBaseetSports, Playmaker) then show video
    final duration = _currentPhase == 2 ? 12 : 8; // Longer for AlBaseetSports (phase 2)
    _phaseTimer = Timer(Duration(seconds: duration), () {
      if (mounted) {
        _fadeController.reverse().then((_) {
          if (_currentPhase < 4) {
            setState(() => _currentPhase++);
            _fadeController.forward();
            if (_currentPhase < 4) {
              _scheduleNextPhase();
            } else {
              // Phase 4 is video - try to play it
              _playVideo();
            }
          }
        });
      }
    });
  }
  
  void _playVideo() {
    if (_videoInitialized && _videoController != null) {
      print('🎬 Playing video...');
      _videoController!.seekTo(Duration.zero);
      _videoController!.play();
      
      // Listen for playback state
      _videoController!.addListener(_videoListener);
    } else {
      print('⚠️ Video not ready - initialized: $_videoInitialized');
    }
  }
  
  void _videoListener() {
    if (_videoController != null && mounted) {
      // Rebuild to update play/pause state
      setState(() {});
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (_currentPhase) {
      case 0: return Colors.white;           // BePro
      case 1: return const Color(0xFFFFD700); // Albaseet logo
      case 2: return const Color(0xFFFFCD3A); // AlBaseet Sports
      case 3: return const Color(0xFF0a0a0a); // Playmaker
      default: return Colors.black;           // Video
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: FadeTransition(opacity: _fadeController, child: _buildCurrentPhase()),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    switch (_currentPhase) {
      case 0: return _buildBeProPhase();
      case 1: return _buildAlbaseetPhase();
      case 2: return _buildAlBaseetSportsPhase();
      case 3: return _buildPlaymakerPhase();
      default: return _buildVideoPhase();
    }
  }

  Widget _buildAlBaseetSportsPhase() {
    // Simplified Al Baseet Sports showcase
    return Container(
      color: const Color(0xFFFFCD3A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1 + _pulseController.value * 0.05),
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset('assets/images/albaseetlogo.png', height: 180),
                const SizedBox(height: 30),
                Text('PREMIUM SPORTS GEAR',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
                // Product images row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildProductImage('assets/images/albassetpromoimage1.png'),
                    _buildProductImage('assets/images/albaseetpromoimage2.png'),
                    _buildProductImage('assets/images/albassetpromoimage3.png'),
                  ],
                ),
                const SizedBox(height: 40),
                // CTA
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text('Showroom around the corner',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  Widget _buildProductImage(String path) {
    return Container(
      width: 200,
      height: 200,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(path, fit: BoxFit.contain),
    );
  }

  Widget _buildBeProPhase() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Image.asset('assets/images/beprologo.png', width: 400, height: 400, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildAlbaseetPhase() {
    return Container(
      color: const Color(0xFFFFD700),
      child: Center(
        child: Image.asset('assets/images/albaseetlogo.png', width: 500, height: 500, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildPlaymakerPhase() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(center: Alignment.center, radius: 1.5, colors: [const Color(0xFF00BF63).withOpacity(0.2), const Color(0xFF0a0a0a)]),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Playmaker Logo - big and prominent
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(55),
                    boxShadow: [BoxShadow(color: const Color(0xFF00BF63).withOpacity(0.5 + _pulseController.value * 0.3), blurRadius: 60, spreadRadius: 20)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(55),
                    child: Image.asset('assets/images/playmakerappicon.png', fit: BoxFit.cover),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // Match AI Recording text
            Text('MATCH AI RECORDING', style: GoogleFonts.inter(color: const Color(0xFF00BF63), fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 4)),
            const SizedBox(height: 40),
            // Store badges image
            Image.asset('assets/images/store_badges_combined.png', height: 140, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }


  Widget _buildVideoPhase() {
    if (_videoError || !_videoInitialized || _videoController == null) {
      // Show replay button if video failed
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [const Color(0xFF00BF63).withOpacity(0.2), const Color(0xFF0a0a0a)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.replay, color: Color(0xFF00BF63), size: 100),
              const SizedBox(height: 30),
              Text('Tap to restart', style: GoogleFonts.inter(color: Colors.white54, fontSize: 20)),
              const SizedBox(height: 50),
              GestureDetector(
                onTap: () {
                  // Restart the ad loop
                  setState(() => _currentPhase = 0);
                  _fadeController.forward();
                  _scheduleNextPhase();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BF63),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text('REPLAY ADS', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Video with play button overlay
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
        // Play/Pause button overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BF63).withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BF63).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 70),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Restart button at bottom
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () {
                _videoController?.pause();
                setState(() => _currentPhase = 0);
                _fadeController.forward();
                _scheduleNextPhase();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFF00BF63), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.replay, color: Color(0xFF00BF63), size: 24),
                    const SizedBox(width: 10),
                    Text('REPLAY ADS', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// VIDEO PLAYER SCREEN - Plays a recording video with nice fallback
// ═══════════════════════════════════════════════════════════════════════════════
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initVideo();
  }

  Future<void> _initVideo() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('🎬 Loading recording: ${widget.videoUrl}');
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await controller.initialize().timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
        controller.play();
        print('✅ Recording playing!');
      }
    } catch (e) {
      print('❌ Recording failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoading()
          : _hasError
              ? _buildNiceError()
              : _buildVideoPlayer(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00BF63)),
          const SizedBox(height: 20),
          Text(
            'Loading your match...',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNiceError() {
    // Show a nice "coming soon" style message instead of ugly error
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                const Color(0xFF00BF63).withOpacity(0.2 + _pulseController.value * 0.1),
                Colors.black,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF63).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF00BF63).withOpacity(0.5 + _pulseController.value * 0.3),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.cloud_download,
                  color: Color(0xFF00BF63),
                  size: 60,
                ),
              ),
              const SizedBox(height: 40),
              
              // Title
              Text(
                'Video Processing',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 15),
              
              // Message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Your match recording is being processed by our AI.\nIt will be available for streaming soon!',
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Info box
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white38, size: 24),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'Check back in a few minutes or visit the Playmaker app to download.',
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Back button
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('GO BACK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BF63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // FULL SCREEN VIDEO
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          
          // Play/Pause indicator
          Center(
            child: AnimatedOpacity(
              opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
              ),
            ),
          ),
          
          // Video progress bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF00BF63),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
