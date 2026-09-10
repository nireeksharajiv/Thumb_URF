import 'package:flutter/foundation.dart';

/// State of synchronization between local storage and Supabase cloud.
enum SyncState {
  localOnly('Local'),
  syncing('Syncing...'),
  synced('Synced'),
  syncFailed('Sync Failed');

  const SyncState(this.displayName);

  final String displayName;
}

/// Metadata and status for an individual monitoring session's synchronization.
@immutable
class SessionSyncInfo {
  const SessionSyncInfo({
    required this.sessionId,
    required this.state,
    this.syncedAt,
    this.errorMessage,
  });

  final String sessionId;
  final SyncState state;
  final DateTime? syncedAt;
  final String? errorMessage;

  bool get isSynced => state == SyncState.synced;
  bool get isSyncing => state == SyncState.syncing;
  bool get isFailed => state == SyncState.syncFailed;

  SessionSyncInfo copyWith({
    String? sessionId,
    SyncState? state,
    DateTime? syncedAt,
    String? errorMessage,
  }) {
    return SessionSyncInfo(
      sessionId: sessionId ?? this.sessionId,
      state: state ?? this.state,
      syncedAt: syncedAt ?? this.syncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'state': state.name,
        'syncedAt': syncedAt?.toUtc().toIso8601String(),
        'errorMessage': errorMessage,
      };

  factory SessionSyncInfo.fromJson(Map<String, dynamic> json) {
    return SessionSyncInfo(
      sessionId: json['sessionId'] as String,
      state: SyncState.values.byName(json['state'] as String),
      syncedAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String).toUtc()
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSyncInfo &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          state == other.state &&
          syncedAt == other.syncedAt &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(sessionId, state, syncedAt, errorMessage);

  @override
  String toString() =>
      'SessionSyncInfo(sessionId: $sessionId, state: ${state.name}, syncedAt: $syncedAt, error: $errorMessage)';
}
