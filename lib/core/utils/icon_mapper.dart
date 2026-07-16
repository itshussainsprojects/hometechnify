import 'package:flutter/material.dart';

class IconMapper {
  static IconData getIcon(String iconName) {
    switch (iconName) {
      case 'plumbing': 
      case 'Plumbing': return Icons.plumbing_rounded;
      
      case 'electrical_services': 
      case 'Electrical': return Icons.electrical_services_rounded;
      
      case 'cleaning_services': 
      case 'Cleaning': return Icons.cleaning_services_rounded;
      
      case 'ac_unit': 
      case 'AC Repair': return Icons.ac_unit_rounded;
      
      case 'carpenter': return Icons.carpenter_rounded;
      case 'format_paint': return Icons.format_paint_rounded;
      case 'roofing': return Icons.roofing_rounded;
      case 'local_laundry_service': return Icons.local_laundry_service_rounded;
      case 'pest_control': return Icons.pest_control_rounded;
      case 'water_drop': return Icons.water_drop_rounded;
      case 'security': return Icons.security_rounded;
      case 'construction': return Icons.construction_rounded;
      case 'local_florist': return Icons.local_florist_rounded;
      case 'local_shipping': return Icons.local_shipping_rounded;
      case 'tv': return Icons.tv_rounded;
      default: return Icons.category_rounded;
    }
  }
}
