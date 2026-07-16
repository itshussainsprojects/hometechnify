// Provider Notifications Screen - Company, Customer & Quote notifications
// Premium design with functional backend integration

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../providers/provider_controller.dart';

class ProviderNotificationsScreen extends StatefulWidget {
  const ProviderNotificationsScreen({super.key});

  @override
  State<ProviderNotificationsScreen> createState() => _ProviderNotificationsScreenState();
}

class _ProviderNotificationsScreenState extends State<ProviderNotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    await context.read<ProviderController>().fetchNotifications();
  }

  Future<void> _markAsRead(String id) async {
    await context.read<ProviderController>().markNotificationAsRead(id);
  }

  Future<void> _deleteNotification(String id) async {
    await context.read<ProviderController>().deleteNotification(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearAllNotifications() {
     _markAsRead('all');
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read')));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _clearAllNotifications,
            child: Text(
              'Mark All Read',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: isSmall ? 12 : 13,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isSmall ? 12 : 13,
          ),
          tabs: const [
            Tab(text: 'Company'),
            Tab(text: 'Customers'),
            Tab(text: 'Quotes'),
          ],
        ),
      ),
      body: Consumer<ProviderController>(
        builder: (context, controller, child) {
           if (controller.isLoading && controller.notifications.isEmpty) {
             return const Center(child: CircularProgressIndicator());
           }
           
           final notifications = controller.notifications;
           
           // Filter Notifications
           final companyNotifs = notifications.where((n) => n['type'] == 'broadcast' || n['type'] == 'SYSTEM' || n['type'] == null).toList();
           final customerNotifs = notifications.where((n) => n['type'] == 'booking_request' || n['type'] == 'booking_update' || n['type'] == 'message' || n['type'] == 'review').toList();
           final quoteNotifs = notifications.where((n) => n['type'] == 'job_post' || n['type'] == 'quote_accepted' || n['type'] == 'quote_rejected').toList();

           return TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationList(companyNotifs, horizontalPadding, isSmall, 'No company updates'),
              _buildNotificationList(customerNotifs, horizontalPadding, isSmall, 'No customer notifications'),
              _buildNotificationList(quoteNotifs, horizontalPadding, isSmall, 'No quote updates'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(List<dynamic> notifs, double padding, bool isSmall, String emptyMsg) {
    if (notifs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.grey400),
            const SizedBox(height: 16),
            Text(emptyMsg, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        padding: EdgeInsets.all(padding),
        itemCount: notifs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notif = notifs[index];
          final id = notif['id']?.toString() ?? '$index';
          return Dismissible(
            key: ValueKey('notif_$id'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _deleteNotification(id),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            child: _buildNotificationItem(notif, isSmall),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(dynamic notif, bool isSmall) {
    final type = notif['type'] ?? 'SYSTEM';
    final title = notif['title'] ?? 'Notification';
    final body = notif['body'] ?? '';
    final isRead = notif['is_read'] ?? false;
    final createdAt = notif['created_at'] != null ? DateTime.parse(notif['created_at']) : DateTime.now();
    final timeStr = _formatTime(createdAt);

    IconData icon;
    Color color;

    switch (type) {
      case 'booking_request':
        icon = Icons.calendar_today_rounded;
        color = AppColors.primaryBlue;
        break;
      case 'booking_update':
        icon = Icons.edit_calendar_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'message':
        icon = Icons.chat_bubble_outline_rounded;
        color = const Color(0xFF8B5CF6);
        break;
      case 'review':
        icon = Icons.star_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'job_post':
        icon = Icons.work_outline_rounded;
        color = const Color(0xFF10B981);
        break;
      case 'quote_accepted':
        icon = Icons.check_circle_outline_rounded;
        color = const Color(0xFF10B981);
        break;
      case 'quote_rejected':
        icon = Icons.cancel_outlined;
        color = AppColors.error;
        break;
      case 'broadcast':
      default:
        icon = Icons.campaign_rounded;
        color = AppColors.primaryBlue;
        break;
    }

    return GestureDetector(
      onTap: () {
        if (!isRead) _markAsRead(notif['id']);
        _handleRedirection(type, notif['data']);
      },
      child: Container(
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.primaryBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? AppColors.grey200 : AppColors.primaryBlue.withValues(alpha: 0.2),
          ),
          boxShadow: [
             if(!isRead)
             BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
             )
          ]
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isSmall ? 44 : 48,
              height: isSmall ? 44 : 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: isSmall ? 22 : 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: isSmall ? 14 : 15,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: isSmall ? 10 : 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                   ),
                   const SizedBox(height: 4),
                   Text(
                     body,
                     style: TextStyle(
                       fontSize: isSmall ? 12 : 13,
                       color: AppColors.textSecondary,
                     ),
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 20),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  void _handleRedirection(String type, dynamic data) {
    // Handle Navigation based on type
    if (type == 'booking_request') {
       if (data != null && data['bookingId'] != null) {
          // Ideally fetch booking details or pass ID
          // For now navigate to jobs/requests or specific booking info
          Navigator.pushNamed(context, '/provider/jobs');
       } else {
          Navigator.pushNamed(context, '/provider/jobs');
       }
    } else if (type == 'job_post') {
       // Navigate to jobs
       Navigator.pushNamed(context, '/provider/jobs');
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(time);
  }
}
