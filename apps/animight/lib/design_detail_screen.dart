import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animight/home_screen.dart';
import 'package:animight/connect_dialog.dart';
import 'dart:ui';
import 'dart:math' as math;

/// Immersive full-screen preview of a wallpaper design.
/// Unique feature: pulse-preview animation, color palette, and collection toggle.
class DesignDetailScreen extends StatefulWidget {
  final Wallpaper wallpaper;
  const DesignDetailScreen({super.key, required this.wallpaper});

  @override
  State<DesignDetailScreen> createState() => _DesignDetailScreenState();
}

class _DesignDetailScreenState extends State<DesignDetailScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallpaper;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showInfo = !_showInfo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-screen image with pulse glow
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final glow = 0.05 + 0.1 * _pulseCtrl.value;
                return Stack(fit: StackFit.expand, children: [
                  w.isRemote
                      ? CachedNetworkImage(imageUrl: w.imageUrl, fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white30, size: 60))
                      : Image.asset(w.assetPath, fit: BoxFit.cover),
                  // LED panel glow simulation
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center, radius: 1.2,
                        colors: [Colors.transparent, const Color(0xFF00E5FF).withOpacity(glow)],
                      ),
                    ),
                  ),
                ]);
              },
            ),
            // Bottom gradient
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: AnimatedOpacity(
                opacity: _showInfo ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  height: 340,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.85), Colors.black],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ),
            // Info panel
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: AnimatedSlide(
                offset: _showInfo ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Design name
                        Text(w.name,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5,
                            shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 12)])),
                        const SizedBox(height: 8),
                        // Color palette dots
                        Row(children: [
                          _colorDot(const Color(0xFF00E5FF)),
                          _colorDot(const Color(0xFFE040FB)),
                          _colorDot(const Color(0xFF7C4DFF)),
                          _colorDot(const Color(0xFF00BFA5)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 14),
                              SizedBox(width: 6),
                              Text('LED Panel Ready', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text('Tap the image to toggle this panel', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                        const SizedBox(height: 20),
                        // Action buttons
                        Row(children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'CONNECT & APPLY',
                              icon: Icons.bluetooth,
                              color: const Color(0xFF00E5FF),
                              onTap: () => _showConnect(context),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Back button
            Positioned(
              top: 0, left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color c) {
    return Container(
      width: 20, height: 20,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: c,
        boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 8)],
        border: Border.all(color: Colors.white24, width: 1),
      ),
    );
  }

  void _showConnect(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) => ConnectDialog(
        onConnectionAttempted: (success, method, deviceName) {
          Navigator.of(dialogCtx).pop();
          if (success) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Connected! Design applied.')));
          } else {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('Failed to connect via $method.')));
          }
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5,
            shadows: [Shadow(color: color, blurRadius: 8)])),
        ]),
      ),
    );
  }
}
