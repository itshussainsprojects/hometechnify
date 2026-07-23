// All Services/Categories Screen - Grid layout with category cards

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'providers/service_provider.dart';
import '../../core/utils/service_visuals.dart';
import '../../core/widgets/async_value_wrapper.dart';
import 'data/models/service_model.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import 'widgets/job_posting_modal.dart';

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  String _searchQuery = '';



  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    
    // Responsive grid columns
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final crossAxisCount = isDesktop ? 4 : isTablet ? 4 : 3;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context), 
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 22),
          ),
        ),
        title: const Text('Categories', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Consumer<ServiceProvider>(
        builder: (context, provider, _) {
          return AsyncValueWrapper(
            isLoading: provider.isLoading,
            error: provider.errorMessage,
            onRetry: provider.loadServices,
            child: Column(
              children: [
                _buildSearchBar(horizontalPadding, isSmall),
                Expanded(
                  child: _buildServicesGrid(
                    provider.services,
                    horizontalPadding,
                    crossAxisCount,
                    isSmall
                  )
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(double horizontalPadding, bool isSmall) {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Container(
        height: isSmall ? 48 : 54,
        decoration: BoxDecoration(
          color: AppColors.white, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: AppColors.grey200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          style: TextStyle(fontSize: isSmall ? 14 : 15),
          decoration: InputDecoration(
            hintText: 'Search categories...',
            hintStyle: TextStyle(color: AppColors.textHint, fontSize: isSmall ? 14 : 15),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryBlue, size: isSmall ? 22 : 24),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 12 : 14),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildServicesGrid(List<ServiceModel> services, double horizontalPadding, int crossAxisCount, bool isSmall) {
    final filtered = _searchQuery.isEmpty 
        ? services 
        : services.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: AppColors.grey300),
            const SizedBox(height: 16),
            const Text('No Categories Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Try searching with different keywords', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildCategoryCard(filtered[index], index, isSmall),
    );
  }

  Widget _buildCategoryCard(ServiceModel service, int index, bool isSmall) {
    // Real trade-specific icon + curated color, resolved from the name.
    final visual = ServiceVisuals.of(service.name);
    final color = visual.color;
    final bgColor = color.withValues(alpha: 0.1);
    final iconData = visual.icon;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => JobPostingModal(
            serviceName: service.name,
            serviceId: service.id,
            serviceIcon: iconData,
            serviceIconUrl: service.iconUrl,
            serviceColor: color,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey200.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container with colored background — shows the
            // admin-uploaded icon when the category has one, falling back to
            // the curated Material icon otherwise (or if it fails to load).
            Container(
              width: isSmall ? 56 : 64,
              height: isSmall ? 56 : 64,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: (service.iconUrl?.isNotEmpty ?? false)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        service.iconUrl!,
                        width: isSmall ? 56 : 64,
                        height: isSmall ? 56 : 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(iconData, size: isSmall ? 28 : 32, color: color),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        iconData,
                        size: isSmall ? 28 : 32,
                        color: color,
                      ),
                    ),
            ),
            SizedBox(height: isSmall ? 10 : 12),
            // Category name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                service.name,
                style: TextStyle(
                  fontSize: isSmall ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 40)).fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}
