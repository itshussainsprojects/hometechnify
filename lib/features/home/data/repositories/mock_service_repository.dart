import 'dart:async';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/service_repository.dart';
import '../models/service_model.dart';

class MockServiceRepository implements ServiceRepository {
  final List<ServiceModel> _mockServices = [
    ServiceModel(
      id: 's1',
      name: 'Plumbing',
      iconName: 'plumbing',
      colorValue: 0xFF2196F3,
      bookingsCount: 150,
    ),
    ServiceModel(
      id: 's2',
      name: 'Electrician',
      iconName: 'electrical_services',
      colorValue: 0xFFFFC107,
      bookingsCount: 200,
    ),
    ServiceModel(
      id: 's3',
      name: 'Cleaning',
      iconName: 'cleaning_services',
      colorValue: 0xFF4CAF50,
      bookingsCount: 300,
    ),
  ];

  @override
  Future<Result<List<ServiceModel>>> getAllServices() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return Result.success(_mockServices);
  }

  @override
  Future<Result<List<ServiceModel>>> getPopularServices() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _mockServices.sort((a, b) => b.bookingsCount.compareTo(a.bookingsCount));
    return Result.success(_mockServices.take(5).toList());
  }
}
