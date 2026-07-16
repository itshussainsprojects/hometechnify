// Job Requests Screen - Provider job management

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../data/dismissed_cards.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/date_formatter.dart';
import '../../job/providers/job_post_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../../job/data/models/job_post_model.dart';
import 'package:home_technify/features/booking/data/models/booking_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/provider_controller.dart';

class JobRequestsScreen extends StatefulWidget {
  const JobRequestsScreen({super.key});

  @override
  State<JobRequestsScreen> createState() => _JobRequestsScreenState();
}

class _JobRequestsScreenState extends State<JobRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Shared with the dashboard, so a card removed there stays removed here.
  final _dismissed = DismissedCards.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dismissed.addListener(_onDismissedChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _onDismissedChanged() {
    if (mounted) setState(() {});
  }

  void _dismiss(String id, String label) {
    _dismissed.dismiss(id);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label removed'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.white,
            onPressed: () => _dismissed.restore(id),
          ),
        ),
      );
  }

  /// Red swipe-to-remove background behind a dismissible card.
  Widget _removeBackground() => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(height: 2),
            Text('Remove',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      // Fetch provider details to get category
      final providerController = context.read<ProviderController>();
      await providerController.fetchProviderDetails(user.id);
      
      final category = providerController.selectedProvider?.category;
      if (mounted) {
        if (category != null) {
          context.read<JobPostProvider>().fetchNearbyJobs(category: category);
        } else {
          debugPrint("⚠️ Skipping nearby jobs fetch: Category is null");
        }
        context.read<BookingProvider>().fetchMyBookings(user.id);
      }
    }
  }

  @override
  void dispose() {
    _dismissed.removeListener(_onDismissedChanged);
    _tabController.dispose();
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
        automaticallyImplyLeading: true, // Allow back navigation
        title: Text('New Opportunities (Deal Not Done)', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: isSmall ? 18 : 20)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Nearby Jobs'),
            Tab(text: 'Negotiations'),
          ],
        ),
      ),
      body: Consumer2<BookingProvider, JobPostProvider>(
        builder: (context, bookingProvider, jobProvider, child) {
          final nearbyJobs = jobProvider.nearbyJobs
              .where((j) => !_dismissed.contains(j.id))
              .toList();
          final negotiatingBookings = bookingProvider.bookings
              .where((b) =>
                  ['pending', 'negotiating'].contains(b.status.toLowerCase()) &&
                  !_dismissed.contains(b.id))
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildNearbyJobsList(horizontalPadding, isSmall, nearbyJobs),
              _buildActiveList(horizontalPadding, isSmall, negotiatingBookings, isNegotiating: true), // Reusing with flag
            ],
          );
        },
      ),

      bottomNavigationBar: _buildBottomNav(context, 1),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    final items = [
      {'icon': Icons.home_rounded, 'iconOutlined': Icons.home_outlined, 'label': 'Home'},
      {'icon': Icons.calendar_today_rounded, 'iconOutlined': Icons.calendar_today_outlined, 'label': 'Bookings'},
      {'icon': Icons.person_rounded, 'iconOutlined': Icons.person_outline_rounded, 'label': 'Profile'},
    ];

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.grey200)),
      ),
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final isSelected = currentIndex == index;
            return GestureDetector(
              onTap: () {
                if (index == 0) {
                  Navigator.pushReplacementNamed(context, '/provider/dashboard');
                } else if (index == 1) {
                  // Already on Bookings
                } else if (index == 2) {
                  Navigator.pushReplacementNamed(context, '/provider/profile');
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? items[index]['icon'] as IconData : items[index]['iconOutlined'] as IconData,
                    size: 24,
                    color: isSelected ? AppColors.primaryBlue : AppColors.grey400,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[index]['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.primaryBlue : AppColors.grey400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNearbyJobsList(double horizontalPadding, bool isSmall, List<JobPostModel> jobs) {
    if (jobs.isEmpty) return _buildEmptyState('No nearby jobs');
    return ListView.separated(
      padding: EdgeInsets.all(horizontalPadding),
      itemCount: jobs.length,
      separatorBuilder: (context, index) => SizedBox(height: isSmall ? 10 : 12),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Dismissible(
          key: ValueKey('job_${job.id}'),
          direction: DismissDirection.endToStart,
          background: _removeBackground(),
          onDismissed: (_) => _dismiss(job.id, 'Job'),
          child: _buildJobPostCard(job, index, isSmall),
        );
      },
    );
  }

  Widget _buildJobPostCard(JobPostModel job, int index, bool isSmall) {
    final hasMedia = job.mediaUrls.isNotEmpty;
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  image: job.customerProfileImage != null 
                    ? DecorationImage(image: NetworkImage(job.customerProfileImage!), fit: BoxFit.cover)
                    : null,
                ),
                child: job.customerProfileImage == null ? Center(
                  child: Text(
                    (job.customerName ?? job.customerId).split(' ').map((e) => e[0]).take(2).join(),
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                  ),
                ) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.customerName ?? 'Customer',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      job.title,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasMedia)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attachment, size: 14, color: AppColors.primaryAccent),
                    const SizedBox(width: 5),
                    Text(
                      'Attachment',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryAccent),
                    ),
                  ],
                ),
              ),
              if (hasMedia) const SizedBox(width: 12),
              Icon(Icons.access_time_rounded, size: 14, color: AppColors.grey400),
              const SizedBox(width: 4),
              Text(DateFormatter.timeAgo(job.createdAt), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/provider/job-detail', arguments: job),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('View Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Navigate to set price
                     Navigator.pushNamed(context, '/provider/set-price', arguments: job);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('Set Price', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 400.ms);
  }

  // Reused for Negotiations list
  Widget _buildActiveList(double horizontalPadding, bool isSmall, List<BookingModel> bookings, {bool isNegotiating = false}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isNegotiating ? Icons.hourglass_disabled : Icons.work_off_rounded, size: 60, color: AppColors.grey300),
            const SizedBox(height: 16),
            Text(isNegotiating ? "No pending negotiations" : "No active bookings", style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    
    return ListView.separated(
      padding: EdgeInsets.all(horizontalPadding),
      itemCount: bookings.length,
      separatorBuilder: (context, index) => SizedBox(height: isSmall ? 10 : 12),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return Dismissible(
          key: ValueKey('booking_${booking.id}'),
          direction: DismissDirection.endToStart,
          background: _removeBackground(),
          onDismissed: (_) => _dismiss(booking.id, 'Request'),
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
          ),
          child: GestureDetector(
             onTap: () {
                Navigator.pushNamed(context, '/provider/ongoing', arguments: {
                   'bookingId': booking.id,
                });
             },
             behavior: HitTestBehavior.opaque,
             child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.work_rounded, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.customerName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                         Text(
                          booking.serviceId, // Show Service Name if possible
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      booking.status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        booking.address, 
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
              
              // Only show action buttons if NOT negotiating (i.e. if this was used for Active list, but now it is mostly for Negotiations)
              // Actually, user might want to quick access chat if active?
              // But we are using this for Negotiations tab now.
              // If isNegotiating is true, hide buttons (Chat disabled, Complete not ready).
              if (!isNegotiating)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/chat', arguments: {
                        'id': booking.customerId,
                        'name': booking.customerName,
                        'service': booking.serviceId,
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(10)),
                        child: const Center(child: Text('Chat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/provider/complete', arguments: {'booking': booking, 'duration': 0}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                        child: const Center(
                          child: Text(
                            'Complete',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ) else 
                // Show "View Offer" / "Negotiate" button
                 GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/provider/ongoing', arguments: {'bookingId': booking.id}),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                        child: const Center(
                          child: Text(
                            'View Details & Negotiate',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        ).animate().fadeIn(duration: 400.ms),
        );
      },
    );
  }



  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off_outlined, size: 80, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
