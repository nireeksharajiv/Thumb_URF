import 'dart:async';
import 'package:flutter/foundation.dart';

import '../errors/supabase_exceptions.dart';
import '../models/monitoring_session.dart';
import '../models/sync_status.dart';
import 'auth_repository.dart';
import 'local_monitoring_session_repository.dart';
import 'monitoring_session_repository.dart';

/// Central coordinator managing the synchronization of completed monitoring sessions
/// and time-series sensor readings between local storage and Supabase cloud.
///
/// **Data Integrity Guarantees**:
/// - Local data is never deleted or overwritten on upload failure.
/// - Uploads are strictly bound to the authenticated user ID.
/// - Uploads are idempotent: syncing a session multiple times will not duplicate records.
class SessionSyncService extends ChangeNotifier {
  SessionSyncService({
    required this.localRepository,
    required this.cloudRepository,
    this.authRepository,
  });

  final LocalMonitoringSessionRepository localRepository;
  final MonitoringSessionRepository cloudRepository;
  final AuthRepository? authRepository;

  final Map<String, SessionSyncInfo> _syncStates = {};

  /// Current sync states for all tracked sessions.
  Map<String, SessionSyncInfo> get syncStates => Map.unmodifiable(_syncStates);

  /// Returns the current [SyncState] for [sessionId], defaulting to [SyncState.localOnly].
  SyncState getSyncState(String sessionId) {
    return _syncStates[sessionId]?.state ?? SyncState.localOnly;
  }

  /// Returns the full [SessionSyncInfo] metadata for [sessionId] if tracked.
  SessionSyncInfo? getSyncInfo(String sessionId) {
    return _syncStates[sessionId];
  }

  /// Synchronizes a single completed session and its sensor readings to the cloud.
  Future<SessionSyncInfo> syncSession(String sessionId) async {
    // 1. Check authentication
    final isAuth = authRepository?.isAuthenticated ?? false;
    if (!isAuth) {
      final failedInfo = SessionSyncInfo(
        sessionId: sessionId,
        state: SyncState.syncFailed,
        errorMessage: 'Authentication required. Please sign in to sync with Supabase cloud.',
      );
      _syncStates[sessionId] = failedInfo;
      notifyListeners();
      return failedInfo;
    }

    // 2. Load local session
    final localSession = await localRepository.getSessionById(sessionId);
    if (localSession == null) {
      final notFoundInfo = SessionSyncInfo(
        sessionId: sessionId,
        state: SyncState.syncFailed,
        errorMessage: 'Local session not found.',
      );
      _syncStates[sessionId] = notFoundInfo;
      notifyListeners();
      return notFoundInfo;
    }

    // 3. Mark in-progress
    _syncStates[sessionId] = SessionSyncInfo(
      sessionId: sessionId,
      state: SyncState.syncing,
    );
    notifyListeners();

    // 4. Perform upload with local data preservation
    try {
      final readings = await localRepository.getSensorReadings(sessionId);
      await cloudRepository.saveSession(localSession, readings: readings);

      final successInfo = SessionSyncInfo(
        sessionId: sessionId,
        state: SyncState.synced,
        syncedAt: DateTime.now().toUtc(),
      );
      _syncStates[sessionId] = successInfo;
      notifyListeners();
      return successInfo;
    } catch (e) {
      // Offline / Network / Cloud error: preserve local session untouched
      final String message;
      if (e is SupabaseException) {
        message = e.message;
      } else {
        message =
            'Unable to sync this session. Your local data is saved safely. Please retry when connection is available.';
      }
      final failedInfo = SessionSyncInfo(
        sessionId: sessionId,
        state: SyncState.syncFailed,
        errorMessage: message,
      );
      _syncStates[sessionId] = failedInfo;
      notifyListeners();
      return failedInfo;
    }
  }

  /// Synchronizes all local sessions that are not yet marked as [SyncState.synced].
  Future<int> syncAllUnsynced() async {
    final sessions = await localRepository.getSessions();
    int syncedCount = 0;

    for (final s in sessions) {
      if (getSyncState(s.id) != SyncState.synced) {
        final result = await syncSession(s.id);
        if (result.isSynced) syncedCount++;
      }
    }

    return syncedCount;
  }

  /// Pulls the authenticated user's sessions from Supabase cloud and merges them
  /// into the local repository if not already present.
  Future<List<MonitoringSession>> pullCloudSessions() async {
    final isAuth = authRepository?.isAuthenticated ?? false;
    if (!isAuth) return const [];

    try {
      final cloudSessions = await cloudRepository.getSessions();

      for (final cs in cloudSessions) {
        final localExisting = await localRepository.getSessionById(cs.id);
        if (localExisting == null) {
          final readings = await cloudRepository.getSensorReadings(cs.id);
          await localRepository.saveSession(cs, readings: readings);
        }
        _syncStates[cs.id] = SessionSyncInfo(
          sessionId: cs.id,
          state: SyncState.synced,
          syncedAt: DateTime.now().toUtc(),
        );
      }

      notifyListeners();
      return cloudSessions;
    } catch (_) {
      return const [];
    }
  }
}
