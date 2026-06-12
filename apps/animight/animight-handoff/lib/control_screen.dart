import 'package:flutter/material.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:animight/connection_service.dart'; // Import ConnectionService

class ControlScreen extends StatelessWidget {
  final String backgroundImagePath;

  const ControlScreen({super.key, required this.backgroundImagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Background Image
          Image.asset(
            backgroundImagePath,
            fit: BoxFit.cover,
          ),
          // Glowy Blur Overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.18),
            ),
          ),
          // Semi-transparent overlay for better text/icon visibility
          Container(
            color: Colors.black.withOpacity(0.25),
          ),
          // Control Buttons and "Connected" text
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Top row with a Back Button
                  Padding(
                    padding: const EdgeInsets.only(left: 0, top: 16.0),
                    child: _buildGlowyBackButton(context),
                  ),
                  // Grid of control buttons
                  Expanded(
                    child: Center(
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 24,
                        childAspectRatio: 1.1,
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        physics: const NeverScrollableScrollPhysics(), // Disable scrolling for the grid
                        children: <Widget>[
                          // Loop Animation Button
                          _buildGlowyControlButton(icon: Icons.sync, color: Colors.cyanAccent, label: "Loop", onTap: () {
                            connectionService.sendCommand("CMD:LOOP_ANIM");
                          }),
                          // Sound Reactive Button
                          _buildGlowyControlButton(icon: Icons.graphic_eq, color: Colors.purpleAccent, label: "Sound", onTap: () {
                            connectionService.sendCommand("CMD:SOUND_MODE");
                          }),
                          // A blank space or another button can go here
                          const SizedBox(), 
                          // OFF Button
                          _buildGlowyControlButton(icon: Icons.power_settings_new, color: Colors.redAccent, label: "OFF", onTap: () {
                            connectionService.sendCommand("CMD:OFF");
                            connectionService.disconnect(); 
                            Navigator.of(context).pop();
                          }),
                        ],
                      ),
                    ),
                  ),
                  // "Connected" Text with Glow
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          colors: [Colors.cyanAccent, Colors.blueAccent, Colors.pinkAccent],
                          tileMode: TileMode.mirror,
                        ).createShader(bounds);
                      },
                      child: Text(
                        'Connected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          shadows: [
                            Shadow(color: Colors.cyanAccent, blurRadius: 18),
                            Shadow(color: Colors.blueAccent, blurRadius: 12),
                          ],
                        ),
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

  Widget _buildGlowyBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
      style: ButtonStyle(
        shadowColor: MaterialStateProperty.all(Colors.cyanAccent),
        elevation: MaterialStateProperty.all(12),
      ),
      onPressed: () {
        connectionService.disconnect(); // Disconnect from the device
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildGlowyControlButton({IconData? icon, Color? color, String? label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(22.0),
          boxShadow: [
            if (color != null)
              BoxShadow(
                color: color.withOpacity(0.7),
                blurRadius: 24,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: label != null
              ? Text(
                  label,
                  style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: color ?? Colors.white, blurRadius: 16),
                    ],
                  ),
                )
              : Icon(
                  icon,
                  color: color ?? Colors.white,
                  size: 54,
                  shadows: [
                    Shadow(color: color ?? Colors.white, blurRadius: 16),
                  ],
                ),
        ),
      ),
    );
  }
}
