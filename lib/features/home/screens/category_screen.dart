import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../providers/service_provider.dart';
import '../data/models/service_model.dart';
import '../widgets/job_posting_modal.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryName;

  const CategoryScreen({super.key, required this.categoryName});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServiceModel> _filtered(List<ServiceModel> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context, isSmall),
          Expanded(
            child: Consumer<ServiceProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final services = _filtered(provider.services);
                if (services.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: AppColors.grey300),
                        const SizedBox(height: 16),
                        Text('No services found', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: EdgeInsets.all(isSmall ? 14 : 18),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: isSmall ? 1.0 : 0.95,
                  ),
                  itemCount: services.length,
                  itemBuilder: (context, index) => _buildServiceTile(context, services[index], isSmall, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmall) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.categoryName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search services...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.8), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildServiceTile(BuildContext context, ServiceModel service, bool isSmall, int index) {
    final color = Color(service.colorValue);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => JobPostingModal(
          serviceName: service.name,
          serviceId: service.id,
          serviceIcon: Icons.category_rounded,
          serviceColor: color,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey200),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isSmall ? 52 : 60,
                height: isSmall ? 52 : 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: (service.iconUrl?.isNotEmpty ?? false)
                    // A real uploaded icon is a normal image, not a monochrome
                    // glyph — tinting it with the curated accent color (as
                    // this used to) painted it a single flat color, which is
                    // exactly the "broken tint" ServiceVisuals was built to
                    // avoid. Show it as-is; only the Material fallback icon
                    // uses the curated color.
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          service.iconUrl!,
                          width: isSmall ? 52 : 60,
                          height: isSmall ? 52 : 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Icon(Icons.category_rounded, color: color, size: 28),
                        ),
                      )
                    : Icon(Icons.category_rounded, color: color, size: isSmall ? 26 : 30),
              ),
              const SizedBox(height: 12),
              Text(
                service.name,
                style: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Book Now',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: index * 40)).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}
