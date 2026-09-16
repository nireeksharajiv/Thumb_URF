import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  disconnecting,
}

/// Manages the low-level BLE scanning and connection lifecycle.
class BleDeviceManager {
  BleConnectionState _state = BleConnectionState.disconnected;
  BleConnectionState get state => _state;

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final StreamController<BleConnectionState> _stateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get stateStream => _stateController.stream;

  void _updateState(BleConnectionState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  /// Scans for devices matching [targetDeviceName] and auto-connects to the first one found.
  Future<void> startScanAndConnect(String targetDeviceName, {Duration timeout = const Duration(seconds: 10)}) async {
    if (_state != BleConnectionState.disconnected) {
      await disconnect();
    }

    _updateState(BleConnectionState.scanning);

    try {
      // Ensure Bluetooth is on
      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        _updateState(BleConnectionState.disconnected);
        throw Exception('Bluetooth is disabled');
      }

      await FlutterBluePlus.startScan(timeout: timeout);

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName == targetDeviceName || r.device.advName == targetDeviceName) {
            _stopScanAndConnect(r.device);
            break;
          }
        }
      });

      // Wait for scan to finish if no device is found
      Future.delayed(timeout, () {
        if (_state == BleConnectionState.scanning) {
          _updateState(BleConnectionState.disconnected);
          _scanSubscription?.cancel();
        }
      });
    } catch (e) {
      _updateState(BleConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> _stopScanAndConnect(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (_state != BleConnectionState.scanning) return; // Disconnected midway

    _updateState(BleConnectionState.connecting);

    try {
      await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      _updateState(BleConnectionState.connected);

      // Listen for unexpected disconnections
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleUnexpectedDisconnect();
        }
      });
    } catch (e) {
      _updateState(BleConnectionState.disconnected);
      rethrow;
    }
  }

  void _handleUnexpectedDisconnect() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDevice = null;
    _updateState(BleConnectionState.disconnected);
  }

  /// Disconnects gracefully from the current device.
  Future<void> disconnect() async {
    _updateState(BleConnectionState.disconnecting);
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (_connectedDevice != null) {
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }

    _updateState(BleConnectionState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
  }
}
