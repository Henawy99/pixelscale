import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _particleController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnim;

  final _pages = const [
    _OBPage(
      title: 'Welcome to\nAnimight',
      subtitle: 'Your personal command center for\ncustom LED art panels.',
      icon: Icons.auto_awesome,
      grad: [Color(0xFF0D0D2B), Color(0xFF1A0A3E)],
      accent: Color(0xFF00E5FF),
    ),
    _OBPage(
      title: 'Discover\nDesigns',
      subtitle: 'Browse curated lighting designs.\nPreview moods and apply them\nto your panel instantly.',
      icon: Icons.palette_outlined,
      grad: [Color(0xFF1A0A3E), Color(0xFF2D0B4E)],
      accent: Color(0xFFE040FB),
    ),
    _OBPage(
      title: 'Connect\nYour Board',
      subtitle: 'Pair with your Animight panel\nover Bluetooth in seconds.\nThen control everything from here.',
      icon: Icons.bluetooth_connected,
      grad: [Color(0xFF0A1628), Color(0xFF0D2137)],
      accent: Color(0xFF00E5FF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    widget.onComplete();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _particleController,
            builder: (ctx, _) => CustomPaint(
              size: MediaQuery.of(ctx).size,
              painter: _ParticlePainter(progress: _particleController.value, color: page.accent),
            ),
          ),
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) { setState(() => _currentPage = i); _fadeController.forward(from: 0); },
            itemBuilder: (_, i) => _buildPage(_pages[i]),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 32 : 10, height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i == _currentPage ? page.accent : Colors.white24,
                          boxShadow: i == _currentPage ? [BoxShadow(color: page.accent.withOpacity(0.6), blurRadius: 8)] : [],
                        ),
                      )),
                    ),
                    const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: page.accent.withOpacity(0.4 * _pulseAnim.value), blurRadius: 24, spreadRadius: 2)],
                        ),
                        child: child,
                      ),
                      child: SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: page.accent.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: page.accent, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(_currentPage == _pages.length - 1 ? 'GET STARTED' : 'NEXT',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_currentPage < _pages.length - 1)
                      TextButton(onPressed: _complete, child: Text('Skip', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)))
                    else const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OBPage p) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p.grad)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
            child: Column(children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [p.accent.withOpacity(0.15), p.accent.withOpacity(0.05), Colors.transparent], stops: const [0, 0.6, 1]),
                    boxShadow: [BoxShadow(color: p.accent.withOpacity(0.3 * _pulseAnim.value), blurRadius: 40 + 20 * _pulseAnim.value, spreadRadius: 8)],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5), border: Border.all(color: p.accent.withOpacity(0.6), width: 2)),
                    child: Icon(p.icon, color: p.accent, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(p.title, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1.2, shadows: [Shadow(color: p.accent.withOpacity(0.5), blurRadius: 20)])),
              const SizedBox(height: 20),
              Text(p.subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, height: 1.6)),
              const Spacer(flex: 3),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OBPage {
  final String title, subtitle;
  final IconData icon;
  final List<Color> grad;
  final Color accent;
  const _OBPage({required this.title, required this.subtitle, required this.icon, required this.grad, required this.accent});
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 50; i++) {
      final x = ((i * 17.3) % 1.0) * size.width + progress * (0.2 + (i % 5) * 0.15) * size.width * 2;
      final y = ((i * 23.7) % 1.0) * size.height + math.sin(progress * math.pi * 2 + i * 0.1) * 20;
      final s = 1.0 + (i % 3) * 0.8;
      final o = (0.3 + 0.4 * math.sin(progress * math.pi * 2 + i * 0.1)).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x % size.width, y), s, Paint()..color = color.withOpacity(o * 0.6)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
