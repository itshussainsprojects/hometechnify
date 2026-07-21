import 'dart:async';
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

  // Cold-start requests ride a phone radio that is still waking up — the
  // Dio-level retries handle a dropped packet, but when ALL of them lose,
  // the home screen used to just sit on the error card until the user
  // tapped Retry themselves. These background re-loads clear that without
  // the user doing anything. Capped so a genuinely dead network doesn't
  // spin forever.
  Timer? _autoRetryTimer;
  int _autoRetries = 0;
  static const _maxAutoRetries = 3;

  Future<void> loadServices() async {
    _autoRetryTimer?.cancel();
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
      _autoRetries = 0;
    } else {
      _status = ServiceStatus.error;
      _errorMessage = allResult.error?.message ?? popularResult.error?.message;
      if (_autoRetries < _maxAutoRetries) {
        _autoRetries++;
        _autoRetryTimer = Timer(
          Duration(seconds: 3 * _autoRetries),
          loadServices,
        );
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    super.dispose();
  }
}
