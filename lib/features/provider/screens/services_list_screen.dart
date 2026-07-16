// Provider Services List Screen

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  final _searchController = TextEditingController();
  
  final List<Map<String, dynamic>> _services = [
    {'name': 'Plumbing', 'icon': Icons.plumbing_rounded, 'status': 'Active', 'price': 500},
    {'name': 'Electrical', 'icon': Icons.electrical_services_rounded, 'status': 'Active', 'price': 600},
    {'name': 'AC Repair', 'icon': Icons.ac_unit_rounded, 'status': 'Active', 'price': 800},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services_rounded, 'status': 'Inactive', 'price': 400},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text('All Service', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(horizontalPadding),
            color: AppColors.white,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grey200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.grey400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          
          // Info Banner
          Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap Active/Inactive to toggle visibility for customers',
                    style: TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Services List
          Expanded(
            child: _services.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    itemCount: _services.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildServiceCard(_services[index], isSmall, index),
                  ),
          ),
          
          // Bottom Info
          Container(
            padding: EdgeInsets.all(horizontalPadding),
            child: Text(
              'Inactive services will not be visible to customers',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_repair_service_outlined, size: 80, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(
            'No service available',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, bool isSmall, int index) {
    final isActive = service['status'] == 'Active';
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? AppColors.success.withValues(alpha: 0.3) : AppColors.grey100),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive 
                  ? AppColors.primaryBlue.withValues(alpha: 0.1)
                  : AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              service['icon'], 
              color: isActive ? AppColors.primaryBlue : AppColors.grey400, 
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['name'],
                  style: TextStyle(
                    fontSize: isSmall ? 15 : 16, 
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${service['price']}',
                  style: TextStyle(fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Clickable Toggle Button
          GestureDetector(
            onTap: () {
              setState(() {
                _services[index]['status'] = isActive ? 'Inactive' : 'Active';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${service['name']}: ${_services[index]['status']}'),
                  backgroundColor: _services[index]['status'] == 'Active' ? AppColors.success : AppColors.grey500,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (isActive ? AppColors.success : AppColors.grey400).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.success.withValues(alpha: 0.5) : AppColors.grey300,
                ),
              ),
              child: Text(
                service['status'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.success : AppColors.grey500,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
