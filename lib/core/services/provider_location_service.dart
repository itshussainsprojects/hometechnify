import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ProviderLocationService {
  static final ProviderLocationService _instance = ProviderLocationService._internal();
  factory ProviderLocationService() => _instance;
  ProviderLocationService._internal();

  final SocketService _socketService = SocketService();
  final ApiService _api = ApiService();
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isBroadcasting = false;

  /// The socket only pushes a fix to whoever is watching right now. It is not
  /// storage: if the customer opens the map later, or either app restarts, the
  /// position is gone. So the last fix is also persisted — throttled, because
  /// this fires every 10 metres and the DB does not need that resolution.
  DateTime? _lastPersisted;
  static const _persistEvery = Duration(seconds: 30);

  bool get isBroadcasting => _isBroadcasting;

  /// Start broadcasting location for a specific booking
  Future<void> startBroadcasting({
    required String bookingId,
    required String providerId,
  }) async {
    if (_isBroadcasting) {
      debugPrint('⚠️ Already broadcasting location');
      return;
    }

    // Check location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    _isBroadcasting = true;

    // Start listening to location updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Live push to whoever has the tracking map open right now.
      _socketService.updateProviderLocation(
        bookingId: bookingId,
        providerId: providerId,
        lat: position.latitude,
        lng: position.longitude,
      );

      _persistLastKnown(position);
      debugPrint('📡 Broadcasting location: ${position.latitude}, ${position.longitude}');
    });

    debugPrint('✅ Started broadcasting location for booking: $bookingId');
  }

  /// Saves the fix so it survives a restart and is there as the starting marker
  /// when the customer opens the map. Throttled — the socket already covers the
  /// live case, this only needs to be roughly current.
  void _persistLastKnown(Position position) {
    final now = DateTime.now();
    if (_lastPersisted != null && now.difference(_lastPersisted!) < _persistEvery) {
      return;
    }
    _lastPersisted = now;

    unawaited(() async {
      try {
        await _api.dio.put('/providers/location', data: {
          'lat': position.latitude,
          'lng': position.longitude,
        });
      } catch (e) {
        // Non-fatal: the socket feed is what the map is actually watching.
        debugPrint('Could not persist provider location: $e');
      }
    }());
  }

  /// Stop broadcasting location
  void stopBroadcasting() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }
    _isBroadcasting = false;
    debugPrint('🛑 Stopped broadcasting location');
  }

  /// Get current location once
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    return await Geolocator.getCurrentPosition();
  }
}
