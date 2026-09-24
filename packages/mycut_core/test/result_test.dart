import 'package:flutter_test/flutter_test.dart';
import 'package:mycut_core/mycut_core.dart';

void main() {
  group('Result', () {
    test('Success.isSuccess returns true', () {
      const result = Success<int, Failure>(42);
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
    });

    test('Error.isError returns true', () {
      const result = Error<int, Failure>(
        NetworkFailure(message: 'timeout'),
      );
      expect(result.isError, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('valueOrThrow returns value on success', () {
      const result = Success<String, Failure>('hello');
      expect(result.valueOrThrow, equals('hello'));
    });

    test('valueOrThrow throws on error', () {
      const result = Error<String, Failure>(
        AuthFailure(message: 'not logged in'),
      );
      expect(() => result.valueOrThrow, throwsException);
    });

    test('map transforms success value', () {
      const Result<int, Failure> result = Success(10);
      final mapped = result.map((v) => v * 2);
      expect(mapped, isA<Success<int, Failure>>());
      expect((mapped as Success<int, Failure>).value, equals(20));
    });

    test('map preserves error', () {
      const Result<int, Failure> result = Error(
        ServerFailure(message: 'oops', statusCode: 500),
      );
      final mapped = result.map((v) => v * 2);
      expect(mapped, isA<Error<int, Failure>>());
      final error = mapped as Error<int, Failure>;
      expect(error.failure, isA<ServerFailure>());
      expect((error.failure as ServerFailure).statusCode, equals(500));
    });

    test('flatMap chains successful results', () {
      const Result<int, Failure> result = Success(5);
      final chained = result.flatMap(
        (v) => Success<String, Failure>('value: $v'),
      );
      expect(chained, isA<Success<String, Failure>>());
      expect((chained as Success<String, Failure>).value, equals('value: 5'));
    });

    test('flatMap short-circuits on error', () {
      const Result<int, Failure> result = Error(
        NotFoundFailure(message: 'not found'),
      );
      final chained = result.flatMap(
        (v) => Success<String, Failure>('value: $v'),
      );
      expect(chained, isA<Error<String, Failure>>());
    });

    test('pattern matching works with switch', () {
      const Result<int, Failure> result = Success(42);

      final message = switch (result) {
        Success(:final value) => 'Got $value',
        Error(:final failure) => 'Failed: ${failure.message}',
      };

      expect(message, equals('Got 42'));
    });
  });

  group('Failure subtypes', () {
    test('all subtypes have message', () {
      final failures = <Failure>[
        const NetworkFailure(message: 'timeout'),
        const AuthFailure(message: 'unauthorized'),
        const ServerFailure(message: 'internal error', statusCode: 500),
        const ValidationFailure(message: 'bad input'),
        const StorageFailure(message: 'upload failed'),
        const NotFoundFailure(message: 'not found'),
        const InsufficientCreditsFailure(message: 'no credits'),
        const UnexpectedFailure(message: 'unknown'),
      ];

      for (final f in failures) {
        expect(f.message, isNotEmpty);
        expect(f.toString(), contains(f.message));
      }
    });

    test('ServerFailure carries statusCode', () {
      const f = ServerFailure(message: 'error', statusCode: 503);
      expect(f.statusCode, equals(503));
    });

    test('Failure sealed class enables exhaustive matching', () {
      const Failure failure = NetworkFailure(message: 'test');

      final label = switch (failure) {
        NetworkFailure() => 'network',
        AuthFailure() => 'auth',
        ServerFailure() => 'server',
        ValidationFailure() => 'validation',
        StorageFailure() => 'storage',
        NotFoundFailure() => 'notFound',
        InsufficientCreditsFailure() => 'credits',
        UnexpectedFailure() => 'unexpected',
      };

      expect(label, equals('network'));
    });
  });
}
