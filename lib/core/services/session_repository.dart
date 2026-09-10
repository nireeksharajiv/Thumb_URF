import 'local_monitoring_session_repository.dart';

/// In-memory & locally persistent store for completed `MonitoringSession`s.
///
/// Extends [LocalMonitoringSessionRepository] for backward compatibility with
/// Step 6 tests and controllers while implementing the full
/// `MonitoringSessionRepository` contract.
class SessionRepository extends LocalMonitoringSessionRepository {
  SessionRepository({super.storageFile});
}
