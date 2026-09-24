/// Typed failure hierarchy for MyCut.
///
/// Every repository method returns [Result<T, Failure>], never throws
/// across a layer boundary.
sealed class Failure {
  const Failure({required this.message, this.stackTrace});

  /// Human-readable error description.
  final String message;

  /// Optional stack trace for debugging.
  final StackTrace? stackTrace;

  @override
  String toString() => 'Failure($message)';
}

/// A network-level failure (timeout, no connectivity, DNS).
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.stackTrace});
}

/// Authentication or authorization failure.
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.stackTrace});
}

/// Server returned an error (5xx, unexpected response shape).
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.stackTrace,
    this.statusCode,
  });

  /// HTTP status code, if available.
  final int? statusCode;
}

/// Validation failure (bad input, constraint violation).
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.stackTrace});
}

/// Storage failure (file upload/download, signed URL).
class StorageFailure extends Failure {
  const StorageFailure({required super.message, super.stackTrace});
}

/// The requested resource was not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message, super.stackTrace});
}

/// The user has insufficient credits for the operation.
class InsufficientCreditsFailure extends Failure {
  const InsufficientCreditsFailure({required super.message, super.stackTrace});
}

/// A catch-all for unexpected errors during development.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.stackTrace});
}
