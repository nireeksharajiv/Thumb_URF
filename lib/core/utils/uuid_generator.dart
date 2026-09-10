import 'dart:math';

/// Generates a standard RFC-4122 version 4 UUID.
///
/// Uses [Random.secure] to produce cryptographically strong pseudo-random
/// values without requiring additional third-party dependencies.
String generateUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  // Set version to 4 (0100 in bits 4-7 of time_hi_and_version)
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Set variant to 10xx (RFC-4122)
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String toHex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${toHex(0, 4)}-${toHex(4, 6)}-${toHex(6, 8)}-${toHex(8, 10)}-${toHex(10, 16)}';
}
