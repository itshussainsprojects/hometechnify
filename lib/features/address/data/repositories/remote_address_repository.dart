import '../../../../core/services/api_service.dart';
import '../models/address_model.dart';

class RemoteAddressRepository {
  final ApiService _apiService = ApiService();

  Future<List<AddressModel>> getAddresses(String userId) async {
    try {
      final response = await _apiService.dio.get(
        '/addresses',
        queryParameters: {'userId': userId},
      );

      final List data = response.data;
      return data.map((json) => AddressModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch addresses: $e');
    }
  }

  Future<AddressModel> createAddress(String userId, String address, {String label = 'Home', double? lat, double? lng}) async {
    try {
      final response = await _apiService.dio.post('/addresses', data: {
        'userId': userId,
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
      });

      return AddressModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create address: $e');
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      await _apiService.dio.delete('/addresses/$id');
    } catch (e) {
      throw Exception('Failed to delete address: $e');
    }
  }
}
