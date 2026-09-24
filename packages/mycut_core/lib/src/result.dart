import 'package:mycut_core/src/failures.dart';

/// A discriminated union for operation results.
///
/// Every network-touching repository method returns `Result<T, Failure>`
/// instead of throwing exceptions across layer boundaries.
///
/// Usage:
/// ```dart
/// final result = await repo.fetchLook(id);
/// switch (result) {
///   case Success(:final value):
///     // use value
///   case Error(:final failure):
///     // handle failure
/// }
/// ```
sealed class Result<T, F extends Failure> {
  const Result();

  /// Whether this result is a success.
  bool get isSuccess => this is Success<T, F>;

  /// Whether this result is an error.
  bool get isError => this is Error<T, F>;

  /// Returns the success value or throws if this is an error.
  ///
  /// Prefer pattern matching over this method.
  T get valueOrThrow {
    return switch (this) {
      Success(:final value) => value,
      Error(:final failure) => throw Exception(failure.message),
    };
  }

  /// Maps the success value to a new type.
  Result<U, F> map<U>(U Function(T value) transform) {
    return switch (this) {
      Success(:final value) => Success(transform(value)),
      Error(:final failure) => Error(failure),
    };
  }

  /// Flat-maps the success value to a new Result.
  Result<U, F> flatMap<U>(Result<U, F> Function(T value) transform) {
    return switch (this) {
      Success(:final value) => transform(value),
      Error(:final failure) => Error(failure),
    };
  }
}

/// A successful result wrapping [value].
class Success<T, F extends Failure> extends Result<T, F> {
  const Success(this.value);

  /// The successful value.
  final T value;
}

/// A failed result wrapping [failure].
class Error<T, F extends Failure> extends Result<T, F> {
  const Error(this.failure);

  /// The failure details.
  final F failure;
}
