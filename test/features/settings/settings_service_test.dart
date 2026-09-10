import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/features/settings/application/settings_service.dart';
import 'package:thumb_biomech_monitor_glove/features/settings/domain/models/research_settings.dart';

void main() {
  group('ResearchSettings Model', () {
    test('instantiates with expected research defaults', () {
      final settings = ResearchSettings.defaults();

      expect(settings.forceThreshold, 2.5);
      expect(settings.angularVelocityThreshold, 40.0);
      expect(settings.refMovementsPerMinute, 30.0);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.autoCloudSync, isFalse);
      expect(settings.samplingRateHz, 10);
    });

    test('copyWith modifies only specified fields', () {
      final original = ResearchSettings.defaults();
      final modified = original.copyWith(
        forceThreshold: 4.2,
        themeMode: ThemeMode.dark,
        autoCloudSync: true,
      );

      expect(modified.forceThreshold, 4.2);
      expect(modified.angularVelocityThreshold, 40.0);
      expect(modified.themeMode, ThemeMode.dark);
      expect(modified.autoCloudSync, isTrue);
      expect(modified.samplingRateHz, 10);
    });

    test('toJson and fromJson serialize and deserialize symmetrically', () {
      const original = ResearchSettings(
        forceThreshold: 3.8,
        angularVelocityThreshold: 65.0,
        refMovementsPerMinute: 45.0,
        themeMode: ThemeMode.light,
        autoCloudSync: true,
        samplingRateHz: 20,
      );

      final json = original.toJson();
      final restored = ResearchSettings.fromJson(json);

      expect(restored, equals(original));
      expect(restored.forceThreshold, 3.8);
      expect(restored.angularVelocityThreshold, 65.0);
      expect(restored.refMovementsPerMinute, 45.0);
      expect(restored.themeMode, ThemeMode.light);
      expect(restored.autoCloudSync, isTrue);
      expect(restored.samplingRateHz, 20);
    });

    test('value equality and hashCode behave correctly', () {
      final a = ResearchSettings.defaults();
      final b = ResearchSettings.defaults();
      final c = a.copyWith(forceThreshold: 5.0);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('SettingsService Application Service', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('settings_service_test_');
      testFile = File('${tempDir.path}/settings.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('starts with defaults when file does not exist', () async {
      final service = SettingsService(storageFile: testFile);
      await service.init();

      expect(service.isInitialized, isTrue);
      expect(service.settings, equals(ResearchSettings.defaults()));
    });

    test('in-memory mode initializes and does not write to disk', () async {
      final service = SettingsService(isInitialized: true);

      expect(service.isInitialized, isTrue);
      expect(service.settings, equals(ResearchSettings.defaults()));

      var notified = false;
      service.addListener(() => notified = true);

      await service.updateForceThreshold(3.5);
      expect(notified, isTrue);
      expect(service.settings.forceThreshold, 3.5);
    });

    test('updateForceThreshold clamps values safely between [0.5, 10.0] N', () async {
      final service = SettingsService(storageFile: testFile);
      await service.init();

      await service.updateForceThreshold(0.1);
      expect(service.settings.forceThreshold, 0.5);

      await service.updateForceThreshold(15.0);
      expect(service.settings.forceThreshold, 10.0);

      await service.updateForceThreshold(5.5);
      expect(service.settings.forceThreshold, 5.5);
    });

    test('updateAngularVelocityThreshold clamps values safely between [10.0, 150.0] °/s', () async {
      final service = SettingsService(storageFile: testFile);
      await service.init();

      await service.updateAngularVelocityThreshold(5.0);
      expect(service.settings.angularVelocityThreshold, 10.0);

      await service.updateAngularVelocityThreshold(200.0);
      expect(service.settings.angularVelocityThreshold, 150.0);

      await service.updateAngularVelocityThreshold(55.0);
      expect(service.settings.angularVelocityThreshold, 55.0);
    });

    test('updateRefMovementsPerMinute clamps values safely between [10.0, 80.0] /min', () async {
      final service = SettingsService(storageFile: testFile);
      await service.init();

      await service.updateRefMovementsPerMinute(2.0);
      expect(service.settings.refMovementsPerMinute, 10.0);

      await service.updateRefMovementsPerMinute(120.0);
      expect(service.settings.refMovementsPerMinute, 80.0);

      await service.updateRefMovementsPerMinute(40.0);
      expect(service.settings.refMovementsPerMinute, 40.0);
    });

    test('updateThemeMode updates theme preference and notifies listeners', () async {
      final service = SettingsService(storageFile: testFile);
      await service.init();

      var notifications = 0;
      service.addListener(() => notifications++);

      await service.updateThemeMode(ThemeMode.dark);
      expect(service.settings.themeMode, ThemeMode.dark);
      expect(notifications, 1);
    });

    test('updateAutoCloudSync updates flag and persists to disk', () async {
      final service = SettingsService(storageFile: testFile);
      await service.init();

      await service.updateAutoCloudSync(true);
      expect(service.settings.autoCloudSync, isTrue);

      // Verify file persistence
      expect(await testFile.exists(), isTrue);

      // Reload in a separate instance
      final reloaded = SettingsService(storageFile: testFile);
      await reloaded.init();
      expect(reloaded.settings.autoCloudSync, isTrue);
    });

    test('resetToDefaults resets all fields to baseline research defaults', () async {
      final service = SettingsService(storageFile: testFile);
      await service.init();

      await service.updateForceThreshold(7.5);
      await service.updateAngularVelocityThreshold(85.0);
      await service.updateThemeMode(ThemeMode.dark);
      await service.updateAutoCloudSync(true);

      expect(service.settings, isNot(equals(ResearchSettings.defaults())));

      await service.resetToDefaults();
      expect(service.settings, equals(ResearchSettings.defaults()));
    });
  });
}
