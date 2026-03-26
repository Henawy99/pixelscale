import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:animight/connect_dialog.dart';
import 'package:animight/control_screen.dart';
import 'package:animight/admin_screen.dart';
import 'package:animight/supabase_service.dart';
import 'dart:ui';
import 'package:shimmer/shimmer.dart';
import 'package:animight/connection_banner.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:animight/ble_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Wallpaper {
  final String assetPath;   // local asset path (empty for remote)
  final String imageUrl;    // remote URL (empty for local)
  final String name;
  final String bluetoothName;
  final bool isComingSoon;
  final bool isRemote;
  final String? remoteId;

  Wallpaper({
    this.assetPath = '',
    this.imageUrl = '',
    required this.name,
    required this.bluetoothName,
    this.isComingSoon = false,
    this.isRemote = false,
    this.remoteId,
  });

  Map<String, dynamic> toJson() => {
        'assetPath': assetPath,
        'imageUrl': imageUrl,
        'name': name,
        'bluetoothName': bluetoothName,
        'isComingSoon': isComingSoon,
        'isRemote': isRemote,
      };

  factory Wallpaper.fromJson(Map<String, dynamic> json) => Wallpaper(
        assetPath: json['assetPath'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        name: json['name'],
        bluetoothName: json['bluetoothName'],
        isComingSoon: json['isComingSoon'] ?? false,
        isRemote: json['isRemote'] ?? false,
      );

  factory Wallpaper.fromSupabase(Map<String, dynamic> row) => Wallpaper(
        imageUrl: row['image_url'] ?? '',
        name: row['name'] ?? '',
        bluetoothName: row['bluetooth_name'] ?? '',
        isComingSoon: row['is_coming_soon'] ?? false,
        isRemote: true,
        remoteId: row['id'],
      );

  String get displayImagePath => isRemote ? imageUrl : assetPath;
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;

  static final List<Wallpaper> _localWallpapers = [
    Wallpaper(assetPath: 'assets/wallpaper0.jpeg', name: 'JinX_Unleashed', bluetoothName: 'JinX_Unleashed'),
    Wallpaper(assetPath: 'assets/wallpaper1.PNG', name: 'Cyberpunk_City', bluetoothName: 'Cyberpunk_City'),
    Wallpaper(assetPath: 'assets/wallpaper4.PNG', name: 'Naruto-X-Kyuubi', bluetoothName: 'Naruto-X-Kyuubi'),
    Wallpaper(assetPath: 'assets/wallpaper5.JPEG', name: 'GT-R_City_lights', bluetoothName: 'GT-R_City_lights'),
    Wallpaper(assetPath: 'assets/wallpaper7.jpg', name: 'Obanai_awakened', bluetoothName: 'Obanai_awakened'),
    Wallpaper(assetPath: 'assets/wallpaper8.jpg', name: 'Wallpaper_8', bluetoothName: 'Wallpaper_8'),
    Wallpaper(assetPath: 'assets/wallpaper2.JPEG', name: 'Anime_Glow', bluetoothName: 'Anime_Glow', isComingSoon: true),
    Wallpaper(assetPath: 'assets/wallpaper6.PNG', name: 'Demon_Slayer_Art', bluetoothName: 'Demon_Slayer_Art', isComingSoon: true),
  ];

  List<Wallpaper> _remoteWallpapers = [];
  List<Wallpaper> get _allWallpapers => [..._localWallpapers, ..._remoteWallpapers];

  List<Wallpaper> _myCollection = [];
  bool _isConnecting = false;
  String _tappedWallpaperPath = '';
  late AnimationController _cardTapController;
  late Animation<double> _cardScaleAnimation;
  int _tappedIndex = -1;

  int _selectedTabIndex = 0;

  // Hidden admin access via 5 taps on "My Collection" tab
  int _myCollectionTapCount = 0;
  Timer? _myCollectionTapTimer;

  void _onMyCollectionTap() {
    setState(() => _selectedTabIndex = 2);
    _myCollectionTapCount++;
    _myCollectionTapTimer?.cancel();
    if (_myCollectionTapCount >= 5) {
      _myCollectionTapCount = 0;
      Future.microtask(() => _showPasscodeDialog());
    } else {
      _myCollectionTapTimer = Timer(const Duration(seconds: 3), () {
        _myCollectionTapCount = 0;
      });
    }
  }

  void _showPasscodeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _PasscodeDialog(),
    ).then((granted) {
      if (granted == true) _openAdmin();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCollection();
    _loadRemoteWallpapers();
    recordVisit();
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
    if (mounted) {
      setState(() {
        _myCollection = collectionJson
            .map((s) => Wallpaper.fromJson(json.decode(s)))
            .toList();
      });
    }
  }

  Future<void> _saveCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionJson =
        _myCollection.map((w) => json.encode(w.toJson())).toList();
    await prefs.setStringList('myCollection', collectionJson);
  }

  Future<void> _loadRemoteWallpapers() async {
    final rows = await fetchRemoteWallpapers();
    if (mounted) {
      setState(() {
        _remoteWallpapers = rows.map((r) => Wallpaper.fromSupabase(r)).toList();
      });
    }
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
                final matchedWallpaper = _localWallpapers.firstWhere(
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
                const ConnectionBanner(),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _buildTabBarWithAdmin(),
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

  Widget _buildTabBarWithAdmin() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = 0),
            child: _buildTab('Home', isSelected: _selectedTabIndex == 0),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = 1),
            child: _buildTab('Trending', isSelected: _selectedTabIndex == 1),
          ),
          GestureDetector(
            onTap: _onMyCollectionTap,
            child: _buildTab('My Collection', isSelected: _selectedTabIndex == 2),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdmin() async {
    // Auto sign-in as admin
    final ok = await signInAsAdmin();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin sign-in failed.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminScreen()),
    );
    // Refresh remote wallpapers after returning from admin
    _loadRemoteWallpapers();
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
      itemCount: _allWallpapers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final wallpaper = _allWallpapers[index];
          return AnimatedBuilder(
            animation: _cardTapController,
            builder: (context, child) {
              final isTapped = _tappedIndex == index;
              return Transform.scale(
                scale: isTapped ? _cardScaleAnimation.value : 1.0,
                child: _WallpaperCard(
                  wallpaper: wallpaper,
                  onTap: () => _onWallpaperTap(index, wallpaper),
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

  void _onWallpaperTap(int index, Wallpaper wallpaper) async {
    setState(() => _tappedIndex = index);
    await _cardTapController.reverse();
    await _cardTapController.forward();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    _showConnectDialog(context, wallpaper.displayImagePath);
  }

  @override
  void dispose() {
    _myCollectionTapTimer?.cancel();
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

// ---------------------------------------------------------------------------
// Passcode dialog — hidden admin access
// ---------------------------------------------------------------------------
class _PasscodeDialog extends StatefulWidget {
  const _PasscodeDialog();

  @override
  State<_PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<_PasscodeDialog>
    with SingleTickerProviderStateMixin {
  static const String _correctCode = '1212';
  String _entered = '';
  bool _wrong = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _wrong = false;
    });
    if (_entered.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _verify);
    }
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _wrong = false;
    });
  }

  void _verify() {
    if (_entered == _correctCode) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _wrong = true;
        _entered = '';
      });
      _shakeController.forward(from: 0.0);
    }
  }

  Widget _buildDot(int index) {
    final filled = index < _entered.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _wrong
            ? Colors.redAccent
            : filled
                ? Colors.cyanAccent
                : Colors.transparent,
        border: Border.all(
          color: _wrong ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.7),
          width: 2,
        ),
        boxShadow: filled
            ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 10)]
            : [],
      ),
    );
  }

  Widget _buildKey(String label, {VoidCallback? onTap, Widget? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1),
        ),
        child: Center(
          child: icon ??
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                ),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.15), blurRadius: 40, spreadRadius: 4),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock icon
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyanAccent.withOpacity(0.1),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.lock_outline, color: Colors.cyanAccent, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ADMIN ACCESS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _wrong ? 'Incorrect passcode' : 'Enter passcode',
                  style: TextStyle(
                    color: _wrong ? Colors.redAccent : Colors.white38,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 24),
                // PIN dots
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _buildDot(i),
                    )),
                  ),
                ),
                const SizedBox(height: 32),
                // Number pad
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['1', '2', '3']
                          .map((d) => _buildKey(d, onTap: () => _onKey(d)))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['4', '5', '6']
                          .map((d) => _buildKey(d, onTap: () => _onKey(d)))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['7', '8', '9']
                          .map((d) => _buildKey(d, onTap: () => _onKey(d)))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 72),
                        _buildKey('0', onTap: () => _onKey('0')),
                        _buildKey(
                          '',
                          onTap: _onDelete,
                          icon: const Icon(Icons.backspace_outlined,
                              color: Colors.white70, size: 22),
                        ),
                      ],
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
        tag: wallpaper.displayImagePath,
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
                child: wallpaper.isRemote
                    ? CachedNetworkImage(
                        imageUrl: wallpaper.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.black,
                          child: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black26,
                          child: const Icon(Icons.broken_image, color: Colors.white30, size: 40),
                        ),
                      )
                    : Image.asset(wallpaper.assetPath, fit: BoxFit.cover),
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
