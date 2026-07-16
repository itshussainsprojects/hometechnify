// ServiceVisuals - one source of truth for how a service looks.
//
// The backend sends arbitrary icon URLs / color ints that render
// inconsistently (broken tints, random colors, generic placeholders).
// Instead, every service resolves - by NAME - to a hand-picked Material
// icon that actually depicts the trade, plus a curated brand-harmonious
// color. Unknown services degrade gracefully to a proper "home repair"
// look, never to an abstract "category" glyph.

import 'package:flutter/material.dart';

class ServiceVisual {
  final IconData icon;
  final Color color;
  const ServiceVisual(this.icon, this.color);
}

class ServiceVisuals {
  ServiceVisuals._();

  // Ordered: first keyword hit wins, so more specific entries sit higher.
  static final List<(List<String>, ServiceVisual)> _rules = [
    // Climate
    (['ac ', ' ac', 'air condition', 'hvac', 'chiller'],
        const ServiceVisual(Icons.ac_unit_rounded, Color(0xFF0EA5E9))),
    (['geyser', 'water heater', 'boiler'],
        const ServiceVisual(Icons.local_fire_department_rounded, Color(0xFFF97316))),
    (['solar'],
        const ServiceVisual(Icons.solar_power_rounded, Color(0xFFF59E0B))),

    // Water & plumbing
    (['plumb', 'pipe', 'leak', 'sanitary', 'tap ', 'drain'],
        const ServiceVisual(Icons.plumbing_rounded, Color(0xFF1495FF))),
    (['water tank', 'tank clean', 'water supply'],
        const ServiceVisual(Icons.water_drop_rounded, Color(0xFF06B6D4))),

    // Electrical
    (['electric', 'wiring', 'ups', 'generator', 'breaker'],
        const ServiceVisual(Icons.electrical_services_rounded, Color(0xFFF59E0B))),

    // Cleaning & home care
    (['deep clean', 'clean', 'maid', 'janitor'],
        const ServiceVisual(Icons.cleaning_services_rounded, Color(0xFF14B8A6))),
    (['laundry', 'dry clean', 'iron'],
        const ServiceVisual(Icons.local_laundry_service_rounded, Color(0xFF6366F1))),
    (['pest', 'termite', 'fumiga', 'insect'],
        const ServiceVisual(Icons.pest_control_rounded, Color(0xFFDC2626))),
    (['garden', 'lawn', 'plant', 'landscap'],
        const ServiceVisual(Icons.yard_rounded, Color(0xFF16A34A))),

    // Build & finish
    (['paint', 'polish', 'wall '],
        const ServiceVisual(Icons.format_paint_rounded, Color(0xFF8B5CF6))),
    (['carpent', 'wood', 'furniture', 'door'],
        const ServiceVisual(Icons.carpenter_rounded, Color(0xFFA16207))),
    (['mason', 'construction', 'renovat', 'tile', 'marble'],
        const ServiceVisual(Icons.construction_rounded, Color(0xFF78716C))),
    (['roof', 'ceiling', 'waterproof'],
        const ServiceVisual(Icons.roofing_rounded, Color(0xFF64748B))),
    (['glass', 'aluminum', 'aluminium', 'window'],
        const ServiceVisual(Icons.window_rounded, Color(0xFF0891B2))),
    (['weld', 'steel', 'iron work', 'grill'],
        const ServiceVisual(Icons.hardware_rounded, Color(0xFF52525B))),

    // Appliances & tech
    (['fridge', 'refrigerator', 'freezer', 'kitchen appliance'],
        const ServiceVisual(Icons.kitchen_rounded, Color(0xFF0EA5E9))),
    (['washing machine', 'appliance'],
        const ServiceVisual(Icons.local_laundry_service_rounded, Color(0xFF3B82F6))),
    (['tv', 'television', 'led '],
        const ServiceVisual(Icons.tv_rounded, Color(0xFF334155))),
    (['cctv', 'camera', 'security', 'alarm'],
        const ServiceVisual(Icons.videocam_rounded, Color(0xFF475569))),
    (['internet', 'network', 'wifi'],
        const ServiceVisual(Icons.wifi_rounded, Color(0xFF2563EB))),
    (['computer', 'laptop', 'it support', 'it service'],
        const ServiceVisual(Icons.computer_rounded, Color(0xFF4F46E5))),
    (['phone', 'mobile'],
        const ServiceVisual(Icons.smartphone_rounded, Color(0xFF7C3AED))),

    // Moving & vehicles
    (['moving', 'shifting', 'movers', 'transport', 'cargo'],
        const ServiceVisual(Icons.local_shipping_rounded, Color(0xFF059669))),
    (['car wash', 'car detail'],
        const ServiceVisual(Icons.local_car_wash_rounded, Color(0xFF0284C7))),
    (['mechanic', 'car ', 'bike'],
        const ServiceVisual(Icons.car_repair_rounded, Color(0xFFEA580C))),

    // Locks & misc trades
    (['lock', 'key'],
        const ServiceVisual(Icons.vpn_key_rounded, Color(0xFFB45309))),
    (['handyman', 'repair', 'fix', 'maintenance'],
        const ServiceVisual(Icons.handyman_rounded, Color(0xFF1495FF))),
  ];

  static const ServiceVisual _fallback =
      ServiceVisual(Icons.home_repair_service_rounded, Color(0xFF1495FF));

  /// Resolve the visual for a service by its display name.
  /// Matching is case-insensitive and keyword-based, so "Split AC Repair",
  /// "AC Installation" and "Air Conditioner Service" all map to the AC look.
  static ServiceVisual of(String serviceName) {
    // Pad so leading/trailing keyword forms like 'ac ' / ' ac' can hit
    // at the string boundaries too.
    final n = ' ${serviceName.toLowerCase().trim()} ';
    for (final (keys, visual) in _rules) {
      for (final k in keys) {
        if (n.contains(k)) return visual;
      }
    }
    return _fallback;
  }
}
