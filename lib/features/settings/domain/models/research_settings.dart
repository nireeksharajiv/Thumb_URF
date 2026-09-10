import 'package:flutter/material.dart';

/// Research configuration and application preferences for biomechanical monitoring.
///
/// All threshold parameters are adjustable experimental research baselines
/// and are strictly **not** clinical diagnostic thresholds or medical limits.
@immutable
class ResearchSettings {
  const ResearchSettings({
    this.forceThreshold = 2.5,
    this.angularVelocityThreshold = 40.0,
    this.refMovementsPerMinute = 30.0,
    this.themeMode = ThemeMode.system,
    this.autoCloudSync = false,
    this.samplingRateHz = 10,
  });

  /// Factory constructor for default research configurations.
  factory ResearchSettings.defaults() => const ResearchSettings();

  /// Minimum thumb-tip contact force (N) considered an exposure event.
  /// Bounded between 0.5 N and 10.0 N.
  final double forceThreshold;

  /// Minimum angular velocity (°/s) considered rapid motion dynamics.
  /// Bounded between 10.0 °/s and 150.0 °/s.
  final double angularVelocityThreshold;

  /// Reference movement frequency (movements/min) for exposure normalization.
  /// Bounded between 10.0 /min and 80.0 /min.
  final double refMovementsPerMinute;

  /// App appearance theme mode (system, light, dark).
  final ThemeMode themeMode;

  /// Whether completed monitoring sessions automatically trigger a cloud sync.
  final bool autoCloudSync;

  /// Polling frequency of the sensor telemetry stream in Hertz.
  final int samplingRateHz;

  ResearchSettings copyWith({
    double? forceThreshold,
    double? angularVelocityThreshold,
    double? refMovementsPerMinute,
    ThemeMode? themeMode,
    bool? autoCloudSync,
    int? samplingRateHz,
  }) =>
      ResearchSettings(
        forceThreshold: forceThreshold ?? this.forceThreshold,
        angularVelocityThreshold:
            angularVelocityThreshold ?? this.angularVelocityThreshold,
        refMovementsPerMinute:
            refMovementsPerMinute ?? this.refMovementsPerMinute,
        themeMode: themeMode ?? this.themeMode,
        autoCloudSync: autoCloudSync ?? this.autoCloudSync,
        samplingRateHz: samplingRateHz ?? this.samplingRateHz,
      );

  Map<String, dynamic> toJson() => {
        'force_threshold': forceThreshold,
        'angular_velocity_threshold': angularVelocityThreshold,
        'ref_movements_per_minute': refMovementsPerMinute,
        'theme_mode': themeMode.name,
        'auto_cloud_sync': autoCloudSync,
        'sampling_rate_hz': samplingRateHz,
      };

  factory ResearchSettings.fromJson(Map<String, dynamic> json) {
    ThemeMode parseTheme(dynamic val) {
      if (val is String) {
        return ThemeMode.values.firstWhere(
          (m) => m.name == val,
          orElse: () => ThemeMode.system,
        );
      }
      return ThemeMode.system;
    }

    return ResearchSettings(
      forceThreshold: (json['force_threshold'] as num?)?.toDouble() ?? 2.5,
      angularVelocityThreshold:
          (json['angular_velocity_threshold'] as num?)?.toDouble() ?? 40.0,
      refMovementsPerMinute:
          (json['ref_movements_per_minute'] as num?)?.toDouble() ?? 30.0,
      themeMode: parseTheme(json['theme_mode']),
      autoCloudSync: json['auto_cloud_sync'] as bool? ?? false,
      samplingRateHz: (json['sampling_rate_hz'] as num?)?.toInt() ?? 10,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResearchSettings &&
          runtimeType == other.runtimeType &&
          forceThreshold == other.forceThreshold &&
          angularVelocityThreshold == other.angularVelocityThreshold &&
          refMovementsPerMinute == other.refMovementsPerMinute &&
          themeMode == other.themeMode &&
          autoCloudSync == other.autoCloudSync &&
          samplingRateHz == other.samplingRateHz;

  @override
  int get hashCode => Object.hash(
        forceThreshold,
        angularVelocityThreshold,
        refMovementsPerMinute,
        themeMode,
        autoCloudSync,
        samplingRateHz,
      );
}
