import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart'; // Ensure correct TileProvider import

class MapService {
  static Future<void> initialize() async {
    try {
      // FMTC initialization logic disabled due to v9 API mismatch issues
      // await FMTC.instance('mapStore').manage.createAsync();
      debugPrint('Map caching disabled temporarily');
    } catch (e) {
      debugPrint('Map caching init error: $e');
    }
  }

  static TileProvider getTileProvider({String storeName = 'mapStore'}) {
    // Return standard network provider for now
    return NetworkTileProvider();
    // return FMTC.instance(storeName).getTileProvider();
  }
}
