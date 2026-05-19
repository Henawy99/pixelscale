import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:animight/connection_service.dart';
import 'package:animight/mood_presets.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ControlScreen extends StatelessWidget {
  final String backgroundImagePath;

  const ControlScreen({super.key, required this.backgroundImagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Background Image (supports both network and asset)
          if (backgroundImagePath.startsWith('http'))
            CachedNetworkImage(
              imageUrl: backgroundImagePath,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF050510)),
            )
          else if (backgroundImagePath.isNotEmpty)
            Image.asset(backgroundImagePath, fit: BoxFit.cover)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D0D2B), Color(0xFF1A0A3E)],
                ),
              ),
            ),
          // Glowy Blur Overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          // Controls
          SafeArea(
            child: Column(
              children: <Widget>[
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      _buildGlowyBackButton(context),
                      const Spacer(),
                      // Connected badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.circle, color: Color(0xFF00E5FF), size: 8),
                          SizedBox(width: 8),
                          Text('Connected', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Control buttons grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: _buildControlCard(icon: Icons.sync, color: const Color(0xFF00E5FF), label: 'Loop', onTap: () => connectionService.sendCommand('CMD:LOOP_ANIM'))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildControlCard(icon: Icons.graphic_eq, color: const Color(0xFF7C4DFF), label: 'Sound', onTap: () => connectionService.sendCommand('CMD:SOUND_MODE'))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildControlCard(icon: Icons.power_settings_new, color: const Color(0xFFFF5252), label: 'OFF', onTap: () {
                        connectionService.sendCommand('CMD:OFF');
                        connectionService.disconnect();
                        Navigator.of(context).pop();
                      })),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Brightness slider
                const BrightnessSliderWidget(),
                const SizedBox(height: 8),
                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
                ),
                const SizedBox(height: 8),
                // Mood presets
                const Expanded(
                  child: SingleChildScrollView(
                    child: MoodPresetsWidget(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowyBackButton(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () {
              connectionService.disconnect();
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 16)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30, shadows: [Shadow(color: color, blurRadius: 12)]),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
