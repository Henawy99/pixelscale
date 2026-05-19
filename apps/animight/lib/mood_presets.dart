import 'package:flutter/material.dart';
import 'package:animight/connection_service.dart';
import 'dart:math' as math;

/// Built-in mood lighting presets — key differentiator for Animight.
/// Each preset sends a specific command to the Arduino LED controller.
class MoodPresetsWidget extends StatefulWidget {
  const MoodPresetsWidget({super.key});

  @override
  State<MoodPresetsWidget> createState() => _MoodPresetsWidgetState();
}

class _MoodPresetsWidgetState extends State<MoodPresetsWidget> with SingleTickerProviderStateMixin {
  int _selectedIndex = -1;
  late AnimationController _glowCtrl;

  static const _presets = [
    MoodPreset(name: 'Chill', icon: Icons.nightlight_round, cmd: 'CMD:MOOD_CHILL',
      colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF42A5F5)]),
    MoodPreset(name: 'Party', icon: Icons.celebration, cmd: 'CMD:MOOD_PARTY',
      colors: [Color(0xFFE040FB), Color(0xFFFF1744), Color(0xFFFFD600)]),
    MoodPreset(name: 'Focus', icon: Icons.psychology, cmd: 'CMD:MOOD_FOCUS',
      colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00897B)]),
    MoodPreset(name: 'Sunset', icon: Icons.wb_twilight, cmd: 'CMD:MOOD_SUNSET',
      colors: [Color(0xFFE65100), Color(0xFFF57C00), Color(0xFFFFB74D)]),
    MoodPreset(name: 'Aurora', icon: Icons.auto_awesome, cmd: 'CMD:MOOD_AURORA',
      colors: [Color(0xFF00E5FF), Color(0xFF1DE9B6), Color(0xFF76FF03)]),
    MoodPreset(name: 'Gaming', icon: Icons.sports_esports, cmd: 'CMD:MOOD_GAMING',
      colors: [Color(0xFF7C4DFF), Color(0xFFE040FB), Color(0xFF00E5FF)]),
  ];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(int index) {
    setState(() => _selectedIndex = index);
    connectionService.sendCommand(_presets[index].cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(children: [
            const Icon(Icons.auto_fix_high, color: Color(0xFF00E5FF), size: 18),
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFFE040FB)],
              ).createShader(bounds),
              child: const Text('MOOD PRESETS',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _presets.length,
            itemBuilder: (context, i) {
              final preset = _presets[i];
              final selected = _selectedIndex == i;
              return AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) {
                  final glowVal = selected ? _glowCtrl.value : 0.0;
                  return GestureDetector(
                    onTap: () => _applyPreset(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 90, height: 105,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [preset.colors[0].withOpacity(selected ? 0.6 : 0.25), preset.colors[2].withOpacity(selected ? 0.4 : 0.1)],
                        ),
                        border: Border.all(color: selected ? preset.colors[1] : Colors.white.withOpacity(0.15), width: selected ? 2 : 1),
                        boxShadow: selected ? [
                          BoxShadow(color: preset.colors[1].withOpacity(0.4 + 0.3 * glowVal), blurRadius: 16 + 8 * glowVal, spreadRadius: 1),
                        ] : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(preset.icon, color: selected ? Colors.white : Colors.white70, size: 28,
                            shadows: selected ? [Shadow(color: preset.colors[1], blurRadius: 12)] : []),
                          const SizedBox(height: 8),
                          Text(preset.name,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white60,
                              fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              letterSpacing: 0.5,
                            )),
                          if (selected) ...[
                            const SizedBox(height: 4),
                            Container(width: 16, height: 2, decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              color: preset.colors[1],
                              boxShadow: [BoxShadow(color: preset.colors[1].withOpacity(0.8), blurRadius: 6)],
                            )),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class MoodPreset {
  final String name;
  final IconData icon;
  final String cmd;
  final List<Color> colors;
  const MoodPreset({required this.name, required this.icon, required this.cmd, required this.colors});
}

/// Brightness slider widget for the control screen.
class BrightnessSliderWidget extends StatefulWidget {
  const BrightnessSliderWidget({super.key});

  @override
  State<BrightnessSliderWidget> createState() => _BrightnessSliderWidgetState();
}

class _BrightnessSliderWidgetState extends State<BrightnessSliderWidget> {
  double _brightness = 0.8;

  void _onChanged(double val) {
    setState(() => _brightness = val);
    final level = (val * 255).round();
    connectionService.sendCommand('CMD:BRIGHTNESS:$level');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.wb_sunny_outlined, color: Color.lerp(Colors.white30, const Color(0xFFFFD600), _brightness), size: 18),
            const SizedBox(width: 8),
            const Text('BRIGHTNESS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const Spacer(),
            Text('${(_brightness * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: const Color(0xFF00E5FF),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
            ),
            child: Slider(value: _brightness, onChanged: _onChanged),
          ),
        ],
      ),
    );
  }
}
