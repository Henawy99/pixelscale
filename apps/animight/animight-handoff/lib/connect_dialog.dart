import 'package:flutter/material.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:animight/ble_service.dart';

class ConnectDialog extends StatefulWidget {
  final Function(bool success, String method, String? deviceName) onConnectionAttempted;

  const ConnectDialog({super.key, required this.onConnectionAttempted});

  @override
  State<ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<ConnectDialog> {
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingDeviceName;

  @override
  void dispose() {
    // Ensure scanning is stopped when the dialog is closed
    bleService.stopScan();
    super.dispose();
  }

  void _startBleScan() {
    setState(() {
      _isScanning = true;
    });
    bleService.startScan();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isScanning = false;
      _isConnecting = true;
      _connectingDeviceName = device.platformName;
    });
    
    await bleService.stopScan();
    bool success = await bleService.connectToDevice(device);
    
    if (mounted) {
      setState(() {
        _isConnecting = false;
        _connectingDeviceName = null;
      });
      widget.onConnectionAttempted(success, 'Bluetooth', device.platformName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.5),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
          ),
          padding: const EdgeInsets.all(24.0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isConnecting) {
      return _buildConnectingView();
    }
    if (_isScanning) {
      return _buildScanningView();
    }
    return _buildInitialView();
  }

  Widget _buildInitialView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildHeader('CONNECT TO\nYOUR BOARD'),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildGlowyConnectButton(
              icon: Icons.bluetooth,
              label: 'Bluetooth',
              borderColor: Colors.blueAccent,
              glowColor: Colors.cyanAccent,
              onTap: _startBleScan,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildScanningView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader('SCANNING...'),
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: Colors.cyanAccent),
        const SizedBox(height: 20),
        SizedBox(
          height: 200, // Constrain the height of the list
          child: StreamBuilder<List<ScanResult>>(
            stream: bleService.scanResults,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No devices found yet...", style: TextStyle(color: Colors.white70)));
              }
              
              // Filter for devices with a name
              final devices = snapshot.data!.where((r) => r.device.platformName.isNotEmpty).toList();

              return ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final result = devices[index];
                  return ListTile(
                    title: Text(result.device.platformName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(result.device.remoteId.toString(), style: const TextStyle(color: Colors.white54)),
                    leading: const Icon(Icons.memory, color: Colors.blueAccent),
                    onTap: () => _connectToDevice(result.device),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() => _isScanning = false),
          child: const Text("Cancel", style: TextStyle(color: Colors.pinkAccent, fontSize: 16)),
        )
      ],
    );
  }

  Widget _buildConnectingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader('CONNECTING TO'),
        const SizedBox(height: 12),
        Text(
          _connectingDeviceName ?? 'Device',
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: Colors.cyanAccent),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeader(String text) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          colors: [Colors.cyanAccent, Colors.blueAccent, Colors.pinkAccent],
          tileMode: TileMode.mirror,
        ).createShader(bounds);
      },
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          height: 1.3,
          shadows: [
            Shadow(color: Colors.cyanAccent, blurRadius: 18),
            Shadow(color: Colors.blueAccent, blurRadius: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowyConnectButton({
    required IconData icon,
    required String label,
    required Color borderColor,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return PulsingGlow(
      glowColor: glowColor,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 120,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: borderColor.withOpacity(0.8), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: borderColor, size: 54, shadows: [Shadow(color: glowColor, blurRadius: 16)]),
              const SizedBox(height: 18),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: glowColor, blurRadius: 12)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minBlur;
  final double maxBlur;
  final Duration duration;

  const PulsingGlow({
    required this.child,
    required this.glowColor,
    this.minBlur = 16,
    this.maxBlur = 32,
    this.duration = const Duration(seconds: 2),
    super.key,
  });

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final blur = widget.minBlur + (widget.maxBlur - widget.minBlur) * _controller.value;
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.7),
                blurRadius: blur,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
