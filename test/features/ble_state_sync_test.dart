import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


import 'package:thumb_biomech_monitor_glove/services/ble/ble_sensor_service.dart';
import 'package:thumb_biomech_monitor_glove/features/home/presentation/home_page.dart';
import 'package:thumb_biomech_monitor_glove/features/monitoring/presentation/live_monitoring_page.dart';
import 'package:thumb_biomech_monitor_glove/features/device/presentation/device_page.dart';

class FakeBleSensorService implements BleSensorService {
  BleConnectionState _state = BleConnectionState.disconnected;
  final StreamController<BleConnectionState> _stateController = StreamController<BleConnectionState>.broadcast();
  final StreamController<String> _dataController = StreamController<String>.broadcast();

  bool isConnectedCalled = false;
  bool isDisconnectedCalled = false;
  int disposeCallCount = 0;

  void emitState(BleConnectionState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void emitData(String data) {
    _dataController.add(data);
  }

  @override
  BleConnectionState get state => _state;

  @override
  Stream<BleConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<String> get incomingData => _dataController.stream;

  @override
  Future<void> connect() async {
    isConnectedCalled = true;
    emitState(BleConnectionState.connecting);
    emitState(BleConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    isDisconnectedCalled = true;
    emitState(BleConnectionState.disconnecting);
    emitState(BleConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await _stateController.close();
    await _dataController.close();
  }
  
  @override
  bool get isSubscribed => true;
  
  @override
  void handleRawData(List<int> value) {}
  
  @override
  void setMockSubscribed(bool value) {}
}

void main() {
  group('BLE State Synchronization Tests', () {
    late FakeBleSensorService fakeBleService;

    setUp(() {
      fakeBleService = FakeBleSensorService();
    });

    Widget buildPage(Widget child) {
      return MaterialApp(
        home: Scaffold(body: child),
      );
    }

    testWidgets('TEST 1: Connect BLE device -> shared state = connected', (tester) async {
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      
      // Initially disconnected
      expect(find.text('No device connected'), findsOneWidget);
      expect(fakeBleService.state, BleConnectionState.disconnected);
      
      // Trigger connect (simulating successful permission & connect)
      await fakeBleService.connect();
      await tester.pump(); 
      await tester.pump(const Duration(milliseconds: 100)); 
      
      expect(fakeBleService.state, BleConnectionState.connected);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('TEST 2: Home observes connected state', (tester) async {
      fakeBleService.emitState(BleConnectionState.connected);
      await tester.pumpWidget(buildPage(HomePage(bleService: fakeBleService)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('TEST 3: Monitor observes connected state', (tester) async {
      fakeBleService.emitState(BleConnectionState.connected);
      await tester.pumpWidget(buildPage(LiveMonitoringPage(bleService: fakeBleService)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('CONNECTED'), findsOneWidget);
    });

    testWidgets('TEST 4: Connect page observes connected state', (tester) async {
      fakeBleService.emitState(BleConnectionState.connected);
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('TEST 5: Navigate: Connect -> Home -> Monitor -> Connect and state remains Connected', (tester) async {
      fakeBleService.emitState(BleConnectionState.connected);
      
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Connected'), findsOneWidget);
      
      await tester.pumpWidget(buildPage(HomePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Connected'), findsOneWidget);
      
      await tester.pumpWidget(buildPage(LiveMonitoringPage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('CONNECTED'), findsOneWidget);
      
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('TEST 6: Disconnect -> all pages show disconnected', (tester) async {
      fakeBleService.emitState(BleConnectionState.connected);
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      await tester.tap(find.text('Disconnect'));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      expect(fakeBleService.state, BleConnectionState.disconnected);
      
      await tester.pumpWidget(buildPage(HomePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Not connected'), findsOneWidget);
      
      await tester.pumpWidget(buildPage(LiveMonitoringPage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('NOT CONNECTED'), findsOneWidget);
    });

    testWidgets('TEST 7: Unexpected BLE disconnect -> all pages update to disconnected', (tester) async {
      fakeBleService.emitState(BleConnectionState.connected);
      
      await tester.pumpWidget(buildPage(HomePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Connected'), findsOneWidget);
      
      fakeBleService.emitState(BleConnectionState.disconnected);
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('TEST 8: Rebuilding/recreating DevicePage does NOT reset connection state', (tester) async {
      fakeBleService.emitState(BleConnectionState.connected);
      
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Connected'), findsOneWidget);
      
      await tester.pumpWidget(Container()); 
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService))); 
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.text('Connected'), findsOneWidget);
      expect(fakeBleService.disposeCallCount, 0); 
    });

    testWidgets('TEST 9: No duplicate BLE managers are created for different pages', (tester) async {
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      await tester.pumpWidget(buildPage(HomePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      expect(fakeBleService.disposeCallCount, 0);
    });

    testWidgets('TEST 10: BLE data notifications continue after navigating between pages', (tester) async {
      fakeBleService.emitState(BleConnectionState.connected);
      
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      fakeBleService.emitData("TestData123");
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.textContaining('TestData123'), findsOneWidget);
      
      await tester.pumpWidget(buildPage(HomePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      await tester.pumpWidget(buildPage(DevicePage(bleService: fakeBleService)));
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      fakeBleService.emitData("NewData456");
      await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.textContaining('NewData456'), findsOneWidget);
    });
  });
}
