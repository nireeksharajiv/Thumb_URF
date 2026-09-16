import 'dart:async';
import 'dart:convert';


import 'ble_protocol.dart';
import 'ble_device_manager.dart';

export 'ble_device_manager.dart' show BleConnectionState;

/// High-level service that connects to the ESP32 and streams text data.
class BleSensorService {
  final BleDeviceManager _deviceManager;
  BleSensorService({BleDeviceManager? deviceManager})
      : _deviceManager = deviceManager ?? BleDeviceManager() {
    _deviceManager.stateStream.listen((state) {
      if (state == BleConnectionState.connected) {
        _discoverAndSubscribe();
      } else if (state == BleConnectionState.disconnected) {
        _cleanupSubscription();
      }
      _stateController.add(state);
    });
  }

  StreamSubscription<List<int>>? _charSubscription;

  final StreamController<String> _dataController = StreamController<String>.broadcast();
  Stream<String> get incomingData => _dataController.stream;

  final StreamController<BleConnectionState> _stateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get stateStream => _stateController.stream;
  BleConnectionState get state => _deviceManager.state;

  /// Starts scanning and connects to the ThumbTrace glove.
  Future<void> connect() async {
    await _deviceManager.startScanAndConnect(BleProtocol.deviceName);
  }

  /// Disconnects gracefully.
  Future<void> disconnect() async {
    await _deviceManager.disconnect();
  }

  bool get isSubscribed => _charSubscription != null;

  /// Visible for testing to simulate a subscription
  void setMockSubscribed(bool value) {
    if (!value) {
      _charSubscription?.cancel();
      _charSubscription = null;
    } else {
      // Create a dummy subscription just for testing state
      _charSubscription = StreamController<List<int>>().stream.listen((_) {});
    }
  }

  /// Visible for testing to parse data without hardware
  void handleRawData(List<int> value) {
    if (value.isNotEmpty) {
      try {
        final str = utf8.decode(value);
        if (str.isNotEmpty) {
          _dataController.add(str);
        }
      } catch (_) {
        // Ignore malformed UTF-8 from hardware gracefully
      }
    }
  }

  Future<void> _discoverAndSubscribe() async {
    final device = _deviceManager.connectedDevice;
    if (device == null) return;

    try {
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == BleProtocol.serviceUuid.toLowerCase()) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == BleProtocol.characteristicUuid.toLowerCase()) {
              await characteristic.setNotifyValue(true);
              _charSubscription = characteristic.onValueReceived.listen(handleRawData);
              return;
            }
          }
        }
      }
    } catch (e) {
      // Failed to discover or subscribe
      await disconnect();
    }
  }

  void _cleanupSubscription() {
    _charSubscription?.cancel();
    _charSubscription = null;
  }

  Future<void> dispose() async {
    _cleanupSubscription();
    await _deviceManager.dispose();
    await _dataController.close();
    await _stateController.close();
  }
}
