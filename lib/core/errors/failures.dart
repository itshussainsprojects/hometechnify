import 'package:dio/dio.dart';

abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No Internet Connection']);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Repositories used to build ServerFailure(e.toString()) in their catch
/// blocks, which for a DioException means the full technical dump —
/// "DioException [connection timeout]: The request connection took longer
/// than 0:00:15.000000..." — ends up rendered straight in the UI. This maps
/// the exceptions that actually reach a catch block to something a customer
/// can act on.
String friendlyErrorMessage(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server is taking too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'Could not connect. Check your internet connection.';
      case DioExceptionType.badResponse:
        final serverMessage = e.response?.data is Map
            ? e.response?.data['message']
            : null;
        return serverMessage is String && serverMessage.isNotEmpty
            ? serverMessage
            : 'Something went wrong on the server. Please try again.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return 'Network error. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
