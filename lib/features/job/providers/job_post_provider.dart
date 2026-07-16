import 'package:flutter/foundation.dart';
import '../data/models/job_post_model.dart';
import '../data/repositories/remote_job_repository.dart';
import '../../../core/errors/failures.dart';

class JobPostProvider extends ChangeNotifier {
  final RemoteJobRepository _repository;
  
  List<JobPostModel> _myJobs = [];
  List<JobPostModel> _nearbyJobs = [];
  bool _isLoading = false;
  String? _errorMessage;

  JobPostProvider(this._repository);

  List<JobPostModel> get myJobs => _myJobs;
  List<JobPostModel> get nearbyJobs => _nearbyJobs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> createJob(String title, String description, String location, double? budget, List<String> mediaPaths, {String? category, String? serviceId, double? lat, double? lng}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = {
        'title': title,
        'description': description,
        'location': location,
        'budget': budget,
        if (category != null) 'category': category,
        // Lets the backend resolve the correct category from the service so
        // providers of that service match the customer's list.
        if (serviceId != null) 'serviceId': serviceId,
        // Job-site coordinates so bookings/provider map get the real spot.
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
      
      final newJob = await _repository.createJob(data, mediaPaths);
      _myJobs.insert(0, newJob); // Add to top locally
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      debugPrint("Create Job Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyJobs() async {
    _isLoading = true;
    notifyListeners();
    try {
      _myJobs = await _repository.getMyJobs();
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNearbyJobs({String? category}) async {
    // Only show full loading if we have no data
    if (_nearbyJobs.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      _nearbyJobs = await _repository.getNearbyJobs(category: category);
    } catch (e) {
      _errorMessage = "Failed to load jobs";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

   Future<bool> deleteJob(String id) async {
     try {
       await _repository.deleteJob(id);
       _myJobs.removeWhere((j) => j.id == id);
       notifyListeners();
       return true;
     } catch (e) {
       _errorMessage = "Failed to delete job";
       notifyListeners();
       return false;
     }
  }

  Future<bool> updateJob(String id, String title, String description, String? status, List<String> newMediaPaths, {List<String>? mediaToDelete}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = {
        'title': title,
        'description': description,
        if (status != null) 'status': status,
      };
      
      final updatedJob = await _repository.updateJob(id, data, newMediaPaths, mediaToDelete: mediaToDelete);
      
      // Update local list
      final index = _myJobs.indexWhere((j) => j.id == id);
      if (index != -1) {
        _myJobs[index] = updatedJob;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      debugPrint("Update Job Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> acceptJob(String jobId, String price) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.acceptJob(jobId, price);
      // Remove from nearby list or update status
      _nearbyJobs.removeWhere((job) => job.id == jobId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      debugPrint("Accept Job Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
