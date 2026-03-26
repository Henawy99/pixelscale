import 'package:flutter/foundation.dart';
import 'package:animight/ble_service.dart';
import 'package:animight/wifi_service.dart';

enum ConnectionStatus {
  disconnected,
  connectedBle,
  connectedWifi,
}

class ConnectionService with ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;

  ConnectionService() {
    bleService.addListener(() {
      if (bleService.isConnected) {
        _updateStatus(ConnectionStatus.connectedBle);
      } else {
        // If BLE disconnects, check if WiFi is still connected before marking as disconnected
        if (_status == ConnectionStatus.connectedBle) {
          _updateStatus(ConnectionStatus.disconnected);
        }
      }
    });

    wifiService.addListener(() {
      if (wifiService.isConnected) {
        _updateStatus(ConnectionStatus.connectedWifi);
      } else {
        // If WiFi disconnects, check if BLE is still connected
        if (_status == ConnectionStatus.connectedWifi) {
          _updateStatus(ConnectionStatus.disconnected);
        }
      }
    });
  }

  ConnectionStatus get status => _status;

  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  Future<void> sendCommand(String command) {
    switch (_status) {
      case ConnectionStatus.connectedBle:
        return bleService.sendCommand(command);
      case ConnectionStatus.connectedWifi:
        return wifiService.sendCommand(command);
      case ConnectionStatus.disconnected:
        print("Cannot send command: Not connected.");
        return Future.value();
    }
  }

  void disconnect() {
    if (_status == ConnectionStatus.connectedBle) {
      bleService.disconnect();
    } else if (_status == ConnectionStatus.connectedWifi) {
      wifiService.disconnect();
    }
    _updateStatus(ConnectionStatus.disconnected);
  }
}

final ConnectionService connectionService = ConnectionService();
