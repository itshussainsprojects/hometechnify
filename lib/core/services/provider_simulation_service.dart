import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../features/provider/data/models/provider_model.dart';

class ProviderSimulationService {
  final _random = Random();
  Timer? _timer;
  final _controller = StreamController<List<ProviderModel>>.broadcast();

  Stream<List<ProviderModel>> get providerStream => _controller.stream;

  List<ProviderModel> _providers = [];
  // Keep track of internal state (heading, position) separately to decouple model from simulation logic
  List<_SimulatedInternal> _internalState = [];

  // Initialize with some random providers around a location
  void startSimulation(LatLng center, {int count = 5, required String serviceName}) {
    _internalState = List.generate(count, (index) {
      return _SimulatedInternal(
        id: 'sim_$index',
        pos: _randomLocation(center),
        heading: _random.nextDouble() * 360,
      );
    });

    _providers = _internalState.map((sim) => _generateProviderModel(sim, serviceName)).toList();
    _controller.add(_providers);

    // Update positions every 2 seconds
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updatePositions(serviceName);
    });
  }

  void stopSimulation() {
    _timer?.cancel();
  }
  
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  void _updatePositions(String serviceName) {
    // Update internal state
    _internalState = _internalState.map((sim) {
      // Move slightly in the direction of heading
      const speed = 0.00015; // Approx 15 meters per update
      final double lat = sim.pos.latitude + cos(_toRadians(sim.heading)) * speed;
      final double lng = sim.pos.longitude + sin(_toRadians(sim.heading)) * speed;
      
      // Randomly change heading slightly
      final newHeading = (sim.heading + (_random.nextDouble() - 0.5) * 40) % 360;

      return sim.copyWith(
        pos: LatLng(lat, lng),
        heading: newHeading,
      );
    }).toList();

    // Map back to Provider Models
    _providers = _internalState.map((sim) => _generateProviderModel(sim, serviceName)).toList();
    _controller.add(_providers);
  }

  ProviderModel _generateProviderModel(_SimulatedInternal sim, String serviceName) {
    // Deterministic random based on ID so name/rating doesn't change every frame
    final r = Random(sim.id.hashCode); 
    
    return ProviderModel(
      id: sim.id,
      name: _getRandomName(r),
      category: serviceName,
      rating: 3.5 + r.nextDouble() * 1.5, // 3.5 to 5.0
      reviewCount: 10 + r.nextInt(100),
      hourlyRate: 500 + (r.nextInt(10) * 100).toDouble(), // 500 - 1500
      experience: 1 + r.nextInt(10),
      latitude: sim.pos.latitude,
      longitude: sim.pos.longitude,
      address: "Live Location",
    );
  }

  String _getRandomName(Random r) {
    const names = [
      "Ahmed Khan", "Ali Raza", "Bilal Ahmed", "Usman Gondal", 
      "Fahad Mustafa", "Hamza Ali", "Kamran Akmal", "Zain Malik", 
      "Saeed Anwar", "Imran Nazir", "Rashid Latif", "Shoaib Akhtar"
    ];
    return names[r.nextInt(names.length)];
  }

  LatLng _randomLocation(LatLng center) {
    // Generate random offset within ~1km
    final latOffset = (_random.nextDouble() - 0.5) * 0.015;
    final lngOffset = (_random.nextDouble() - 0.5) * 0.015;
    return LatLng(center.latitude + latOffset, center.longitude + lngOffset);
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}

class _SimulatedInternal {
  final String id;
  final LatLng pos;
  final double heading;

  _SimulatedInternal({required this.id, required this.pos, required this.heading});

  _SimulatedInternal copyWith({String? id, LatLng? pos, double? heading}) {
    return _SimulatedInternal(
      id: id ?? this.id, 
      pos: pos ?? this.pos, 
      heading: heading ?? this.heading
    );
  }
}
