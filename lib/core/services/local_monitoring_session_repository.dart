import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/monitoring_session.dart';
import '../models/sensor_reading.dart';
import 'monitoring_session_repository.dart';

/// True local-first persistence implementation of [MonitoringSessionRepository].
///
/// Stores completed [MonitoringSession] summaries and full [SensorReading]
/// time-series batches to non-volatile local disk storage using standard [dart:io]
/// file operations with atomic write semantics.
/// Operates seamlessly offline and in Demo Mode with zero cloud dependencies.
class LocalMonitoringSessionRepository extends ChangeNotifier
    implements MonitoringSessionRepository {
  LocalMonitoringSessionRepository({
    File? storageFile,
    bool isInitialized = false,
  })  : _customStorageFile = storageFile {
    _isInitialized = isInitialized;
  }

  final File? _customStorageFile;
  File? _resolvedFile;
  bool _isInitialized = false;

  final List<MonitoringSession> _sessions = [];
  final Map<String, List<SensorReading>> _readingsBySession = {};

  bool get isInitialized => _isInitialized;

  /// Synchronous unmodifiable view of all completed sessions (oldest first).
  /// Maintained for backwards compatibility with Step 6.
  List<MonitoringSession> get sessions => List.unmodifiable(_sessions);

  /// Resolves the file reference to use for local persistence.
  Future<File> get _file async {
    final custom = _customStorageFile;
    if (custom != null) return custom;
    final resolved = _resolvedFile;
    if (resolved != null) return resolved;
    final defaultFile = await _resolveDefaultStorageFile();
    _resolvedFile = defaultFile;
    return defaultFile;
  }

  /// Locates the appropriate OS-level user data directory in pure [dart:io].
  static Future<File> _resolveDefaultStorageFile() async {
    try {
      String basePath;
      if (Platform.isWindows) {
        basePath = Platform.environment['LOCALAPPDATA'] ??
            Platform.environment['APPDATA'] ??
            Directory.current.path;
      } else if (Platform.isMacOS) {
        basePath = '${Platform.environment['HOME']}/Library/Application Support';
      } else if (Platform.isLinux) {
        basePath = Platform.environment['XDG_DATA_HOME'] ??
            '${Platform.environment['HOME']}/.local/share';
      } else {
        basePath = Directory.systemTemp.path;
      }

      final dir = Directory('$basePath/ThumbBiomech');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return File('${dir.path}/monitoring_sessions_local.json');
    } catch (_) {
      return File('${Directory.systemTemp.path}/thumb_biomech_sessions.json');
    }
  }

  /// Asynchronously loads previously persisted sessions and sensor readings.
  ///
  /// Starts clean if the file does not exist. Gracefully ignores malformed or
  /// corrupt data without crashing the application.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _file;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(content);
            if (decoded is Map<String, dynamic>) {
              _loadFromMap(decoded);
            }
          } catch (e) {
            debugPrint('LocalMonitoringSessionRepository: Malformed data ignored: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('LocalMonitoringSessionRepository: Initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _loadFromMap(Map<String, dynamic> json) {
    final sessionList = json['sessions'];
    if (sessionList is List) {
      for (final raw in sessionList) {
        if (raw is Map<String, dynamic>) {
          try {
            final s = MonitoringSession.fromJson(raw);
            if (!_sessions.any((existing) => existing.id == s.id)) {
              _sessions.add(s);
            }
          } catch (_) {}
        }
      }
    }

    final rawReadings = json['readings'];
    if (rawReadings is Map<String, dynamic>) {
      rawReadings.forEach((sessionId, list) {
        if (list is List) {
          final readings = list
              .whereType<Map<String, dynamic>>()
              .map((item) {
                try {
                  return SensorReading.fromJson(item);
                } catch (_) {
                  return null;
                }
              })
              .whereType<SensorReading>()
              .toList();
          _readingsBySession[sessionId] = readings;
        }
      });
    }
  }

  /// Atomically commits current state to disk using a temporary file.
  Future<void> _persistToDisk() async {
    if (_customStorageFile == null && _resolvedFile == null && _isInitialized) {
      return;
    }
    try {
      final file = await _file;
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final jsonStr = exportToJsonString();
      final tempFile = File('${file.path}.tmp');

      // Write atomically to temporary file first
      await tempFile.writeAsString(jsonStr, flush: true);

      // Safely replace main persistence file
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (e) {
      debugPrint('LocalMonitoringSessionRepository: Failed to persist to disk: $e');
    }
  }

  /// Synchronously adds a completed [session], notifies listeners, and schedules persistence.
  /// Maintained for backwards compatibility with Step 6 test suites.
  void add(MonitoringSession session) {
    final existingIndex = _sessions.indexWhere((s) => s.id == session.id);
    if (existingIndex >= 0) {
      _sessions[existingIndex] = session;
    } else {
      _sessions.add(session);
    }
    notifyListeners();
    unawaited(_persistToDisk());
  }

  /// Clears all stored sessions and sensor readings, updating disk storage.
  void clear() {
    _sessions.clear();
    _readingsBySession.clear();
    notifyListeners();
    unawaited(_persistToDisk());
  }

  @override
  Future<void> saveSession(
    MonitoringSession session, {
    List<SensorReading>? readings,
  }) async {
    if (!_isInitialized) await init();

    final existingIndex = _sessions.indexWhere((s) => s.id == session.id);
    if (existingIndex >= 0) {
      _sessions[existingIndex] = session;
    } else {
      _sessions.add(session);
    }

    if (readings != null && readings.isNotEmpty) {
      _readingsBySession[session.id] = List.unmodifiable(readings);
    }

    notifyListeners();
    await _persistToDisk();
  }

  @override
  Future<List<MonitoringSession>> getSessions() async {
    if (!_isInitialized) await init();

    final sorted = List<MonitoringSession>.from(_sessions);
    sorted.sort((a, b) => b.startTime.compareTo(a.startTime));
    return List.unmodifiable(sorted);
  }

  @override
  Future<MonitoringSession?> getSessionById(String id) async {
    if (!_isInitialized) await init();

    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  @override
  Future<void> deleteSession(String id) async {
    if (!_isInitialized) await init();

    _sessions.removeWhere((s) => s.id == id);
    _readingsBySession.remove(id);
    notifyListeners();
    await _persistToDisk();
  }

  @override
  Future<void> saveSensorReadings(
    String sessionId,
    List<SensorReading> readings,
  ) async {
    if (readings.isEmpty) return;
    if (!_isInitialized) await init();

    final current = _readingsBySession[sessionId] ?? [];
    _readingsBySession[sessionId] = List.unmodifiable([...current, ...readings]);
    await _persistToDisk();
  }

  @override
  Future<List<SensorReading>> getSensorReadings(String sessionId) async {
    if (!_isInitialized) await init();

    final list = _readingsBySession[sessionId];
    if (list == null) return const [];
    return List.unmodifiable(list);
  }

  // ── JSON Serialization Helpers ────────────────────────────────────────────

  Map<String, dynamic> exportToJson() => {
        'sessions': _sessions.map((s) => s.toJson()).toList(),
        'readings': _readingsBySession.map(
          (sessionId, readings) => MapEntry(
            sessionId,
            readings.map((r) => r.toJson()).toList(),
          ),
        ),
      };

  void importFromJson(Map<String, dynamic> json, {bool clearExisting = false}) {
    if (clearExisting) {
      _sessions.clear();
      _readingsBySession.clear();
    }
    _loadFromMap(json);
    notifyListeners();
  }

  String exportToJsonString() => jsonEncode(exportToJson());

  void importFromJsonString(String jsonString, {bool clearExisting = false}) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    importFromJson(decoded, clearExisting: clearExisting);
  }
}
