
import '../../data/models/service_model.dart';
import '../../../../core/utils/result.dart'; // Added Result import

abstract class ServiceRepository {
  Future<Result<List<ServiceModel>>> getAllServices();
  Future<Result<List<ServiceModel>>> getPopularServices();
}
