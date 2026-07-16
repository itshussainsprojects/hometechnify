// Route Map — a real map (flutter_map / OpenStreetMap) showing the road route
// between two points with the real distance + ETA (via OSRM). Used when a
// provider opens a booking to reach the customer, or a customer tracks a job.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';
import '../../core/services/osrm_service.dart';
import '../../core/widgets/neumorphic.dart';

class RouteMapScreen extends StatefulWidget {
  final double fromLat, fromLng; // usually the provider (you)
  final double toLat, toLng;     // usually the customer (destination)
  final String title;
  final String destinationLabel;

  const RouteMapScreen({
    super.key,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    this.title = 'Route to Customer',
    this.destinationLabel = 'Customer',
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _map = MapController();
  RouteResult? _route;
  bool _loading = true;
  bool _failed = false;

  LatLng get _from => LatLng(widget.fromLat, widget.fromLng);
  LatLng get _to => LatLng(widget.toLat, widget.toLng);

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() { _loading = true; _failed = false; });
    final r = await OsrmService.getRoute(_from, _to);
    if (!mounted) return;
    setState(() {
      _route = r;
      _loading = false;
      _failed = r == null;
    });
    _fitBounds();
  }

  void _fitBounds() {
    final pts = _route?.points.isNotEmpty == true ? _route!.points : [_from, _to];
    try {
      _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(70)));
    } catch (_) {}
  }

  // Open the device's map app for turn-by-turn navigation.
  Future<void> _openInMaps() async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${widget.toLat},${widget.toLng}&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fallback numbers when routing fails (straight-line estimate).
    final straightKm = OsrmService.straightLineKm(_from, _to);
    final distLabel = _route?.distanceLabel ?? '${straightKm.toStringAsFixed(1)} km';
    final etaLabel = _route?.etaLabel ?? '~${(straightKm / 0.4).round()} min';

    return Scaffold(
      backgroundColor: Neu.base,
      appBar: AppBar(
        backgroundColor: Neu.base,
        surfaceTintColor: Neu.base,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: NeuBox(
            circle: true,
            padding: const EdgeInsets.all(8),
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.primaryBlue),
          ),
        ),
        title: Text(widget.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
            child: NeuBox(
              circle: true,
              padding: const EdgeInsets.all(8),
              onTap: _loadRoute,
              child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: LatLng((widget.fromLat + widget.toLat) / 2, (widget.fromLng + widget.toLng) / 2),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hometechnify.app',
              ),
              // Road route
              if (_route != null && _route!.points.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _route!.points, strokeWidth: 5, color: AppColors.primaryBlue),
                ])
              else
                PolylineLayer(polylines: [
                  Polyline(points: [_from, _to], strokeWidth: 3, color: AppColors.primaryBlue.withValues(alpha: 0.5)),
                ]),
              MarkerLayer(markers: [
                // Provider (you)
                Marker(point: _from, width: 46, height: 46, child: _pin(Icons.handyman_rounded, AppColors.primaryBlue)),
                // Customer (destination)
                Marker(point: _to, width: 46, height: 46, child: _pin(Icons.home_rounded, AppColors.error)),
              ]),
            ],
          ),

          if (_loading)
            Positioned(top: 12, left: 0, right: 0, child: Center(
              child: NeuBox(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                radius: 30,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
                  SizedBox(width: 10),
                  Text('Finding best route…', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ]),
              ),
            )),

          // Bottom info card — real distance + ETA + navigate (neumorphic)
          Positioned(
            left: 16, right: 16, bottom: 20,
            child: NeuBox(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: _stat(Icons.route_rounded, 'Distance', distLabel, AppColors.primaryBlue)),
                  const SizedBox(width: 12),
                  Expanded(child: _stat(Icons.schedule_rounded, 'Travel time', etaLabel, AppColors.success)),
                ]),
                if (_failed)
                  const Padding(padding: EdgeInsets.only(top: 8), child: Text('(estimated — live route unavailable)', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary))),
                const SizedBox(height: 16),
                NeuBox(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  onTap: _openInMaps,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.navigation_rounded, size: 18, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text('Navigate to ${widget.destinationLabel}', style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 14)),
                  ]),
                ),
              ]),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _pin(IconData icon, Color color) => Container(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10)]),
        child: Icon(icon, color: Colors.white, size: 22),
      );

  // Inset neumorphic "well" for each stat.
  Widget _stat(IconData icon, String label, String value, Color color) => NeuBox(
        pressedStyle: true,
        radius: 14,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}
