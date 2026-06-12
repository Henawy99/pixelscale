import 'dart:async'; // For Future.delayed
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:animight/connect_dialog.dart'; // Import the new dialog
import 'package:animight/control_screen.dart'; // Import the control screen
import 'dart:ui'; // For BackdropFilter
import 'package:shimmer/shimmer.dart';
import 'package:animight/connection_banner.dart'; // Import the banner
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For json.decode and json.encode
import 'package:animight/ble_service.dart'; // Import BLE service

class Wallpaper {
  final String assetPath;
  final String name;
  final String bluetoothName;
  final bool isComingSoon;

  Wallpaper({
    required this.assetPath,
    required this.name,
    required this.bluetoothName,
    this.isComingSoon = false,
  });

  // For saving to SharedPreferences
  Map<String, dynamic> toJson() => {
        'assetPath': assetPath,
        'name': name,
        'bluetoothName': bluetoothName,
        'isComingSoon': isComingSoon,
      };

  // For loading from SharedPreferences
  factory Wallpaper.fromJson(Map<String, dynamic> json) => Wallpaper(
        assetPath: json['assetPath'],
        name: json['name'],
        bluetoothName: json['bluetoothName'],
        isComingSoon: json['isComingSoon'] ?? false,
      );
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  final List<Wallpaper> _wallpaperAssets = [
    Wallpaper(assetPath: 'assets/wallpaper0.jpeg', name: 'JinX_Unleashed', bluetoothName: 'JinX_Unleashed'),
    Wallpaper(assetPath: 'assets/wallpaper1.PNG', name: 'Cyberpunk_City', bluetoothName: 'Cyberpunk_City'),
    Wallpaper(assetPath: 'assets/wallpaper4.PNG', name: 'Naruto-X-Kyuubi', bluetoothName: 'Naruto-X-Kyuubi'),
    Wallpaper(assetPath: 'assets/wallpaper5.JPEG', name: 'GT-R_City_lights', bluetoothName: 'GT-R_City_lights'),
    Wallpaper(assetPath: 'assets/wallpaper7.jpg', name: 'Obanai_awakened', bluetoothName: 'Obanai_awakened'),
    Wallpaper(assetPath: 'assets/wallpaper2.JPEG', name: 'Anime_Glow', bluetoothName: 'Anime_Glow', isComingSoon: true),
    Wallpaper(assetPath: 'assets/wallpaper6.PNG', name: 'Demon_Slayer_Art', bluetoothName: 'Demon_Slayer_Art', isComingSoon: true),
  ];

  List<Wallpaper> _myCollection = [];
  bool _isConnecting = false;
  String _tappedWallpaperPath = '';
  late AnimationController _cardTapController;
  late Animation<double> _cardScaleAnimation;
  int _tappedIndex = -1;

  int _selectedTabIndex = 0; // 0: Home/Scan, 1: Trending, 2: My Collection

  @override
  void initState() {
    super.initState();
    _loadCollection();
    _videoController = VideoPlayerController.asset('assets/backgroundvideo.mov')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
      }).catchError((error) {
        // ignore: avoid_print
        print("Error initializing video: $error");
      });
    _cardTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _cardScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_cardTapController);
  }

  Future<void> _loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionJson = prefs.getStringList('myCollection') ?? [];
    setState(() {
      _myCollection = collectionJson.map((jsonString) => Wallpaper.fromJson(json.decode(jsonString))).toList();
    });
  }

  Future<void> _saveCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionJson = _myCollection.map((wallpaper) => json.encode(wallpaper.toJson())).toList();
    await prefs.setStringList('myCollection', collectionJson);
  }

  void _showConnectDialog(BuildContext context, String imagePath) {
    _tappedWallpaperPath = imagePath; // Store the path
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return ConnectDialog(
          onConnectionAttempted: (bool success, String method, String? deviceName) {
            Navigator.of(dialogContext).pop(); // Close the dialog
            if (success) {
              _startConnectionProcess(navigateToControlScreen: true);

              if (deviceName != null) {
                final matchedWallpaper = _wallpaperAssets.firstWhere(
                  (wallpaper) => wallpaper.bluetoothName == deviceName,
                  orElse: () => Wallpaper(assetPath: '', name: '', bluetoothName: ''), // Return a dummy wallpaper
                );

                if (matchedWallpaper.assetPath.isNotEmpty && !_myCollection.any((w) => w.assetPath == matchedWallpaper.assetPath)) {
                  setState(() {
                    _myCollection.add(matchedWallpaper);
                    _saveCollection();
                  });
                }
              }
            } else {
              // Handle any connection failure
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to connect via $method.')),
              );
            }
          },
        );
      },
    );
  }

  void _startConnectionProcess({required bool navigateToControlScreen}) {
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
    });

    // Simulate connection delay or actual connection process feedback
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
      if (navigateToControlScreen) {
        // If no wallpaper was tapped (e.g., connected from the main scan button),
        // use a default background for the control screen.
        final String backgroundPath = _tappedWallpaperPath.isNotEmpty
            ? _tappedWallpaperPath
            : 'assets/wallpaper0.jpeg'; // Default wallpaper

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ControlScreen(backgroundImagePath: backgroundPath),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content stack
          Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Video Background
              FittedBox(
                fit: BoxFit.cover,
                child: _videoController.value.isInitialized
                    ? SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      )
                    : Container(
                        color: Colors.black,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
              ),
            ],
          ),
          // UI Overlay
          SafeArea(
            child: Column(
              children: <Widget>[
                // Connection Banner is now at the top of the main layout
                const ConnectionBanner(),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _buildCustomTabBar(),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(scale: animation, child: child),
                            );
                          },
                          child: _buildCurrentView(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Connecting Progress Indicator Overlay
          if (_isConnecting)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowy Progress Indicator
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.8),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const SizedBox(
                        width: 70,
                        height: 70,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                          strokeWidth: 7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Shimmer.fromColors(
                      baseColor: Colors.cyanAccent,
                      highlightColor: Colors.pinkAccent,
                      child: const Text(
                        "Connecting...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 16)],
                        ),
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

  Widget _buildCustomTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          GestureDetector(
            onTap: () => setState(() {
              _selectedTabIndex = 0;
            }),
            child: _buildTab('Home', isSelected: _selectedTabIndex == 0),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedTabIndex = 1;
            }),
            child: _buildTab('Trending', isSelected: _selectedTabIndex == 1),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedTabIndex = 2;
            }),
            child: _buildTab('My Collection', isSelected: _selectedTabIndex == 2),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildScanView();
      case 1:
        return _buildWallpaperGridView();
      case 2:
        return _buildMyCollectionView();
      default:
        return _buildScanView();
    }
  }

  Widget _buildScanView() {
    return Center(
      key: const ValueKey('scan_view'),
      child: ScanButton(
        onTap: () => _showConnectDialog(context, ''), // Pass context and empty path
      ),
    );
  }

  Widget _buildWallpaperGridView() {
    return GridView.builder(
      key: const ValueKey('wallpaper_grid'),
      padding: const EdgeInsets.all(8.0), // Revert to simple padding
      itemCount: _wallpaperAssets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final wallpaper = _wallpaperAssets[index];
          return AnimatedBuilder(
            animation: _cardTapController,
            builder: (context, child) {
              final isTapped = _tappedIndex == index;
              return Transform.scale(
                scale: isTapped ? _cardScaleAnimation.value : 1.0,
                child: _WallpaperCard(
                  wallpaper: wallpaper,
                  onTap: () => _onWallpaperTap(index, wallpaper.assetPath),
                  glowColor: Colors.cyanAccent,
                ),
              );
            },
          );
        },
    );
  }

  Widget _buildMyCollectionView() {
    if (_myCollection.isEmpty) {
      return Center(
        child: Text(
          'Your collected wallpapers will appear here.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            shadows: [
              const Shadow(color: Colors.cyanAccent, blurRadius: 8),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      key: const ValueKey('collection_grid'),
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        itemCount: _myCollection.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final wallpaper = _myCollection[index];
          return _WallpaperCard(
            wallpaper: wallpaper,
            onTap: () => _reconnectToDevice(wallpaper),
            glowColor: Colors.pinkAccent, // Different glow for collection items
          );
        },
      ),
    );
  }

  void _reconnectToDevice(Wallpaper wallpaper) async {
    setState(() {
      _tappedWallpaperPath = wallpaper.assetPath;
      _isConnecting = true;
    });

    // Show a message to the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attempting to reconnect to ${wallpaper.bluetoothName}...')),
    );

    bool success = await bleService.scanAndConnect(wallpaper.bluetoothName);

    if (!mounted) return;

    setState(() {
      _isConnecting = false;
    });

    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ControlScreen(backgroundImagePath: _tappedWallpaperPath),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reconnect to ${wallpaper.bluetoothName}.')),
      );
    }
  }

  Widget _buildTab(String text, {bool isSelected = false}) {
    return CustomPaint(
      painter: FuturisticTabPainter(isSelected: isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
            shadows: isSelected
                ? [const Shadow(color: Colors.cyanAccent, blurRadius: 12)]
                : [],
          ),
        ),
      ),
    );
  }

  void _onWallpaperTap(int index, String imagePath) async {
    setState(() {
      _tappedIndex = index;
    });
    await _cardTapController.reverse();
    await _cardTapController.forward();
    _showConnectDialog(context, imagePath);
  }

  @override
  void dispose() {
    _videoController.dispose();
    _cardTapController.dispose();
    super.dispose();
  }
}

class FuturisticTabPainter extends CustomPainter {
  final bool isSelected;

  FuturisticTabPainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const cornerSize = 10.0;

    // Create a sharp, angular path for the tab
    path.moveTo(cornerSize, 0);
    path.lineTo(size.width - cornerSize, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - cornerSize, size.height);
    path.lineTo(cornerSize, size.height);
    path.lineTo(0, size.height / 2);
    path.close();

    if (isSelected) {
      // Draw a filled, glowing tab for the selected state
      final fillPaint = Paint()..color = Colors.cyanAccent.withOpacity(0.15);
      final glowPaint = Paint()
        ..color = Colors.cyanAccent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, fillPaint);
    } else {
      // Draw a subtle, outlined tab for unselected states
      final strokePaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant FuturisticTabPainter oldDelegate) {
    return isSelected != oldDelegate.isSelected;
  }
}


class ScanButton extends StatefulWidget {
  final VoidCallback onTap;

  const ScanButton({super.key, required this.onTap});

  @override
  State<ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<ScanButton> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _tapController;
  late AnimationController _flareController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _flareAnimation;

  @override
  void initState() {
    super.initState();
    // Controller for the orbital rings
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 15))
      ..repeat();
      
    // Controller for the tap animation
    _tapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));

    // Controller for the flare effect on tap
    _flareController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _flareAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _flareController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _tapController.dispose();
    _flareController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _tapController.forward();
    _flareController.forward(from: 0.0);
  }

  void _onTapUp(TapUpDetails details) {
    _tapController.reverse();
    widget.onTap();
  }
  
  void _onTapCancel() {
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 280,
          height: 280,
          child: AnimatedBuilder(
            animation: Listenable.merge([_rotationController, _flareController]),
            builder: (context, child) {
              return CustomPaint(
                painter: FuturisticOrbPainter(
                  rotationProgress: _rotationController.value,
                  flareProgress: _flareAnimation.value,
                ),
                child: Center(
                  child: Shimmer.fromColors(
                    baseColor: Colors.cyanAccent,
                    highlightColor: Colors.pinkAccent,
                    period: const Duration(seconds: 3),
                    child: const Text(
                      'SCAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: Colors.cyanAccent, blurRadius: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}


class FuturisticOrbPainter extends CustomPainter {
  final double rotationProgress;
  final double flareProgress;

  FuturisticOrbPainter({
    required this.rotationProgress,
    required this.flareProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final coreRadius = radius * 0.7;

    // Draw orbital rings first
    _drawOrbitalRings(canvas, size, center, radius);

    // Draw the solid button core with a glow
    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);
    canvas.drawCircle(center, coreRadius, glowPaint);
    
    final corePaint = Paint()..color = Colors.black.withOpacity(0.8);
    canvas.drawCircle(center, coreRadius, corePaint);
    
    // Draw a subtle radial gradient on the core for depth
    final coreSurfacePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.05), Colors.transparent],
        stops: const [0.0, 0.7],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));
    canvas.drawCircle(center, coreRadius, coreSurfacePaint);


    // Draw the tap flare shockwave
    if (flareProgress > 0) {
      final flareOpacity = (1.0 - flareProgress).clamp(0.0, 1.0);
      final flarePaint = Paint()
        ..color = Colors.white.withOpacity(flareOpacity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (flareProgress * 3.0);
      canvas.drawCircle(center, coreRadius + (flareProgress * radius * 0.3), flarePaint);
    }
  }

  void _drawOrbitalRings(Canvas canvas, Size size, Offset center, double radius) {
    // Ring 1: Solid Gradient Ring
    final rect1 = Rect.fromCircle(center: center, radius: radius * 0.9);
    final gradientPaint1 = Paint()
      ..shader = SweepGradient(
        colors: [Colors.cyanAccent, Colors.transparent, Colors.pinkAccent, Colors.transparent, Colors.cyanAccent],
        stops: const [0.0, 0.4, 0.5, 0.9, 1.0],
        transform: GradientRotation(rotationProgress * 2 * math.pi),
      ).createShader(rect1)
      ..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * 0.9, gradientPaint1);

    // Ring 2: Solid counter-rotating ring
    final paint2 = Paint()..color = Colors.cyanAccent.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rotationProgress * 4 * math.pi);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(center, radius, paint2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _WallpaperCard extends StatelessWidget {
  final Wallpaper wallpaper;
  final VoidCallback onTap;
  final Color glowColor;

  const _WallpaperCard({required this.wallpaper, required this.onTap, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: wallpaper.isComingSoon ? null : onTap,
      child: Hero(
        tag: wallpaper.assetPath,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 10.0,
          shadowColor: glowColor.withOpacity(0.7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.7),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  wallpaper.assetPath,
                  fit: BoxFit.cover,
                ),
              ),
              // Gradient overlay for text visibility
              Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16.0)),
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
              // Wallpaper Name
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Text(
                  wallpaper.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [
                      Shadow(color: glowColor, blurRadius: 8),
                    ],
                  ),
                ),
              ),
              // "Coming Soon" Overlay
              if (wallpaper.isComingSoon)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Center(
                    child: Text(
                      'COMING SOON',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        shadows: [
                          const Shadow(color: Colors.cyanAccent, blurRadius: 16),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
