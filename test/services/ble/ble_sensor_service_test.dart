import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/services/ble/ble_sensor_service.dart';
import 'package:thumb_biomech_monitor_glove/services/ble/ble_device_manager.dart';

// Manual mock for BleDeviceManager to simulate state changes
class MockBleDeviceManager extends BleDeviceManager {
  final _mockStateController = StreamController<BleConnectionState>.broadcast();
  BleConnectionState _mockState = BleConnectionState.disconnected;
  
  @override
  Stream<BleConnectionState> get stateStream => _mockStateController.stream;
  
  @override
  BleConnectionState get state => _mockState;

  void simulateState(BleConnectionState state) {
    _mockState = state;
    _mockStateController.add(state);
  }
  
  @override
  Future<void> startScanAndConnect(String targetDeviceName, {Duration timeout = const Duration(seconds: 10)}) async {
    simulateState(BleConnectionState.scanning);
    // Simulate finding and connecting
    simulateState(BleConnectionState.connecting);
    simulateState(BleConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    simulateState(BleConnectionState.disconnecting);
    simulateState(BleConnectionState.disconnected);
  }
  
  @override
  Future<void> dispose() async {
    await _mockStateController.close();
  }
}

void main() {
  group('BleSensorService Tests', () {
    late MockBleDeviceManager mockManager;
    late BleSensorService service;

    setUp(() {
      mockManager = MockBleDeviceManager();
      service = BleSensorService(deviceManager: mockManager);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('Initial state is disconnected', () {
      expect(service.state, BleConnectionState.disconnected);
    });

    test('Connection state stream propagates changes', () async {
      expectLater(
        service.stateStream,
        emitsInOrder([
          BleConnectionState.scanning,
          BleConnectionState.connecting,
          BleConnectionState.connected,
          BleConnectionState.disconnecting,
          BleConnectionState.disconnected,
        ]),
      );

      await service.connect();
      await service.disconnect();
    });

    test('Data parsing: valid incoming message', () async {
      final dataList = <String>[];
      service.incomingData.listen((data) => dataList.add(data));

      // Expose the internal parser logic for testing
      service.handleRawData(utf8.encode('HELLO_FROM_ESP32'));
      service.handleRawData(utf8.encode('TEST=42'));

      await Future.delayed(Duration.zero);

      expect(dataList, equals(['HELLO_FROM_ESP32', 'TEST=42']));
    });

    test('Data parsing: empty message is ignored', () async {
      final dataList = <String>[];
      service.incomingData.listen((data) => dataList.add(data));

      service.handleRawData([]);
      service.handleRawData(utf8.encode(''));

      await Future.delayed(Duration.zero);

      expect(dataList, isEmpty);
    });

    test('Data parsing: malformed UTF-8 is handled gracefully', () async {
      final dataList = <String>[];
      service.incomingData.listen((data) => dataList.add(data));

      // Send invalid UTF-8 bytes
      service.handleRawData([0xFF, 0xFE, 0xFD]);
      service.handleRawData(utf8.encode('VALID'));

      await Future.delayed(Duration.zero);

      // The malformed data should be dropped, valid data passes
      expect(dataList, equals(['VALID']));
    });

    test('Disconnecting cleans up subscriptions', () async {
      // Connect to set up fake internal subscriptions if any
      await service.connect();
      expect(service.isSubscribed, isFalse); // Because device is null in mock, it short-circuits discovery
      
      // We can manually set the flag to test cleanup
      service.setMockSubscribed(true);
      expect(service.isSubscribed, isTrue);

      await service.disconnect();
      await Future.delayed(Duration.zero);
      
      // Disconnect triggers state change to disconnected, which triggers _cleanupSubscription
      expect(service.isSubscribed, isFalse);
    });
  });
}
