import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/errors/supabase_exceptions.dart';
import 'package:thumb_biomech_monitor_glove/core/models/monitoring_session.dart';
import 'package:thumb_biomech_monitor_glove/core/services/auth_service.dart';
import 'package:thumb_biomech_monitor_glove/core/services/supabase_service.dart';
import 'package:thumb_biomech_monitor_glove/core/services/supabase_session_repository.dart';

void main() {
  group('SupabaseSessionRepository & AuthService uninitialized handling', () {
    setUp(() {
      SupabaseService.instance.setClientForTesting(null);
    });

    test('Repository throws SupabaseConfigException when client is uninitialized', () async {
      final repository = SupabaseSessionRepository();

      final session = MonitoringSession(
        id: 's-1',
        startTime: DateTime.utc(2026, 9, 10, 10),
        endTime: DateTime.utc(2026, 9, 10, 10, 1),
        movementCount: 0,
        averageIpAngle: 0,
        maximumIpAngle: 0,
        averageMcpAngle: 0,
        maximumMcpAngle: 0,
        averageForce: 0,
        peakForce: 0,
        averageAngularVelocity: 0,
        averageMotionMagnitude: 0,
      );

      expect(
        () => repository.saveSession(session, userId: 'u-1'),
        throwsA(isA<SupabaseConfigException>()),
      );

      expect(
        () => repository.fetchSessions(userId: 'u-1'),
        throwsA(isA<SupabaseConfigException>()),
      );

      expect(
        () => repository.saveReadings([], sessionId: 's-1'),
        returnsNormally,
      );
    });

    test('AuthService throws SupabaseConfigException when client is uninitialized', () async {
      final auth = AuthService();

      expect(auth.currentUser, isNull);
      expect(auth.currentSession, isNull);
      expect(auth.isAuthenticated, isFalse);

      expect(
        () => auth.signIn(email: 'test@example.com', password: 'password123'),
        throwsA(isA<SupabaseConfigException>()),
      );

      expect(
        () => auth.signUp(email: 'test@example.com', password: 'password123'),
        throwsA(isA<SupabaseConfigException>()),
      );

      // signOut should not throw even if uninitialized
      expect(() => auth.signOut(), returnsNormally);
    });
  });
}
