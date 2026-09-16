/// BLE Protocol Definitions
///
/// Contains centralized constants for BLE Service UUIDs,
/// Characteristic UUIDs, and expected Device Names.
class BleProtocol {
  // Prevent instantiation
  BleProtocol._();

  /// The exact expected device name for the ESP32 Glove.
  static const String deviceName = 'ThumbTrace Glove';

  /// The primary BLE service UUID exposed by the ESP32.
  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';

  /// The characteristic UUID used for incoming data notifications.
  static const String characteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
}
