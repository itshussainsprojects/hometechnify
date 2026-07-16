import 'package:flutter/foundation.dart';
import '../domain/repositories/service_repository.dart';
import '../data/models/service_model.dart'; // Corrected path: data/models

enum ServiceStatus { idle, loading, success, error }

class ServiceProvider extends ChangeNotifier {
  final ServiceRepository _serviceRepository;

  ServiceProvider(this._serviceRepository);

  List<ServiceModel> _services = [];
  List<ServiceModel> get services => _services;

  List<ServiceModel> _popularServices = [];
  List<ServiceModel> get popularServices => _popularServices;

  ServiceStatus _status = ServiceStatus.idle;
  ServiceStatus get status => _status;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == ServiceStatus.loading;

  Future<void> loadServices() async {
    _status = ServiceStatus.loading;
    notifyListeners();

    // Fetch popular and all services in parallel
    final results = await Future.wait([
      _serviceRepository.getAllServices(),
      _serviceRepository.getPopularServices(),
    ]);

    final allResult = results[0];
    final popularResult = results[1];

    if (allResult.isSuccess && popularResult.isSuccess) {
      _services = allResult.data!;
      _popularServices = popularResult.data!;
      _status = ServiceStatus.success;
    } else {
      _status = ServiceStatus.error;
      _errorMessage = allResult.error?.message ?? popularResult.error?.message;
    }
    notifyListeners();
  }
}
