import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WifiService with ChangeNotifier {
  Socket? _socket;
  bool _isConnected = false;
  final String _ipAddress = "192.168.4.1"; // Default IP for ESP32 Access Point
  final int _port = 80;

  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    if (_isConnected) return true;

    // This new logic assumes the user has already connected their phone
    // to the ESP32's Wi-Fi network via the phone's settings.
    try {
      _socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 5));
      _isConnected = true;
      
      _socket!.listen(
        (data) {
          final serverResponse = String.fromCharCodes(data);
          print('Server: $serverResponse');
        },
        onError: (error) {
          print("Socket Error: $error");
          disconnect();
        },
        onDone: () {
          print("Server left.");
          disconnect();
        },
        cancelOnError: true,
      );

      print("Successfully connected to WiFi device via socket.");
      notifyListeners();
      return true;
    } catch (e) {
      print("Error connecting via WiFi: $e");
      disconnect();
      return false;
    }
  }

  Future<void> sendCommand(String command) async {
    if (!_isConnected || _socket == null) {
      print("Not connected. Cannot send command.");
      return;
    }
    try {
      _socket!.writeln(command);
      await _socket!.flush();
      print("Sent command via WiFi: $command");
    } catch (e) {
      print("Error sending command via WiFi: $e");
      disconnect();
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.destroy();
      _socket = null;
    }
    if (_isConnected) {
      _isConnected = false;
      print("Disconnected from WiFi.");
      notifyListeners();
    }
  }
}

final WifiService wifiService = WifiService();
