// My Bookings Screen - Professional Design with Brand Colors

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'providers/booking_provider.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/widgets/async_value_wrapper.dart';
import 'data/models/booking_model.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/service_visuals.dart';
import 'widgets/booking_shimmer.dart';
import '../../../core/theme/neu_theme.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final user = context.read<AuthProvider>().user;
       if (user != null) {
         context.read<BookingProvider>().fetchMyBookings(user.id);
       }
    });
  }
  
  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isTiny = size.height < 550;
    final horizontalPadding = isTiny ? 14.0 : isSmall ? 16.0 : 20.0;

    return Scaffold(
      body: Container(
        color: NeuTheme.bg,
        child: Column(
          children: [
            _buildAppBar(isSmall, isTiny),
            if (_selectedDate != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Filtering by: ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}',
                      style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearFilter,
                      child: const Icon(Icons.close, size: 18, color: AppColors.primaryBlue),
                    ),
                  ],
                ),
              ),
            _buildTabBar(isSmall),
            Expanded(
              child: Consumer<BookingProvider>(
                builder: (context, provider, _) {
                  return AsyncValueWrapper(
                    isLoading: provider.isLoading,
                    loadingChild: const BookingShimmer(),
                    error: provider.errorMessage,
                    onRetry: () {
                      final user = context.read<AuthProvider>().user;
                      if (user != null) {
                        provider.fetchMyBookings(user.id);
                      }
                    },
                    child: Builder(
                      builder: (context) {
                        // Backend returns UPPERCASE statuses — compare case-insensitively
                        bool isDone(String s) { final l = s.toLowerCase(); return l == 'completed' || l == 'cancelled'; }
                        var active = provider.bookings.where((b) => !isDone(b.status)).toList();
                        var completed = provider.bookings.where((b) => isDone(b.status)).toList();
                        
                        if (_selectedDate != null) {
                          active = active.where((b) => isSameDay(b.bookingDate, _selectedDate!)).toList();
                          completed = completed.where((b) => isSameDay(b.bookingDate, _selectedDate!)).toList();
                        }

                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildBookingsList(active, horizontalPadding, isActive: true, isSmall: isSmall, isTiny: isTiny),
                            _buildBookingsList(completed, horizontalPadding, isActive: false, isSmall: isSmall, isTiny: isTiny),
                          ],
                        );
                      }
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildAppBar(bool isSmall, bool isTiny) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isTiny ? 10 : 20),
        left: isTiny ? 14 : isSmall ? 16 : 20,
        right: isTiny ? 14 : isSmall ? 16 : 20,
        bottom: isTiny ? 10 : 20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Bookings',
                style: TextStyle(
                  fontSize: isTiny ? 22 : isSmall ? 24 : 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track & manage your services',
                style: TextStyle(
                  fontSize: isTiny ? 12 : isSmall ? 13 : 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _selectedDate != null ? AppColors.primaryBlue : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _selectedDate != null ? AppColors.primaryBlue.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.calendar_month_rounded, color: _selectedDate != null ? Colors.white : AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isSmall) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmall ? 16 : 20, vertical: 10),
      height: 45,
      decoration: NeuTheme.inset(radius: 25),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Active'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<BookingModel> bookings, double horizontalPadding, {required bool isActive, required bool isSmall, required bool isTiny}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isTiny ? 80 : isSmall ? 90 : 100,
              height: isTiny ? 80 : isSmall ? 90 : 100,
              decoration: NeuTheme.circle(),
              child: Icon(
                Icons.calendar_today_outlined,
                size: isTiny ? 36 : isSmall ? 42 : 50,
                color: AppColors.primaryBlue,
              ),
            ),
            SizedBox(height: isSmall ? 16 : 20),
            Text(
              'No ${isActive ? 'Active' : 'Past'} Bookings',
              style: TextStyle(
                fontSize: isTiny ? 16 : isSmall ? 17 : 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${isActive ? 'active' : 'completed'} bookings will appear here',
              style: TextStyle(
                fontSize: isTiny ? 12 : isSmall ? 13 : 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(horizontalPadding),
      itemCount: bookings.length,
      separatorBuilder: (context, index) => SizedBox(height: isTiny ? 10 : isSmall ? 12 : 14),
      itemBuilder: (context, index) => _buildBookingCard(bookings[index], index, isActive, isSmall, isTiny),
    );
  }

  Widget _buildBookingCard(BookingModel booking, int index, bool isActive, bool isSmall, bool isTiny) {
    // Real trade icon + curated color resolved from the service name
    final visual = ServiceVisuals.of(booking.serviceName);
    final serviceColor = visual.color;
    Color statusColor;
    IconData statusIcon;
    final icon = visual.icon;
    
    switch (booking.status) {
      case 'active':
      case 'in_progress':
        statusColor = AppColors.primaryBlue;
        statusIcon = Icons.sync_rounded;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.watch_later_outlined;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_outlined;
        break;
      case 'completed':
      default:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
    }
    
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, 
        '/booking-detail',
        arguments: {'isActive': isActive, 'bookingId': booking.id},
      ),
      child: Container(
        padding: EdgeInsets.all(isTiny ? 12 : isSmall ? 14 : 16),
        decoration: NeuTheme.sm(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Service icon with gradient
                Container(
                  width: isTiny ? 48 : isSmall ? 52 : 58,
                  height: isTiny ? 48 : isSmall ? 52 : 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        serviceColor.withValues(alpha: 0.2),
                        serviceColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: serviceColor.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: isTiny ? 24 : isSmall ? 26 : 30,
                    color: serviceColor,
                  ),
                ),
                SizedBox(width: isTiny ? 10 : isSmall ? 12 : 14),
                // Service details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceName,
                        style: TextStyle(
                          fontSize: isTiny ? 14 : isSmall ? 15 : 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: isTiny ? 2 : 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: isTiny ? 12 : 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            booking.providerName,
                            style: TextStyle(
                              fontSize: isTiny ? 11 : isSmall ? 12 : 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTiny ? 8 : isSmall ? 10 : 12,
                    vertical: isTiny ? 4 : isSmall ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: isTiny ? 10 : 12, color: statusColor),
                      SizedBox(width: isTiny ? 3 : 4),
                      Text(
                        booking.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: isTiny ? 9 : isSmall ? 10 : 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isTiny ? 10 : isSmall ? 12 : 14),
            // Date and time row
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTiny ? 10 : isSmall ? 12 : 14,
                vertical: isTiny ? 8 : isSmall ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.access_time_rounded,
                      size: isTiny ? 14 : isSmall ? 16 : 18,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  SizedBox(width: isTiny ? 8 : 10),
                  Expanded(
                    child: Text(
                      DateFormat('MMM dd, hh:mm a').format(booking.bookingDate),
                      style: TextStyle(
                        fontSize: isTiny ? 11 : isSmall ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isTiny ? 4 : 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: isTiny ? 10 : 12,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0);
  }
}
