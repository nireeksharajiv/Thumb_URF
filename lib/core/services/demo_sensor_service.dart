import 'dart:async';
import 'dart:math' as math;

import '../models/sensor_reading.dart';
import 'sensor_data_source.dart';

/// Smooth, simulated glove readings for non-diagnostic prototype monitoring.
class DemoSensorService implements SensorDataSource {
  DemoSensorService({
    this.samplingInterval = const Duration(milliseconds: 100),
  });

  final Duration samplingInterval;
  final StreamController<SensorReading> _controller =
      StreamController<SensorReading>.broadcast();
  Timer? _timer;
  var _sampleIndex = 0;
  var _isPaused = false;
  var _isDisposed = false;

  @override
  Stream<SensorReading> get readings => _controller.stream;

  @override
  Future<void> start() async {
    _ensureNotDisposed();
    if (_timer != null) return;
    _isPaused = false;
    _emitReading();
    _timer = Timer.periodic(samplingInterval, (_) => _emitReading());
  }

  @override
  Future<void> pause() async {
    _ensureNotDisposed();
    _timer?.cancel();
    _timer = null;
    _isPaused = true;
  }

  @override
  Future<void> resume() async {
    _ensureNotDisposed();
    if (!_isPaused) return;
    _isPaused = false;
    _emitReading();
    _timer = Timer.periodic(samplingInterval, (_) => _emitReading());
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isPaused = false;
    _sampleIndex = 0;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    await stop();
    _isDisposed = true;
    await _controller.close();
  }

  void _emitReading() {
    if (_isDisposed || _controller.isClosed) return;
    final time =
        _sampleIndex *
        samplingInterval.inMicroseconds /
        Duration.microsecondsPerSecond;
    _sampleIndex++;

    final activity = (math.sin(time * 1.15) + 1) / 2;
    final movement = math.sin(time * 1.4);
    _controller.add(
      SensorReading(
        timestamp: DateTime.now(),
        ipAngle: 10 + (70 * activity),
        mcpAngle: 10 + (50 * ((math.sin(time * 1.05 + 0.7) + 1) / 2)),
        force: 0.15 + (7.5 * activity * activity),
        angularVelocity: movement * (25 + (75 * activity)),
        motionMagnitude: 0.05 + (2.2 * activity),
      ),
    );
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('DemoSensorService has been disposed.');
    }
  }
}
