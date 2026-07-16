
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/services/socket_service.dart';
import '../data/repositories/remote_profile_repository.dart';
import '../../auth/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProfileStatus { idle, loading, success, error }



class ProfileProvider extends ChangeNotifier {
  final RemoteProfileRepository _profileRepository;
  final SocketService _socketService = SocketService();


  ProfileProvider(this._profileRepository) {
     _loadPreferences();
  }

  UserModel? _user;
  ProfileStatus _status = ProfileStatus.idle;
  String? _errorMessage;

  UserModel? get user => _user;
  ProfileStatus get status => _status;
  String? get errorMessage => _errorMessage;
  
  // Payment Method State
  String _selectedPaymentMethod = 'cash';
  String get selectedPaymentMethod => _selectedPaymentMethod;
  
  String _selectedWallet = 'jazzcash';
  String get selectedWallet => _selectedWallet;
  
  // App-Level Settings
  bool _appLocationEnabled = true;
  bool get appLocationEnabled => _appLocationEnabled;
  
  bool _appNotificationEnabled = true;
  bool get appNotificationEnabled => _appNotificationEnabled;

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedPaymentMethod = prefs.getString('payment_method') ?? 'cash';
    _selectedWallet = prefs.getString('wallet') ?? 'jazzcash';
    _appLocationEnabled = prefs.getBool('app_location') ?? true;
    _appNotificationEnabled = prefs.getBool('app_notifications') ?? true;
    notifyListeners();
  }

  Future<void> updatePaymentMethod(String method) async {
    _selectedPaymentMethod = method;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payment_method', method);
  }
  
  Future<void> updateWallet(String wallet) async {
    _selectedWallet = wallet;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet', wallet);
  }
  
  Future<void> setAppLocation(bool enabled) async {
    _appLocationEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_location', enabled);
  }
  
  Future<void> setAppNotification(bool enabled) async {
    _appNotificationEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_notifications', enabled);
    // This used to be device-local only — the backend's is_notifications_enabled
    // column (and every push send that checks it, and the admin panel's view
    // of the user) never learned the customer had opted out.
    await _profileRepository.toggleNotifications(enabled);
  }

  bool get isLoading => _status == ProfileStatus.loading;

  Future<void> fetchProfile(String userId) async {
    _status = ProfileStatus.loading;
    notifyListeners();

    final result = await _profileRepository.getProfile(userId);

    if (result.isSuccess) {
      _user = result.data;
      _status = ProfileStatus.success;
    } else {
      _status = ProfileStatus.error;
      _errorMessage = result.error?.message;
    }
    notifyListeners();
  }

  Future<String?> uploadImage(File image) async {
    _status = ProfileStatus.loading;
    notifyListeners();
    
    final url = await _profileRepository.uploadProfileImage(image);
    
    if (url == null) {
      _status = ProfileStatus.error;
      _errorMessage = "Failed to upload image";
      notifyListeners();
      return null;
    }
    
    return url;
  }

  Future<bool> updateProfile(UserModel updatedUser) async {
    _status = ProfileStatus.loading;
    notifyListeners();

    final result = await _profileRepository.updateProfile(updatedUser);

    if (result.isSuccess) {
      _user = result.data;
      if (_user != null) {
        _socketService.connect(_user!.id, userName: _user!.name);
      }
      _status = ProfileStatus.success;
      notifyListeners();
      return true;
    } else {
      _status = ProfileStatus.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }
}
