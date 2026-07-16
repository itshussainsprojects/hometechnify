import 'package:dio/dio.dart';
import 'api_service.dart';

/// Payments go through the SAME client as everything else.
///
/// This used to build its own Dio against EnvConfig.apiUrl — but dotenv was
/// never loaded, so that fell back to `http://localhost:3000`, which on a phone
/// is the phone itself. It also never attached the Firebase token (setAuthToken
/// was never called), so /payments/initiate would have 401'd even if the host
/// had been right. Reusing ApiService fixes both: correct base URL, and the auth
/// interceptor that every other call already relies on.
class PaymentService {
  final Dio _dio = ApiService().dio;

  /// Initiate Payment
  Future<Map<String, dynamic>> initiatePayment({
    required String bookingId,
    required String paymentMethod, // JAZZCASH, EASYPAISA, CASH
    String? customerPhone,
    String? customerEmail,
  }) async {
    try {
      final response = await _dio.post(
        '/payments/initiate',
        data: {
          'bookingId': bookingId,
          'paymentMethod': paymentMethod,
          'customerPhone': customerPhone,
          'customerEmail': customerEmail,
        },
      );

      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Get Payment Status
  Future<Map<String, dynamic>> getPaymentStatus(String bookingId) async {
    try {
      final response = await _dio.get('/payments/status/$bookingId');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Get Transaction History
  Future<List<dynamic>> getTransactionHistory() async {
    try {
      final response = await _dio.get('/payments/transactions');
      return response.data['data'] as List;
    } catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final data = error.response!.data;
        return data['message'] ?? 'Payment failed';
      }
      return 'Network error';
    }
    return error.toString();
  }
}
