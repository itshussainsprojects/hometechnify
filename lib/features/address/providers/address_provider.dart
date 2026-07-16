import 'package:flutter/material.dart';
import '../data/models/address_model.dart';
import '../data/repositories/remote_address_repository.dart';
import '../../../../core/utils/snackbar_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddressProvider extends ChangeNotifier {
  final RemoteAddressRepository _repository;
  
  List<AddressModel> _addresses = [];
  bool _isLoading = false;
  String? _error;

  List<AddressModel> get addresses => _addresses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Selected Address State
  AddressModel? _selectedAddress;
  AddressModel? get selectedAddress => _selectedAddress;

  Future<void> selectAddress(AddressModel? address) async {
    _selectedAddress = address;
    notifyListeners();
    // Persist
    final prefs = await SharedPreferences.getInstance();
    if (address != null) {
      await prefs.setString('selected_address_id', address.id);
    } else {
      await prefs.remove('selected_address_id');
    }
  }

  AddressProvider(this._repository);

  Future<void> fetchAddresses(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _addresses = await _repository.getAddresses(userId);
      
      // Restore Selection
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('selected_address_id');
      if (savedId != null && _addresses.isNotEmpty) {
        try {
           _selectedAddress = _addresses.firstWhere((a) => a.id == savedId);
        } catch (_) {
           // Saved address likely deleted
           await prefs.remove('selected_address_id');
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAddress(String userId, String address, {String label = 'Home', double? lat, double? lng, required BuildContext context}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newAddr = await _repository.createAddress(userId, address, label: label, lat: lat, lng: lng);
      _addresses.insert(0, newAddr);
      selectAddress(newAddr);
      if (context.mounted) SnackBarHelper.showSuccess(context, 'Address added successfully');
    } catch (e) {
      if (context.mounted) SnackBarHelper.showError(context, 'Failed to add address');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAddress(String id, BuildContext context) async {
    // Optimistic update
    final index = _addresses.indexWhere((a) => a.id == id);
    if (index == -1) return;
    
    final deleted = _addresses.removeAt(index);
    // If selected was deleted, clear selection
    if (_selectedAddress?.id == id) {
       selectAddress(null);
    }
    notifyListeners();

    try {
      await _repository.deleteAddress(id);
      if (context.mounted) SnackBarHelper.showSuccess(context, 'Address deleted');
    } catch (e) {
      _addresses.insert(index, deleted);
      if (context.mounted) SnackBarHelper.showError(context, 'Failed to delete address');
      notifyListeners();
    }
  }
}
