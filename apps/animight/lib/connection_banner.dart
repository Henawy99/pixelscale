import 'package:flutter/material.dart';
import 'package:animight/connection_service.dart';

class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _status = connectionService.status;
    _isVisible = _status != ConnectionStatus.disconnected;
    connectionService.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    connectionService.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged() {
    if (mounted) {
      final newStatus = connectionService.status;
      setState(() {
        _status = newStatus;
        _isVisible = newStatus != ConnectionStatus.disconnected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerData = _getBannerData(_status);

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: _isVisible
          ? Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 8,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: bannerData['color']?.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: bannerData['color']!.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(bannerData['icon'], color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      bannerData['text']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Map<String, dynamic> _getBannerData(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connectedBle:
        return {
          'text': 'Connected via Bluetooth',
          'icon': Icons.bluetooth_connected,
          'color': Colors.blueAccent,
        };
      case ConnectionStatus.connectedWifi:
        return {
          'text': 'Connected via Wi-Fi',
          'icon': Icons.wifi,
          'color': Colors.purpleAccent,
        };
      default:
        return {
          'text': 'Disconnected',
          'icon': Icons.signal_wifi_off,
          'color': Colors.grey[800],
        };
    }
  }
}
