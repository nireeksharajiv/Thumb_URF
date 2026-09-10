/// Base exception for all Supabase-related errors.
abstract class SupabaseException implements Exception {
  const SupabaseException(this.message);

  /// User-friendly, non-technical explanation of the failure.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when Supabase configuration is missing or malformed.
class SupabaseConfigException extends SupabaseException {
  const SupabaseConfigException(super.message);
}

/// Thrown when an authentication operation fails (sign up, sign in, session).
class SupabaseAuthException extends SupabaseException {
  const SupabaseAuthException(super.message, {this.technicalDetails});

  /// Optional internal technical message (for debug logs, never shown raw in UI).
  final String? technicalDetails;

  @override
  String toString() {
    if (technicalDetails != null) {
      return '$runtimeType: $message (Details: $technicalDetails)';
    }
    return super.toString();
  }
}

/// Thrown when a database or repository operation fails.
class SupabaseRepositoryException extends SupabaseException {
  const SupabaseRepositoryException(super.message, {this.technicalDetails});

  /// Optional internal technical message (for debug logs, never shown raw in UI).
  final String? technicalDetails;

  @override
  String toString() {
    if (technicalDetails != null) {
      return '$runtimeType: $message (Details: $technicalDetails)';
    }
    return super.toString();
  }
}
