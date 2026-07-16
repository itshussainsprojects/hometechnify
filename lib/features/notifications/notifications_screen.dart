import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/firebase_auth_service.dart';
import 'package:home_technify/features/notifications/providers/notification_provider.dart';
import 'package:home_technify/features/auth/providers/auth_provider.dart';
import 'package:home_technify/features/notifications/data/models/notification_model.dart';
import '../../core/theme/neu_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final user = context.read<AuthProvider>().user;
    
    // Use Firebase UID for Firestore (not Postgres UUID)
    final firebaseUid = FirebaseAuthService.getUserId();
    
    // Safety check just in case
    if (user == null || firebaseUid == null) {
      return const Scaffold(body: Center(child: Text("Please login to view notifications")));
    }

    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final notifications = provider.notifications;
        final unreadCount = provider.unreadCount;

        return Scaffold(
          backgroundColor: NeuTheme.bg,
          appBar: AppBar(
            backgroundColor: NeuTheme.bg,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            ),
            title: const Text('Notifications', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            centerTitle: true,
            actions: [
              if (unreadCount > 0)
                GestureDetector(
                  onTap: () => provider.markAllAsRead(firebaseUid),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text('Mark all read', style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
          body: provider.isLoading && notifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: EdgeInsets.all(horizontalPadding),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildNotificationCard(context, notifications[index], index, firebaseUid),
                    ),
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel notification, int index, String userId) {
    final isRead = notification.isRead;
    
    // Determine color/icon based on type
    final Color color;
    final IconData icon;
    
    switch (notification.type) {
      case 'job':
        color = const Color(0xFF4CAF50);
        icon = Icons.work_rounded;
        break;
      case 'booking':
        color = AppColors.primaryBlue;
        icon = Icons.calendar_today_rounded;
        break;
      case 'message':
        color = const Color(0xFF1E88E5);
        icon = Icons.chat_bubble_rounded;
        break;
      case 'payment':
        color = Colors.purple;
        icon = Icons.payment_rounded;
        break;
      case 'alert':
        color = AppColors.error;
        icon = Icons.warning_rounded;
        break;
      default:
        color = AppColors.primaryBlue;
        icon = Icons.notifications_rounded;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.error.withValues(alpha: 0.8), AppColors.error],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) {
        context.read<NotificationProvider>().deleteNotification(userId, notification.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Notification deleted")));
      },
      child: GestureDetector(
        onLongPress: () {
           showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               title: const Text("Delete Notification"),
               content: const Text("Are you sure you want to delete this notification?"),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                 TextButton(
                   onPressed: () {
                     context.read<NotificationProvider>().deleteNotification(userId, notification.id);
                     Navigator.pop(ctx);
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Notification deleted")));
                   }, 
                   child: const Text("Delete", style: TextStyle(color: Colors.red))
                 ),
               ],
             )
           );
        },
        onTap: () {
          if (!isRead) {
            context.read<NotificationProvider>().markAsRead(userId, notification.id);
          }
          // Handle navigation
          if (notification.type == 'message') {
             Navigator.pushNamed(context, '/chats');
          } else if (notification.type == 'booking') {
             // For booking updates, we need to know valid route info.
             // If payload has data, use it. But model might not expose full payload easily here?
             // Helper navigation:
             Navigator.pushNamed(context, '/my-bookings');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // Read notifications settle into the same flat neumorphic look as
          // the rest of the app; unread ones keep their type color as a
          // highlight so "something new" still visibly stands out.
          decoration: isRead
              ? NeuTheme.sm(radius: 20)
              : BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.08),
                      color.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.2),
                            color.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, size: 28, color: color),
                    ),
                    const SizedBox(width: 16),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color, color.withValues(alpha: 0.8)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notification.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatTime(notification.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.grey600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: Duration(milliseconds: index * 80))
          .fadeIn(duration: 500.ms, curve: Curves.easeOut)
          .slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined, size: 60, color: AppColors.grey300),
          ),
          const SizedBox(height: 24),
          const Text('No Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Booking updates, messages, and offers will show up here.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
