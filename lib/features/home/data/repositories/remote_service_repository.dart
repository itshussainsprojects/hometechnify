import 'package:flutter/material.dart';

import '../../domain/repositories/service_repository.dart';
import '../models/service_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';

class RemoteServiceRepository implements ServiceRepository {
  final ApiService _apiService = ApiService();

  @override
  Future<Result<List<ServiceModel>>> getAllServices() async {
    try {
      // Fetch Categories as "Services" for Home Screen
      final response = await _apiService.dio.get('/categories');
      final data = response.data['data'] as List;
      
      final services = data.map((json) {
        // Generate a stable color based on name hash if not provided
        final name = json['name'] as String? ?? 'Service';
        final int colorValue = json['color'] != null 
            ? int.parse(json['color'].replaceAll('#', '0xFF')) 
            : Colors.primaries[name.hashCode.abs() % Colors.primaries.length].toARGB32();

        // The admin upload path (SupabaseStorage) already saves the full
        // public URL as icon_url — prepending the backend's own base URL
        // here turned every uploaded icon into a broken, double-prefixed
        // link (https://api.example.com/https://xxx.supabase.co/...). Admin's
        // own screens already use icon_url as-is; this was the one place
        // that didn't, so a category with a real uploaded icon showed a
        // broken image on the customer home screen while looking fine in
        // the admin panel.
        final rawIcon = json['icon_url'] as String?;
        final iconUrl = (rawIcon == null || rawIcon.isEmpty)
            ? null
            : (rawIcon.startsWith('http')
                ? rawIcon
                : '${_apiService.baseUrl.replaceAll("/api", "")}/$rawIcon');

        return ServiceModel(
          id: json['id'] ?? '',
          name: name,
          iconUrl: iconUrl,
          iconName: name, // Use Name for smart fallback
          colorValue: colorValue,
        );
      }).toList();
      
      return Result.success(services);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<List<ServiceModel>>> getPopularServices() async {
    return getAllServices();
  }
}
