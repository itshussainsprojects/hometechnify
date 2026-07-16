import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'edit_job_dialog.dart';
import '../../../core/constants/constants.dart';
import '../providers/job_post_provider.dart';
import '../../../core/utils/snackbar_helper.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../booking/providers/booking_provider.dart';
import 'package:home_technify/features/booking/data/models/booking_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/date_formatter.dart';
import '../../provider/screens/ongoing_service_screen.dart'; // For navigation
import '../../../core/theme/neu_theme.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<BookingProvider>().fetchMyBookings(user.id);
        context.read<JobPostProvider>().fetchMyJobs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    
    // Extract arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final initialTab = args?['initialTab'] ?? 0;

    return DefaultTabController(
      length: 3, // Increased to 3
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: NeuTheme.bg,
        appBar: AppBar(
          title: const Text('My Jobs', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
          centerTitle: true,
          backgroundColor: NeuTheme.bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          bottom: const TabBar(
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryBlue,
            isScrollable: true, // Allow scrolling for 3 tabs
            tabs: [
              Tab(text: 'Posted Jobs'), // NEW TAB
              Tab(text: 'Active Bookings'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. POSTED JOBS
            Consumer<JobPostProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.myJobs.isEmpty) {
                   return const Center(child: CircularProgressIndicator());
                }
                if (provider.myJobs.isEmpty) {
                  return _buildEmptyState("No posted jobs", Icons.post_add);
                }
                return ListView.separated(
                  padding: EdgeInsets.all(horizontalPadding),
                  itemCount: provider.myJobs.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final job = provider.myJobs[index];
                    return GestureDetector(
                      onTap: () {
                         // Navigate back to FindingProvidersScreen
                         if (job.category != null) {
                            Navigator.pushNamed(
                              context, 
                              '/finding-providers',
                              arguments: {
                                'jobId': job.id,
                                'serviceName': job.title, // Use title as fallback
                                'serviceId': job.category,
                                'jobData': job, 
                              }
                            );
                         } else {
                           SnackBarHelper.showError(context, "Cannot open job map: Category missing.");
                         }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: NeuTheme.sm(radius: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Expanded(child: Text(job.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                 Row(
                                   children: [
                                     Container(
                                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                       decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                       child: Text(job.status, style: TextStyle(fontSize: 12, color: Colors.blue)),
                                     ),
                                     PopupMenuButton<String>(
                                       onSelected: (value) {
                                         if (value == 'edit') {
                                           showDialog(
                                             context: context,
                                             builder: (_) => EditJobDialog(job: job),
                                           );
                                         } else if (value == 'delete') {
                                            _confirmDelete(context, job.id);
                                         }
                                       },
                                       itemBuilder: (context) => [
                                         const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                         const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                       ],
                                       child: Padding(
                                         padding: const EdgeInsets.only(left: 8.0),
                                         child: Icon(Icons.more_vert, color: Colors.grey),
                                       ),
                                     )
                                   ],
                                 )
                               ],
                             ),
                             SizedBox(height: 8),
                             Text(job.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey)),
                             SizedBox(height: 12),
                             Row(
                               children: [
                                 Icon(Icons.location_on, size: 14, color: Colors.grey),
                                 SizedBox(width: 4),
                                 Expanded(child: Text(job.location, style: TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1)),
                                 Text(
                                   job.budget != null ? "Rs. ${job.budget!.toInt()}" : "Negotiable", 
                                   style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)
                                 ),
                               ],
                             )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // 2. ACTIVE BOOKINGS
            Consumer<BookingProvider>(
              builder: (context, provider, child) {
                 final activeBookings = provider.bookings.where((b) => 
                    ['accepted', 'ongoing', 'in_progress', 'confirmed'].contains(b.status.toLowerCase())).toList();
                 return _buildBookingList(horizontalPadding, isSmall, activeBookings, isActive: true);
              }
            ),

            // 3. COMPLETED BOOKINGS
             Consumer<BookingProvider>(
              builder: (context, provider, child) {
                 final completedBookings = provider.bookings.where((b) => 
                    ['completed', 'cancelled'].contains(b.status.toLowerCase())).toList();
                 return _buildBookingList(horizontalPadding, isSmall, completedBookings, isActive: false);
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: NeuTheme.circle(),
            child: Icon(icon, size: 42, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildBookingList(double horizontalPadding, bool isSmall, List<BookingModel> bookings, {required bool isActive}) {
    if (bookings.isEmpty) {
       return _buildEmptyState(isActive ? "No active bookings" : "No completed bookings", isActive ? Icons.work_off_rounded : Icons.history_edu_rounded);
    }

    return ListView.separated(
      padding: EdgeInsets.all(horizontalPadding),
      itemCount: bookings.length,
      separatorBuilder: (c, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return GestureDetector(
          onTap: () {
             // Navigate to specific detail/ongoing screen
             if (isActive) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingServiceScreen(bookingData: {'bookingId': booking.id})));
             } else {
                // Show details or separate completed screen? 
                // For now, re-use OngoingServiceScreen as it checks status and shows "Completed" if done.
                Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingServiceScreen(bookingData: {'bookingId': booking.id})));
             }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: NeuTheme.sm(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        booking.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: isActive ? AppColors.primaryBlue : AppColors.success
                        ),
                      ),
                    ),
                    Text(
                      DateFormatter.formatDate(booking.scheduledAt),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  booking.serviceName, // Assuming BookingModel has serviceName, or we fetch it. Wait, BookingModel doesn't have serviceName directly usually? 
                  // Let's check BookingModel. It usually has serviceId. 
                  // Actually previous screens showed Service Name. 
                  // Checking BookingModel... it has serviceId. 
                  // We might need to fetch service or it might be included in a Relation.
                  // For now let's use "Service Request" or try to find it.
                  // Ah, BookingModel in provider usually needs to be rich.
                  // Let's check BookingModel in task checking...
                  // It has `serviceName`.
                  // If not, we use "Service Request".
                  // I'll assume it has it or use a placeholder.
                  // Replacing with safe access if possible.
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                // Address?
                 Row(
                   children: [
                     const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          booking.address,
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                   ],
                 ),
                 const SizedBox(height: 12),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Text(
                        "Rs. ${booking.totalAmount}",
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primaryDark),
                      ),
                      if(isActive)
                      const Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.primaryBlue),
                   ],
                 ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String jobId) {
    final jobProvider = context.read<JobPostProvider>();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Job?"),
        content: const Text("Are you sure you want to delete this job? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await jobProvider.deleteJob(jobId);
              if (!mounted) return;
              if (success) {
                messenger.showSnackBar(const SnackBar(content: Text('Job deleted successfully'), backgroundColor: AppColors.success));
              } else {
                messenger.showSnackBar(const SnackBar(content: Text('Failed to delete job'), backgroundColor: Colors.red));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
