import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/models/research_settings.dart';

/// Application service managing user preferences and research telemetry thresholds.
///
/// Implements [ChangeNotifier] so UI components react instantly to threshold updates.
/// Persists settings locally using pure [dart:io] atomic writes, with full in-memory
/// isolation available for unit and widget tests.
class SettingsService extends ChangeNotifier {
  SettingsService({
    File? storageFile,
    bool isInitialized = false,
  })  : _customStorageFile = storageFile {
    _isInitialized = isInitialized;
  }

  final File? _customStorageFile;
  File? _resolvedFile;
  bool _isInitialized = false;

  ResearchSettings _settings = ResearchSettings.defaults();

  /// Current active research settings and user preferences.
  ResearchSettings get settings => _settings;

  bool get isInitialized => _isInitialized;

  /// Loads persisted settings if available.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _file;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _settings = ResearchSettings.fromJson(decoded);
          }
        }
      }
    } catch (e) {
      debugPrint('SettingsService: Failed to read settings file: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Updates the research force exceedance threshold with safety clamping [0.5, 10.0] N.
  Future<void> updateForceThreshold(double value) async {
    final clamped = value.clamp(0.5, 10.0);
    _settings = _settings.copyWith(forceThreshold: clamped);
    notifyListeners();
    await _persist();
  }

  /// Updates the angular velocity threshold with safety clamping [10.0, 150.0] °/s.
  Future<void> updateAngularVelocityThreshold(double value) async {
    final clamped = value.clamp(10.0, 150.0);
    _settings = _settings.copyWith(angularVelocityThreshold: clamped);
    notifyListeners();
    await _persist();
  }

  /// Updates the reference movement frequency baseline with safety clamping [10.0, 80.0] /min.
  Future<void> updateRefMovementsPerMinute(double value) async {
    final clamped = value.clamp(10.0, 80.0);
    _settings = _settings.copyWith(refMovementsPerMinute: clamped);
    notifyListeners();
    await _persist();
  }

  /// Updates the application theme mode preference.
  Future<void> updateThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _persist();
  }

  /// Toggles automatic cloud synchronization on session completion.
  Future<void> updateAutoCloudSync(bool enabled) async {
    _settings = _settings.copyWith(autoCloudSync: enabled);
    notifyListeners();
    await _persist();
  }

  /// Resets all research thresholds and preferences to default baselines.
  Future<void> resetToDefaults() async {
    _settings = ResearchSettings.defaults();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    if (_customStorageFile == null && _resolvedFile == null && _isInitialized) {
      // In-memory test instance: skip disk persistence
      return;
    }
    try {
      final file = await _file;
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      final jsonStr = jsonEncode(_settings.toJson());
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonStr, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
    } catch (e) {
      debugPrint('SettingsService: Failed to persist settings: $e');
    }
  }

  Future<File> get _file async {
    final custom = _customStorageFile;
    if (custom != null) return custom;
    final resolved = _resolvedFile;
    if (resolved != null) return resolved;
    final defaultFile = await _resolveDefaultFile();
    _resolvedFile = defaultFile;
    return defaultFile;
  }

  static Future<File> _resolveDefaultFile() async {
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
      return File('${dir.path}/app_settings.json');
    } catch (_) {
      return File('${Directory.systemTemp.path}/thumb_biomech_settings.json');
    }
  }
}
