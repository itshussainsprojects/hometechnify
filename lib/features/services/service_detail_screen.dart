// Service Detail Screen - View service info and book (REAL providers)

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../provider/data/models/provider_model.dart';
import '../provider/data/repositories/remote_provider_repository.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String serviceName;
  final String serviceId;
  final IconData serviceIcon;
  final Color serviceColor;

  const ServiceDetailScreen({
    super.key,
    required this.serviceName,
    required this.serviceId,
    required this.serviceIcon,
    required this.serviceColor,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  int _selectedProviderIndex = -1;

  final RemoteProviderRepository _providerRepository = RemoteProviderRepository();
  List<ProviderModel> _providers = [];
  bool _isLoadingProviders = true;

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    // Attach the customer's location (if permitted) so the backend can
    // rank providers nearest-first with a distance_km on each.
    double? lat, lng;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        ).timeout(const Duration(seconds: 6));
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    // Only AVAILABLE providers of THIS service. No fallback to a wider list:
    // showing an offline plumber (or an electrician) for a plumbing request is
    // worse than showing an honest empty state.
    final result = await _providerRepository.getProviders(
      categoryId: widget.serviceId,
      availableOnly: true,
      lat: lat,
      lng: lng,
    );
    if (!mounted) return;
    setState(() {
      _providers = result.isSuccess ? (result.data ?? []) : [];
      _isLoadingProviders = false;
    });
  }

  String _fmtDistance(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildServiceInfo(horizontalPadding)),
          SliverToBoxAdapter(child: _buildPostJobSection(horizontalPadding)),
          SliverToBoxAdapter(child: _buildProvidersList(horizontalPadding)),
          SliverToBoxAdapter(child: const SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _buildBookButton(horizontalPadding),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: widget.serviceColor,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.serviceColor, widget.serviceColor.withValues(alpha: 0.8)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Icon(widget.serviceIcon, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(widget.serviceName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceInfo(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About ${widget.serviceName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              'Professional ${widget.serviceName.toLowerCase()} services available 24/7. Our verified experts ensure quality work with guaranteed satisfaction.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(Icons.access_time_rounded, '24/7 Available'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.verified_rounded, 'Verified Experts'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.serviceColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: widget.serviceColor),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.serviceColor)),
        ],
      ),
    );
  }

  Widget _buildPostJobSection(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.serviceColor.withValues(alpha: 0.1),
              widget.serviceColor.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.serviceColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.serviceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_task_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Need Custom Work?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        'Post your job with video, image or voice',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/post-job', arguments: {
                'serviceName': widget.serviceName,
                'serviceId': widget.serviceId,
                'serviceIcon': widget.serviceIcon,
                'serviceColor': widget.serviceColor,
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [widget.serviceColor, widget.serviceColor.withValues(alpha: 0.8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: widget.serviceColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.post_add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Post Your Job', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildProvidersList(double horizontalPadding) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: const Text('Or Select a Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 16),
        if (_isLoadingProviders)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_providers.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Column(children: [
                Icon(Icons.person_search_rounded, size: 40, color: AppColors.grey300),
                const SizedBox(height: 10),
                Text('No providers available for this service yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: _providers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildProviderCard(index),
          ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildProviderCard(int index) {
    final provider = _providers[index];
    final isSelected = _selectedProviderIndex == index;
    final isAvailable = provider.isAvailable;

    return GestureDetector(
      onTap: isAvailable ? () => setState(() => _selectedProviderIndex = index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? widget.serviceColor : AppColors.grey200, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: widget.serviceColor.withValues(alpha: 0.2), blurRadius: 12)] : null,
        ),
        child: Opacity(
          opacity: isAvailable ? 1 : 0.5,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [widget.serviceColor, widget.serviceColor.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: provider.profileImage != null && provider.profileImage!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(provider.profileImage!, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    provider.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                )),
                      )
                    : Center(
                        child: Text(
                          provider.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(provider.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                        if (provider.isVerified) ...[
                          const SizedBox(width: 5),
                          // Verified tick (CNIC-verified providers)
                          const Icon(Icons.verified_rounded, size: 15, color: AppColors.primaryBlue),
                        ],
                        if (provider.rating >= 4.8) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                            child: const Text('Top Rated', style: TextStyle(fontSize: 9.5, color: Color(0xFFB7791F), fontWeight: FontWeight.w800)),
                          ),
                        ],
                        if (!isAvailable) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(10)),
                            child: const Text('Busy', style: TextStyle(fontSize: 10, color: AppColors.grey600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(provider.rating > 0 ? provider.rating.toStringAsFixed(1) : 'New',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        const Icon(Icons.work_outline_rounded, size: 14, color: AppColors.grey400),
                        const SizedBox(width: 4),
                        Text('${provider.reviewCount} reviews', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (provider.distanceKm != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.grey400),
                          const SizedBox(width: 4),
                          Text(_fmtDistance(provider.distanceKm!), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Rs. ${provider.hourlyRate.toInt()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.serviceColor)),
                  const Text('Service Rate', style: TextStyle(fontSize: 11, color: AppColors.grey500)),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(width: 12),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: widget.serviceColor, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookButton(double horizontalPadding) {
    final isEnabled = _selectedProviderIndex >= 0;

    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: isEnabled ? () {
            final selected = _providers[_selectedProviderIndex];
            Navigator.pushNamed(
              context,
              '/booking',
              arguments: {
                'providerName': selected.name,
                'serviceName': widget.serviceName,
                'price': selected.hourlyRate.toInt().toString(),
                'negotiated': false,
                'providerId': selected.id,
                'serviceId': widget.serviceId,
              },
            );
          } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: isEnabled ? LinearGradient(colors: [widget.serviceColor, widget.serviceColor.withValues(alpha: 0.8)]) : null,
              color: isEnabled ? null : AppColors.grey200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isEnabled ? [BoxShadow(color: widget.serviceColor.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))] : null,
            ),
            child: Center(
              child: Text(
                isEnabled ? 'Book Now' : 'Select a Provider',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isEnabled ? Colors.white : AppColors.grey400),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
