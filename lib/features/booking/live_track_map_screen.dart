// Live tracking map — the real one.
//
// This replaces a "map" that was a gradient background with a grid pattern and
// animated dots painted on it: no tiles, no route, no real position. The live
// GPS pipeline (provider streams a fix every 10 m over the socket) was wired to
// that fake screen, so it went nowhere.
//
// What this actually does:
//   • OpenStreetMap tiles (flutter_map) — a real map.
//   • OSRM road route, real driving distance and real ETA. No straight lines
//     unless routing itself fails, and then it says so.
//   • The moving point updates live: the customer gets the provider's fixes over
//     the socket; the provider uses their own GPS stream (and keeps broadcasting).
//   • The route is recomputed as the provider moves, but only after they have
//     actually moved a meaningful distance — OSRM's free server must not be
//     hammered every 10 m.
//
// One screen serves both sides, because it is the same journey seen from two
// ends: the provider is always the one travelling, the customer is always the
// destination.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/constants.dart';
import '../../core/services/osrm_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/theme/neu_theme.dart';

enum TrackView {
  /// The customer is watching the provider come to them.
  customerWatchingProvider,

  /// The provider is navigating to the customer.
  providerGoingToCustomer,
}

class LiveTrackMapScreen extends StatefulWidget {
  const LiveTrackMapScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    required this.view,
    required this.customerLat,
    required this.customerLng,
    this.providerLat,
    this.providerLng,
    this.providerName = 'Provider',
    this.customerName = 'Customer',
  });

  final String bookingId;
  final String providerId;
  final TrackView view;

  /// The destination — the job site.
  final double customerLat;
  final double customerLng;

  /// Where the provider was last known to be. May be null until the first fix.
  final double? providerLat;
  final double? providerLng;

  final String providerName;
  final String customerName;

  @override
  State<LiveTrackMapScreen> createState() => _LiveTrackMapScreenState();
}

class _LiveTrackMapScreenState extends State<LiveTrackMapScreen> {
  final _map = MapController();
  final _socket = SocketService();

  LatLng? _provider; // the moving point
  late LatLng _customer; // the destination

  RouteResult? _route;
  bool _routing = true;
  bool _routeFailed = false;

  /// Where the route was last calculated from. The route is only recomputed once
  /// the provider has moved further than this from it.
  LatLng? _routedFrom;
  static const _recomputeAfterMeters = 120.0;

  StreamSubscription<Position>? _gps;
  Function(Map<String, dynamic>)? _prevProviderLocation;
  Timer? _staleTimer;
  DateTime? _lastFix;
  bool _mapReady = false;

  bool get _isProviderView => widget.view == TrackView.providerGoingToCustomer;

  @override
  void initState() {
    super.initState();
    _customer = LatLng(widget.customerLat, widget.customerLng);
    if (widget.providerLat != null &&
        widget.providerLng != null &&
        widget.providerLat != 0 &&
        widget.providerLng != 0) {
      _provider = LatLng(widget.providerLat!, widget.providerLng!);
      _lastFix = DateTime.now();
    }

    if (_isProviderView) {
      _followOwnGps();
    } else {
      _listenForProviderFixes();
    }

    if (_provider != null) _recomputeRoute(force: true);

    // Drives the "last seen" line so a frozen marker never looks live.
    _staleTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _gps?.cancel();
    _staleTimer?.cancel();
    if (!_isProviderView) {
      _socket.onProviderLocation = _prevProviderLocation;
      _socket.leaveBookingRoom(widget.bookingId);
    }
    super.dispose();
  }

  // ── Customer side: the provider's fixes arrive over the socket ────────────
  void _listenForProviderFixes() {
    _socket.joinBookingRoom(widget.bookingId);

    _prevProviderLocation = _socket.onProviderLocation;
    final prev = _prevProviderLocation;
    _socket.onProviderLocation = (data) {
      prev?.call(data);
      if (!mounted) return;
      if (data['bookingId'] != widget.bookingId) return;

      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null || lat == 0 || lng == 0) return;

      setState(() {
        _provider = LatLng(lat, lng);
        _lastFix = DateTime.now();
      });
      _recomputeRoute();
    };
  }

  // ── Provider side: follow this device's own GPS ───────────────────────────
  Future<void> _followOwnGps() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _routing = false;
          _routeFailed = true;
        });
      }
      return;
    }

    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _provider = LatLng(pos.latitude, pos.longitude);
        _lastFix = DateTime.now();
      });
      // Keep the customer's screen alive too.
      _socket.updateProviderLocation(
        bookingId: widget.bookingId,
        providerId: widget.providerId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      _recomputeRoute();
    });
  }

  // ── Routing ──────────────────────────────────────────────────────────────
  Future<void> _recomputeRoute({bool force = false}) async {
    final from = _provider;
    if (from == null) return;

    if (!force && _routedFrom != null) {
      final movedMeters = const Distance().as(LengthUnit.Meter, _routedFrom!, from);
      if (movedMeters < _recomputeAfterMeters) return; // don't hammer OSRM
    }

    setState(() => _routing = true);
    final r = await OsrmService.getRoute(from, _customer);
    if (!mounted) return;

    setState(() {
      _route = r;
      _routedFrom = from;
      _routing = false;
      _routeFailed = r == null;
    });

    if (r != null) _fitBounds(r.points);
  }

  void _fitBounds(List<LatLng> points) {
    if (!_mapReady || points.isEmpty) return;
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([...points, _customer, if (_provider != null) _provider!]),
          padding: const EdgeInsets.fromLTRB(60, 90, 60, 260),
        ),
      );
    } catch (_) {/* map not laid out yet */}
  }

  Future<void> _openInMapsApp() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${_customer.latitude},${_customer.longitude}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String get _lastSeenLabel {
    if (_lastFix == null) return 'Waiting for the first location…';
    final secs = DateTime.now().difference(_lastFix!).inSeconds;
    if (secs < 30) return 'Live';
    if (secs < 120) return 'Updated ${secs}s ago';
    return 'Updated ${(secs / 60).round()} min ago';
  }

  bool get _isLive => _lastFix != null && DateTime.now().difference(_lastFix!).inSeconds < 60;

  @override
  Widget build(BuildContext context) {
    final title = _isProviderView
        ? 'Route to ${widget.customerName}'
        : 'Track ${widget.providerName}';

    return Scaffold(
      backgroundColor: NeuTheme.bg,
      appBar: AppBar(
        backgroundColor: NeuTheme.bg,
        surfaceTintColor: NeuTheme.bg,
        elevation: 0,
        title: Text(title,
            style: const TextStyle(
                color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Recentre',
            icon: const Icon(Icons.my_location_rounded, color: AppColors.primaryBlue),
            onPressed: () {
              if (_route != null) {
                _fitBounds(_route!.points);
              } else if (_provider != null) {
                _map.move(_provider!, 15);
              } else {
                _map.move(_customer, 15);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildInfoCard()),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _provider ?? _customer,
        initialZoom: 14,
        onMapReady: () {
          _mapReady = true;
          if (_route != null) _fitBounds(_route!.points);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.hometechnify.app',
        ),
        if (_route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _route!.points,
                strokeWidth: 5,
                color: AppColors.primaryBlue,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // Destination — the customer's door.
            Marker(
              point: _customer,
              width: 54,
              height: 62,
              alignment: Alignment.topCenter,
              child: _pin(
                icon: Icons.home_rounded,
                color: AppColors.error,
                label: _isProviderView ? widget.customerName : 'You',
              ),
            ),
            // The provider — the one who is moving.
            if (_provider != null)
              Marker(
                point: _provider!,
                width: 54,
                height: 62,
                alignment: Alignment.topCenter,
                child: _pin(
                  icon: Icons.person_pin_circle_rounded,
                  color: _isLive ? AppColors.primaryBlue : AppColors.textSecondary,
                  label: _isProviderView ? 'You' : widget.providerName,
                  pulsing: _isLive,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// A map pin: coloured circle with an icon, a little tail, and a name chip.
  /// Goes grey when the fix is stale, so a frozen marker never reads as live.
  Widget _pin({
    required IconData icon,
    required Color color,
    required String label,
    bool pulsing = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: pulsing ? 0.5 : 0.25),
                blurRadius: pulsing ? 12 : 6,
                spreadRadius: pulsing ? 2 : 0,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final route = _route;
    final waiting = _provider == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: NeuTheme.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Live / stale badge.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isLive ? AppColors.success : AppColors.grey300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _lastSeenLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _isLive ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Waiting for the provider to share their location.\nIt appears here the moment they set off.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              )
            else if (_routing && route == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (route != null)
              Row(
                children: [
                  Expanded(
                    child: _stat(
                      icon: Icons.route_rounded,
                      label: 'Distance by road',
                      value: route.distanceLabel,
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.grey200),
                  Expanded(
                    child: _stat(
                      icon: Icons.schedule_rounded,
                      label: 'Arriving in',
                      value: route.etaLabel,
                    ),
                  ),
                ],
              )
            else if (_routeFailed && _provider != null)
              // Be honest: this is not the road distance.
              Column(
                children: [
                  _stat(
                    icon: Icons.straighten_rounded,
                    label: 'Straight-line distance (route unavailable)',
                    value: '${OsrmService.straightLineKm(_provider!, _customer).toStringAsFixed(1)} km',
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => _recomputeRoute(force: true),
                    child: const Text('Retry route'),
                  ),
                ],
              ),

            if (_isProviderView) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openInMapsApp,
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Navigate with Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
