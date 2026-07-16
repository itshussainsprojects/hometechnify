
import '../errors/failures.dart';

// Simple Result class for functional error handling
class Result<T> {
  final T? data;
  final Failure? error;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  Result.success(this.data) : error = null;
  Result.failure(this.error) : data = null;
}
