
import 'package:dio/dio.dart';
import '../errors/failures.dart';

class ApiClient {
  static const String _baseUrl = 'http://10.0.2.2:3000/api'; 
  final Dio _dio;

  ApiClient() : _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    validateStatus: (status) => status! < 500, // Handle 4xx manually
  ));

  // Headers with Auth Token
  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }
  
  // GET Request
  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParameters);
      return _handleResponse(response);
    } catch (e) {
      throw NetworkFailure('Connection failed: $e');
    }
  }

  // POST Request
  Future<Response> post(String endpoint, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.post(endpoint, data: data, queryParameters: queryParameters);
      return _handleResponse(response);
    } catch (e) {
      throw NetworkFailure('Connection failed: $e');
    }
  }

  // PUT Request
  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return _handleResponse(response);
    } catch (e) {
      throw NetworkFailure('Connection failed: $e');
    }
  }

  // DELETE Request
  Future<Response> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return _handleResponse(response);
    } catch (e) {
      throw NetworkFailure('Connection failed: $e');
    }
  }

  Response _handleResponse(Response response) {
    if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
      return response;
    } else {
      // Backend error format: { success: false, message: "Error msg" }
      try {
        final body = response.data;
        throw ServerFailure(body['message'] ?? 'Unknown Server Error');
      } catch (e) {
        if (e is Failure) rethrow; // If it's the ServerFailure we just threw
        throw ServerFailure('Server Error: ${response.statusCode}');
      }
    }
  }
}
