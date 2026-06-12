import 'dart:async';
import 'dart:convert'; // For utf8.encode
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService with ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandCharacteristic;

  // UUIDs for the AniMight ESP32 service
  final Guid _serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Guid _characteristicUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void _updateConnectionState(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      notifyListeners();
    }
  }

  // --- Scanning Methods ---
  StreamSubscription? _scanSubscription; // To manage the scan stream
  final StreamController<List<ScanResult>> _scanResultsController = StreamController.broadcast();
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  Future<void> startScan() async {
    // Cancel any previous scan subscription
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    
    // Clear previous results
    _scanResultsController.add([]);

    try {
      // Ensure Bluetooth is on
      if (!await FlutterBluePlus.isSupported) {
        print("BLE is not supported by this device");
        return;
      }
      await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;
      
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResultsController.add(results);
      }, onError: (e) {
        print("Error during scan: $e");
      });
    } catch (e) {
      print("Error starting scan: $e");
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
    } catch (e) {
      print("Error stopping scan: $e");
    }
  }

  // --- Connection Methods ---
  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (isConnected) await disconnect();
    
    _connectedDevice = device;
    try {
      await _connectedDevice!.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      await _discoverServices();
      return isConnected; // Return true if connection and service discovery were successful
    } catch (e) {
      print("Error connecting to device: $e");
      _connectedDevice = null; // Reset on failure
      return false;
    }
  }

  Future<bool> scanAndConnect(String deviceName) async {
    Completer<bool> connectionCompleter = Completer();
    StreamSubscription? scanSubscription;

    // Start scanning
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Listen to scan results
    scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName == deviceName) {
          // Found the device, stop scanning
          await FlutterBluePlus.stopScan();
          scanSubscription?.cancel();

          // Attempt to connect
          bool success = await connectToDevice(r.device);
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(success);
          }
          return;
        }
      }
    });

    // Handle timeout
    Future.delayed(const Duration(seconds: 10), () {
      if (!connectionCompleter.isCompleted) {
        FlutterBluePlus.stopScan();
        scanSubscription?.cancel();
        connectionCompleter.complete(false);
      }
    });

    return connectionCompleter.future;
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;

    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid == _serviceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _characteristicUuid) {
              _commandCharacteristic = characteristic;
              print("Command characteristic found!");
              _updateConnectionState(true); // Notify that we are fully connected and ready
              return;
            }
          }
        }
      }
      print("Command characteristic NOT found.");
      disconnect(); // Disconnect if the required characteristic isn't found
    } catch (e) {
      print("Error discovering services: $e");
      disconnect();
    }
  }

  Future<void> sendCommand(String command) async {
    if (_commandCharacteristic == null || !isConnected) {
      // ignore: avoid_print
      print("Not connected or characteristic not found. Cannot send command.");
      return;
    }
    try {
      List<int> bytes = utf8.encode(command); // Encode string to bytes
      await _commandCharacteristic!.write(bytes, withoutResponse: false); // Use withoutResponse: true if your Arduino doesn't send a response
      // ignore: avoid_print
      print("Sent command: $command");
    } catch (e) {
      // ignore: avoid_print
      print("Error sending command: $e");
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        print("Error disconnecting: $e");
      }
    }
    _connectedDevice = null;
    _commandCharacteristic = null;
    _updateConnectionState(false); // Notify that we are disconnected
    print("Disconnected");
  }
}

// Global instance (or use a proper state management solution like Provider, Riverpod, GetX)
final BleService bleService = BleService();
