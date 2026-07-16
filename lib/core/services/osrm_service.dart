// OSRM routing — free, no API key. Given two points it returns the driving
// road route (polyline), the real distance (km) and the travel time (ETA).
// Public demo server: router.project-osrm.org

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points; // the road polyline to draw on the map
  final double distanceKm;    // real driving distance
  final int durationMin;      // real travel time (ETA)

  RouteResult({required this.points, required this.distanceKm, required this.durationMin});

  String get distanceLabel =>
      distanceKm < 1 ? '${(distanceKm * 1000).round()} m' : '${distanceKm.toStringAsFixed(1)} km';
  String get etaLabel => durationMin < 1 ? '<1 min' : '$durationMin min';
}

class OsrmService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Fetches the driving route from [from] to [to]. Returns null on failure
  /// (caller can fall back to a straight line + Haversine distance).
  static Future<RouteResult?> getRoute(LatLng from, LatLng to) async {
    if (from.latitude == 0 || to.latitude == 0) return null;
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';
      final res = await _dio.get(url);
      final routes = res.data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first;
      final coords = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      final meters = (route['distance'] as num).toDouble();
      final seconds = (route['duration'] as num).toDouble();

      return RouteResult(
        points: coords,
        distanceKm: meters / 1000,
        durationMin: (seconds / 60).round(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Straight-line (Haversine) distance in km — a fallback when routing fails.
  static double straightLineKm(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Kilometer, a, b);
}
