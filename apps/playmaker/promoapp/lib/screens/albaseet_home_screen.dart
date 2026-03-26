import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/albaseet_visitor_service.dart';

/// Al Baseet Sports Home Screen with visitor counter
class AlBaseetHomeScreen extends StatefulWidget {
  const AlBaseetHomeScreen({super.key});

  @override
  State<AlBaseetHomeScreen> createState() => _AlBaseetHomeScreenState();
}

class _AlBaseetHomeScreenState extends State<AlBaseetHomeScreen> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  final AlBaseetVisitorService _visitorService = AlBaseetVisitorService();
  
  int _visitorCount = 0;
  int _todayVisitors = 0;
  bool _isLoading = true;
  
  int _activeProductIndex = 0;
  Timer? _productCycleTimer;
  Timer? _visitorRefreshTimer;
  
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _counterController;
  late AnimationController _floatController;
  
  final List<Map<String, String>> _products = [
    {'image': 'assets/images/albassetpromoimage1.png', 'name': 'Court Tennis Balls', 'price': 'EGP 450'},
    {'image': 'assets/images/albaseetpromoimage2.png', 'name': 'Pro Sports Bag', 'price': 'EGP 2,850'},
    {'image': 'assets/images/albassetpromoimage3.png', 'name': 'Padel Racket Pro', 'price': 'EGP 4,200'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize animation controllers
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _scaleController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Track this visit
    await _visitorService.trackVisit(screen: 'home');
    
    // Load visitor stats
    await _loadVisitorStats();
    
    // Start product cycle
    _startProductCycle();
    
    // Refresh visitor count every 30 seconds
    _visitorRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadVisitorStats(),
    );
  }

  Future<void> _loadVisitorStats() async {
    try {
      final stats = await _visitorService.getVisitorStats();
      if (mounted) {
        setState(() {
          _visitorCount = stats['total'] ?? 0;
          _todayVisitors = stats['today'] ?? 0;
          _isLoading = false;
        });
        _counterController.forward(from: 0);
      }
    } catch (e) {
      print('❌ Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startProductCycle() {
    _productCycleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _scaleController.reverse().then((_) {
          setState(() => _activeProductIndex = (_activeProductIndex + 1) % _products.length);
          _scaleController.forward();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached) {
      _visitorService.endSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visitorService.endSession();
    _productCycleTimer?.cancel();
    _visitorRefreshTimer?.cancel();
    _scaleController.dispose();
    _glowController.dispose();
    _counterController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFCD3A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background decorations
          _buildBackground(),
          
          // Main content
          SafeArea(
            child: isLandscape 
                ? _buildLandscapeLayout() 
                : _buildPortraitLayout(),
          ),
          
          // Visitor counter badge - top right
          Positioned(
            top: 20,
            right: 20,
            child: _buildVisitorBadge(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        // Main gradient
        Container(color: const Color(0xFFFFCD3A)),
        
        // Animated circle top right
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
        
        // Animated circle bottom left
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
      ],
    );
  }

  Widget _buildVisitorBadge() {
    return AnimatedBuilder(
      animation: _counterController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated eye icon
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) => Icon(
                  Icons.visibility,
                  color: Color.lerp(
                    const Color(0xFFFFCD3A),
                    Colors.white,
                    _glowController.value * 0.3,
                  ),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              
              // Visitor count with animation
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFCD3A),
                                strokeWidth: 2,
                              ),
                            )
                          : TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: _visitorCount),
                              duration: const Duration(milliseconds: 1500),
                              builder: (context, value, _) {
                                return Text(
                                  _formatNumber(value),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                );
                              },
                            ),
                      const SizedBox(width: 6),
                      Text(
                        'visitors',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Today's count
                  if (!_isLoading && _todayVisitors > 0)
                    Text(
                      '+$_todayVisitors today',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFCD3A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Left side - Logo and info
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 30),
                _buildTagline(),
                const SizedBox(height: 40),
                _buildCTA(),
              ],
            ),
          ),
        ),
        
        // Right side - Products
        Expanded(
          flex: 6,
          child: _buildProductShowcase(),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 60), // Space for visitor badge
            _buildLogo(),
            const SizedBox(height: 25),
            _buildTagline(),
            const SizedBox(height: 40),
            _buildProductShowcase(),
            const SizedBox(height: 40),
            _buildCTA(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatController.value * 8 - 4),
          child: Column(
            children: [
              // Logo with glow effect
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/albaseetlogo.png',
                  height: 160,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagline() {
    return Column(
      children: [
        Text(
          'PREMIUM SPORTS GEAR',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 5,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            '⚽ Tennis • Padel • Football • Basketball 🏀',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductShowcase() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        
        if (isWide) {
          // Show all products in a row for landscape/tablet
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              _products.length,
              (index) => _buildProductCard(index, compact: true),
            ),
          );
        }
        
        // Show products in carousel for portrait
        return Column(
          children: [
            _buildProductCard(_activeProductIndex),
            const SizedBox(height: 20),
            _buildProductIndicators(),
          ],
        );
      },
    );
  }

  Widget _buildProductCard(int index, {bool compact = false}) {
    final isActive = index == _activeProductIndex;
    final product = _products[index];
    
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _glowController]),
      builder: (context, child) {
        double scale = 1.0;
        double opacity = compact ? 0.85 : 1.0;
        double glowOpacity = 0.0;
        
        if (isActive && !compact) {
          scale = 1.0 + (_scaleController.value * 0.08);
          glowOpacity = 0.4 + (_glowController.value * 0.3);
        } else if (isActive && compact) {
          scale = 1.05;
          glowOpacity = 0.5;
          opacity = 1.0;
        }
        
        final cardWidth = compact ? 200.0 : 280.0;
        final imageHeight = compact ? 140.0 : 200.0;
        
        return Transform.scale(
          scale: scale,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: opacity,
            child: Container(
              width: cardWidth,
              padding: EdgeInsets.all(compact ? 15 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: isActive 
                    ? Border.all(color: Colors.black.withOpacity(0.1), width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isActive && !compact
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
                  // Product image
                  Container(
                    height: imageHeight,
                    padding: EdgeInsets.all(compact ? 10 : 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset(product['image']!, fit: BoxFit.contain),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  
                  // Product name
                  Text(
                    product['name']!,
                    style: GoogleFonts.inter(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  
                  // Price
                  Text(
                    product['price']!,
                    style: GoogleFonts.inter(
                      fontSize: compact ? 18 : 22,
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

  Widget _buildProductIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_products.length, (index) {
        final isActive = index == _activeProductIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 30 : 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.black87 : Colors.black26,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  Widget _buildCTA() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3 + _glowController.value * 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: const Color(0xFFFFCD3A),
                size: 26,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Showroom around the corner',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Visit us today!',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFFCD3A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCD3A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.black87, size: 20),
              ),
            ],
          ),
        );
      },
    );
  }
}
