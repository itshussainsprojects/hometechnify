// Favorites Service - Manages favorite providers for the user
// Allows users to mark providers as favorites from chat

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesService extends ChangeNotifier {
  // Set of favorite provider names (in production, use IDs)
  final Set<String> _favoriteProviders = {};

  // List of provider details for favorites display
  final Map<String, Map<String, dynamic>> _providerDetails = {};
  
  String? _currentUserId;

  // Initialize and sync with Firestore
  Future<void> init(String userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    await _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    if (_currentUserId == null) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('favorites')
          .get();
          
      _favoriteProviders.clear();
      _providerDetails.clear();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final providerId = doc.id; // Using ID/Name as doc ID
        _favoriteProviders.add(providerId);
        _providerDetails[providerId] = data;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching favorites: $e");
    }
  }

  // Check if a provider is a favorite
  bool isFavorite(String providerName) {
    return _favoriteProviders.contains(providerName);
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String providerName, {Map<String, dynamic>? details}) async {
    if (_favoriteProviders.contains(providerName)) {
      _favoriteProviders.remove(providerName);
      _providerDetails.remove(providerName);
      _removeFromFirestore(providerName);
    } else {
      _favoriteProviders.add(providerName);
      if (details != null) {
        _providerDetails[providerName] = details;
      }
      _addToFirestore(providerName, details ?? {});
    }
    notifyListeners();
  }

  Future<void> _addToFirestore(String providerId, Map<String, dynamic> details) async {
    if (_currentUserId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('favorites')
          .doc(providerId)
          .set(details);
    } catch (e) {
      debugPrint("Error adding favorite: $e");
    }
  }

  Future<void> _removeFromFirestore(String providerId) async {
    if (_currentUserId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('favorites')
          .doc(providerId)
          .delete();
    } catch (e) {
      debugPrint("Error removing favorite: $e");
    }
  }

  // Add to favorites
  void addFavorite(String providerName, {Map<String, dynamic>? details}) {
    _favoriteProviders.add(providerName);
    if (details != null) {
      _providerDetails[providerName] = details;
    }
    notifyListeners();
  }

  // Remove from favorites
  void removeFavorite(String providerName) {
    _favoriteProviders.remove(providerName);
    _providerDetails.remove(providerName);
    notifyListeners();
  }

  // Get all favorite providers
  List<String> get favoriteProviders => _favoriteProviders.toList();

  // Get favorite providers count
  int get favoritesCount => _favoriteProviders.length;

  // Get provider details
  Map<String, dynamic>? getProviderDetails(String providerName) {
    return _providerDetails[providerName];
  }

  // Get all favorites with details
  List<Map<String, dynamic>> get favoritesWithDetails {
    return _favoriteProviders.map((name) {
      final details = _providerDetails[name] ?? {};
      return {
        'name': name,
        'initials': name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
        ...details,
      };
    }).toList();
  }
}

// Global instance for easy access
final favoritesService = FavoritesService();
