// Booking Detail Screen - View booking details

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'providers/booking_provider.dart';
import 'package:home_technify/features/chat/providers/chat_provider.dart'; // Correct Import
import 'data/models/booking_model.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';

import 'package:intl/intl.dart';
import '../../core/utils/snackbar_helper.dart';
import 'live_track_map_screen.dart';
import 'reschedule_deadline.dart';
import '../../core/services/socket_service.dart';
import '../../core/widgets/video_player_screen.dart';
import '../../core/widgets/voice_note_tile.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final SocketService _socketService = SocketService();
  String? _currentBookingId;

  // Screens chain onto the socket callbacks; restore them on dispose so the
  // chain doesn't keep growing with dead closures.
  Function(Map<String, dynamic>)? _prevNotification;
  Function(Map<String, dynamic>)? _prevStatusChanged;

  @override
  void initState() {
    super.initState();
    _initSocketListeners();
  }

  void _initSocketListeners() {
    _prevNotification = _socketService.onNotification;
    final prevListener = _prevNotification;
    _socketService.onNotification = (data) {
       prevListener?.call(data);
       if (!mounted) return;

       final type = data['type'];
       // 'offer_received' is what a counter-offer arrives as — leaving it out
       // meant the customer's screen kept showing the stale price.
       if (['booking_rescheduled', 'booking_update', 'booking_accepted',
            'booking_cancelled', 'offer_received'].contains(type)) {
          final payload = data['data'];
          if (payload != null && payload['bookingId'] != null) {
              // Refresh if it matches current booking
              if (_currentBookingId == payload['bookingId']) {
                 _refreshBooking();
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Booking Updated!'), backgroundColor: AppColors.primaryBlue),
                 );
              }
          }
       }
    };

    // The backend also emits a dedicated booking_status_changed event on every
    // counter / accept. Nothing was listening to it, so those live updates were
    // being dropped on the floor.
    _prevStatusChanged = _socketService.onBookingStatusChanged;
    final prevStatus = _prevStatusChanged;
    _socketService.onBookingStatusChanged = (data) {
      prevStatus?.call(data);
      if (!mounted) return;
      if (data['bookingId'] == _currentBookingId) _refreshBooking();
    };
  }

  void _refreshBooking() {
     if (_currentBookingId != null) {
        context.read<BookingProvider>().fetchBookingById(_currentBookingId!);
     }
  }

  @override
  void dispose() {
    _socketService.onNotification = _prevNotification;
    _socketService.onBookingStatusChanged = _prevStatusChanged;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['bookingId'] != null) {
      _currentBookingId = args['bookingId'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    
    // Get the bookingId from navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? bookingId = args?['bookingId'];
    // final bool isActiveArg = args?['isActive'] ?? false; // We can derive this from status

    if (bookingId == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Error: No booking ID provided")));
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: Text('Booking Details', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: isSmall ? 18 : 20)),
        centerTitle: true,
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, child) {
          // Find the booking in the list or fetch it if needed (assuming list is loaded)
          // For now, let's try to find it in the provider's current list to avoid extra fetch if possible,
          // OR use FutureBuilder to fetch specific booking details if the API supports it better.
          // Given RemoteBookingRepository.getBookingById calls getMyBookings, it relies on the list.
          
          BookingModel? booking;
          try {
             booking = provider.bookings.firstWhere((b) => b.id == bookingId);
          } catch (e) {
            // Not found in current list, maybe show loader or fetch?
            // If provider.isLoading is true, we wait.
            if (provider.isLoading) {
               return const Center(child: CircularProgressIndicator());
            }
            // If not found and not loading, fetch it?
             // provider.fetchBookingById(bookingId); // Need to ensure this doesn't loop infinite
             return const Center(child: Text("Booking not found."));
          }
          
          // 'ongoing' is the status the backend actually sets once work starts.
          // Leaving it out hid Cancel/Reschedule and the payment summary for
          // every in-progress booking.
          final isActiveBooking = ['pending', 'accepted', 'in_progress', 'ongoing', 'active']
              .contains(booking.status.toLowerCase());

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(isSmall, booking.status),
                _buildReschedulePanel(context, booking),
                _buildOtpCard(booking),
                if (booking.status.toLowerCase() == 'negotiating')
                  _buildNegotiationPanel(context, isSmall, booking),
                SizedBox(height: isSmall ? 16 : 24),
                _buildServiceInfo(isSmall, booking),
                SizedBox(height: isSmall ? 16 : 24),
                _buildProviderInfo(context, isSmall, isActiveBooking, booking),
                SizedBox(height: isSmall ? 16 : 24),
                _buildBookingDetails(isSmall, booking),
                SizedBox(height: isSmall ? 16 : 24),
                _buildJobPostSection(isSmall, booking),
                if (!['negotiating'].contains(booking.status.toLowerCase()))
                   _buildPaymentInfo(isSmall, booking),
                if (isActiveBooking && booking.status.toLowerCase() != 'negotiating')
                  _buildActionButtons(context, horizontalPadding, isSmall, booking),
                _buildTrackProviderButton(booking),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // Pending reschedule proposal — accept / decline (real-time via socket).
  Widget _buildReschedulePanel(BuildContext context, BookingModel booking) {
    if (booking.rescheduleProposedAt == null) return const SizedBox.shrink();
    final proposed = booking.rescheduleProposedAt!.toLocal();
    final when = DateFormat('dd MMM yyyy, hh:mm a').format(proposed);
    // On the CUSTOMER screen: action required when PROVIDER proposed.
    final actionRequired = booking.rescheduleBy == 'PROVIDER';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.event_repeat_rounded, color: Colors.orange, size: 22),
            const SizedBox(width: 10),
            const Text('Reschedule Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Text(
            actionRequired
                ? '${booking.providerName} wants to reschedule to:\n$when'
                : 'You requested to reschedule to:\n$when\nWaiting for ${booking.providerName} to accept…',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
          ),
          RescheduleDeadline(booking: booking, actionRequired: actionRequired),

          // The proposer could not take their own request back — pick the wrong
          // date and you were stuck waiting for the other side (or the 24h
          // expiry) to clear it.
          if (!actionRequired) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelRescheduleRequest(booking),
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: const Text('Cancel my request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],

          if (actionRequired) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondReschedule(booking, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondReschedule(booking, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept', style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// Withdraw a reschedule request I made myself.
  Future<void> _cancelRescheduleRequest(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel your reschedule request?'),
        content: const Text(
            'The booking keeps its original time and the provider is told the request was withdrawn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final bookingProvider = context.read<BookingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await bookingProvider.cancelReschedule(booking.id);
    if (!mounted) return;

    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Request withdrawn — the original time stands.'
          : (bookingProvider.errorMessage ?? 'Could not withdraw the request')),
      backgroundColor: ok ? AppColors.primaryBlue : AppColors.error,
    ));
    if (ok) _refreshBooking();
  }

  Future<void> _respondReschedule(BookingModel booking, bool accept) async {
    final bookingProvider = context.read<BookingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await bookingProvider.respondReschedule(booking.id, accept);
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(accept ? 'Reschedule accepted — booking updated!' : 'Reschedule declined.'),
        backgroundColor: accept ? AppColors.success : AppColors.primaryBlue,
      ));
      _refreshBooking();
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(bookingProvider.errorMessage ?? 'Something went wrong'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // Two-OTP security card — customer shares the code with the provider on-site.
  // Customer taps this to see WHERE the provider is on a real map, with the
  // road route + distance + ETA to their home (OSRM). Shown once a provider
  // is assigned (ACCEPTED / ONGOING) and their location is known.
  Widget _buildTrackProviderButton(BookingModel booking) {
    final status = booking.status.toLowerCase();
    final active = ['accepted', 'in_progress', 'ongoing', 'active'].contains(status);
    if (!active) return const SizedBox.shrink();
    // The button used to hide itself until the provider had a GPS fix, which is
    // exactly when the customer most wants to open the map and wait for one.

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => LiveTrackMapScreen(
                bookingId: booking.id,
                providerId: booking.providerId,
                view: TrackView.customerWatchingProvider,
                customerLat: booking.lat,      // destination: your home
                customerLng: booking.lng,
                providerLat: booking.providerLat, // last known position of the provider
                providerLng: booking.providerLng,
                providerName: booking.providerName,
              ),
            ));
          },
          icon: const Icon(Icons.map_rounded, size: 18),
          label: const Text('Track Provider on Map'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            foregroundColor: AppColors.primaryBlue,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpCard(BookingModel booking) {
    final status = booking.status.toUpperCase();
    String? otp;
    String title = '', hint = '';
    IconData icon = Icons.lock_rounded;

    if (status == 'ACCEPTED' && booking.startOtp != null) {
      otp = booking.startOtp;
      title = 'Start OTP';
      hint = 'Provider ke pohanchne par ye code batayein taake kaam shuru ho.';
      icon = Icons.play_circle_fill_rounded;
    } else if (status == 'ONGOING' && booking.completionOtp != null) {
      otp = booking.completionOtp;
      title = 'Completion OTP';
      hint = 'Kaam mukammal hone par ye code batayein — phir payment & rating khulega.';
      icon = Icons.check_circle_rounded;
    }

    if (otp == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)), child: const Text('SECURE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1))),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: otp.split('').map((d) => Container(
              width: 46, height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
            )).toList(),
          ),
          const SizedBox(height: 12),
          Text(hint, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, height: 1.4)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildNegotiationPanel(BuildContext context, bool isSmall, BookingModel booking) {
    // Determine strict role logic
    // Customer screen, so 'lastOfferBy' == 'PROVIDER' means ACTION REQUIRED
    // 'lastOfferBy' == 'CUSTOMER' means WAITING
    
    final bool actionRequired = booking.lastOfferBy == 'PROVIDER';
    
    return Container(
      margin: EdgeInsets.only(top: isSmall ? 16 : 24),
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: actionRequired ? AppColors.warning.withValues(alpha: 0.1) : AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: actionRequired ? AppColors.warning : AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.handshake_rounded, 
                color: actionRequired ? AppColors.warning : AppColors.textSecondary,
                size: isSmall ? 24 : 28
              ),
              const SizedBox(width: 12),
              Text(
                'Price Negotiation',
                style: TextStyle(
                  fontSize: isSmall ? 16 : 18, 
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            actionRequired 
              ? 'Provider has offered a price. You can accept or counter.' 
              : 'You have sent an offer. Waiting for provider response.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildPaymentRow('Current Offer', 'Rs. ${booking.price}', isTotal: true, isSmall: isSmall),
          
          if (actionRequired) ...[
             const SizedBox(height: 20),
             Row(
               children: [
                 Expanded(
                   child: ElevatedButton(
                     onPressed: () => _showCounterOfferDialog(context, booking),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.white,
                       foregroundColor: AppColors.textPrimary,
                       side: const BorderSide(color: AppColors.grey300),
                       padding: const EdgeInsets.symmetric(vertical: 12),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     ),
                     child: const Text('Counter Offer'),
                   ),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: ElevatedButton(
                     onPressed: () => _acceptOffer(booking),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppColors.success,
                       padding: const EdgeInsets.symmetric(vertical: 12),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     ),
                     child: const Text('Accept Price', style: TextStyle(color: Colors.white)),
                   ),
                 ),
               ],
             )
          ]
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  void _showCounterOfferDialog(BuildContext context, BookingModel booking) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Counter Offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your counter price:'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(context);
              final bookingProvider = context.read<BookingProvider>();
              final success = await bookingProvider.counterOffer(booking.id, controller.text);
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Counter offer sent successfully!'), backgroundColor: AppColors.success),
                );
              } else {
                // Smart-bidding fence (or other) rejection — show the reason,
                // e.g. "Minimum price for Fan Installation is Rs. 300".
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(bookingProvider.errorMessage ?? 'Could not send offer'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Send Offer'),
          ),
        ],
      ),
    );
  }

  void _acceptOffer(BookingModel booking) async {
      final messenger = ScaffoldMessenger.of(context);
      final chatProvider = context.read<ChatProvider>();
      final bookingProvider = context.read<BookingProvider>();

      final success = await bookingProvider.acceptOffer(booking.id);
      if (!mounted) return;
      if (success) {
           messenger.showSnackBar(
             const SnackBar(content: Text('Offer Accepted! Sending confirmation...'), backgroundColor: AppColors.success),
           );
           try {
            final message = "I have accepted your offer of Rs. ${booking.totalAmount}.";
            await chatProvider.sendMessage(
              senderId: booking.customerId,
              receiverId: booking.providerId,
              text: message,
              senderName: booking.customerName,
              receiverName: booking.providerName,
            );
             if (!mounted) return;
             Navigator.pushReplacementNamed(context, '/chat', arguments: {
               'recipientId': booking.providerId,
               'name': booking.providerName,
               'service': booking.serviceName
             });
           } catch (e) {
             debugPrint("Failed to send auto-message: $e");
             if (!mounted) return;
             Navigator.pop(context);
           }
      }
  }

  Widget _buildStatusCard(bool isSmall, String status) {
    String statusText;
    String statusMessage;
    IconData statusIcon;
    Color statusColor;

    switch (status.toLowerCase()) {
      case 'pending':
        statusText = 'Pending Approval';
        statusMessage = 'Waiting for provider to accept';
        statusIcon = Icons.watch_later_outlined;
        statusColor = Colors.orange;
        break;
      case 'active':
      case 'accepted':
      case 'in_progress':
        statusText = 'In Progress';
        statusMessage = 'Provider is working on your task';
        statusIcon = Icons.sync_rounded;
        statusColor = AppColors.primaryBlue;
        break;
      case 'completed':
        statusText = 'Completed';
        statusMessage = 'Service completed successfully';
        statusIcon = Icons.check_circle_rounded;
        statusColor = AppColors.success;
        break;
      case 'cancelled':
        statusText = 'Cancelled';
        statusMessage = 'This booking was cancelled';
        statusIcon = Icons.cancel_outlined;
        statusColor = AppColors.error;
        break;
      default:
        statusText = status;
        statusMessage = '';
        statusIcon = Icons.info_outline;
        statusColor = Colors.grey;
    }
    
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [statusColor, statusColor.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
        boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.3), blurRadius: isSmall ? 15 : 20, offset: Offset(0, isSmall ? 6 : 10))],
      ),
      child: Row(
        children: [
          Container(
            width: isSmall ? 52 : 60,
            height: isSmall ? 52 : 60,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(isSmall ? 14 : 16)),
            child: Icon(statusIcon, size: isSmall ? 28 : 32, color: Colors.white),
          ),
          SizedBox(width: isSmall ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText, style: TextStyle(color: Colors.white, fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700)),
                if(statusMessage.isNotEmpty) ...[
                  SizedBox(height: isSmall ? 2 : 4),
                  Text(statusMessage, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: isSmall ? 12 : 13)),
                ]
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildServiceInfo(bool isSmall, BookingModel booking) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(isSmall ? 14 : 16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Service Details', style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700)),
          SizedBox(height: isSmall ? 12 : 16),
          Row(
            children: [
              Container(
                width: isSmall ? 50 : 56,
                height: isSmall ? 50 : 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(isSmall ? 12 : 14),
                ),
                child: Icon(Icons.build_circle_outlined, size: isSmall ? 24 : 28, color: AppColors.primaryBlue),
              ),
              SizedBox(width: isSmall ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.serviceName, style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildProviderInfo(BuildContext context, bool isSmall, bool isActiveBooking, BookingModel booking) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(isSmall ? 14 : 16), border: Border.all(color: AppColors.grey200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Provider Details', style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700)),
          SizedBox(height: isSmall ? 12 : 16),
          Row(
            children: [
              Container(
                width: isSmall ? 50 : 56,
                height: isSmall ? 50 : 56,
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(isSmall ? 12 : 14)),
                child: Center(child: Text(booking.providerName.isNotEmpty ? booking.providerName.substring(0, 1).toUpperCase() : 'P', style: TextStyle(color: Colors.white, fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700))),
              ),
              SizedBox(width: isSmall ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.providerName, style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (isActiveBooking && ['accepted', 'in_progress', 'active'].contains(booking.status.toLowerCase())) // Only show buttons for active/accepted bookings
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showCallDialog(context),
                      child: Container(
                        width: isSmall ? 40 : 44,
                        height: isSmall ? 40 : 44,
                        decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isSmall ? 10 : 12)),
                        child: Icon(Icons.call_rounded, color: AppColors.primaryBlue, size: isSmall ? 18 : 20),
                      ),
                    ),
                    SizedBox(width: isSmall ? 6 : 8),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/chat', arguments: {
                        'recipientId': booking.providerId,
                        'name': booking.providerName,
                        'service': booking.serviceName,
                      }),
                      child: Container(
                        width: isSmall ? 40 : 44,
                        height: isSmall ? 40 : 44,
                        decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isSmall ? 10 : 12)),
                        child: Icon(Icons.chat_bubble_rounded, color: AppColors.primaryBlue, size: isSmall ? 18 : 20),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildBookingDetails(bool isSmall, BookingModel booking) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(isSmall ? 14 : 16), border: Border.all(color: AppColors.grey200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking Information', style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700)),
          SizedBox(height: isSmall ? 12 : 16),
          _buildInfoRow(Icons.tag_rounded, 'Booking ID',
              '#${booking.id.length >= 4 ? booking.id.substring(booking.id.length - 4).toUpperCase() : booking.id.toUpperCase()}', isSmall),
          SizedBox(height: isSmall ? 10 : 14),
          _buildInfoRow(Icons.calendar_today_rounded, 'Date & Time', DateFormat('dd MMM yyyy, hh:mm a').format(booking.bookingDate.toLocal()), isSmall),
          SizedBox(height: isSmall ? 10 : 14),
          _buildInfoRow(Icons.location_on_outlined, 'Address', booking.address, isSmall),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isSmall) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isSmall ? 32 : 36,
          height: isSmall ? 32 : 36,
          decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(isSmall ? 8 : 10)),
          child: Icon(icon, size: isSmall ? 16 : 18, color: AppColors.textSecondary),
        ),
        SizedBox(width: isSmall ? 10 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: isSmall ? 11 : 12, color: AppColors.textSecondary)),
              SizedBox(height: isSmall ? 1 : 2),
              Text(value, style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  /// The customer's original job post — what they actually asked for, including
  /// the photo / video / voice note they attached.
  Widget _buildJobPostSection(bool isSmall, BookingModel booking) {
    final hasPost = (booking.jobTitle ?? '').isNotEmpty ||
        (booking.jobDescription ?? '').isNotEmpty ||
        booking.jobMediaUrls.isNotEmpty;
    if (!hasPost) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 16 : 24),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(isSmall ? 14 : 16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Job Post',
                style: TextStyle(
                    fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700)),
            SizedBox(height: isSmall ? 10 : 12),
            if ((booking.jobTitle ?? '').isNotEmpty)
              Text(booking.jobTitle!,
                  style: TextStyle(
                      fontSize: isSmall ? 14 : 15, fontWeight: FontWeight.w600)),
            if ((booking.jobDescription ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(booking.jobDescription!,
                  style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      color: AppColors.textSecondary,
                      height: 1.4)),
            ],
            if (booking.jobMediaUrls.isNotEmpty) ...[
              SizedBox(height: isSmall ? 12 : 14),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: booking.jobMediaUrls.length,
                  separatorBuilder: (_, i) => const SizedBox(width: 10),
                  itemBuilder: (context, i) =>
                      _buildAttachmentTile(booking.jobMediaUrls[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 350.ms);
  }

  Widget _buildAttachmentTile(String url) {
    final lower = url.toLowerCase();
    final isAudio = lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg');
    if (isAudio) return Center(child: VoiceNoteTile(url: url));

    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(videoUrl: url, isNetwork: true),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
          image: isVideo
              ? null
              : DecorationImage(
                  image: NetworkImage(url),
                  fit: BoxFit.cover,
                  onError: (e, s) {},
                ),
        ),
        child: isVideo
            ? Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: AppColors.primaryBlue, size: 32),
              )
            : null,
      ),
    );
  }

  Widget _buildPaymentInfo(bool isSmall, BookingModel booking) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(isSmall ? 14 : 16), border: Border.all(color: AppColors.grey200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Details', style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700)),
          SizedBox(height: isSmall ? 12 : 16),
          _buildPaymentRow('Service Charge', 'Rs. ${booking.price}', isSmall: isSmall),
          SizedBox(height: isSmall ? 10 : 12),
          const Divider(),
          SizedBox(height: isSmall ? 10 : 12),
          _buildPaymentRow('Total Amount', 'Rs. ${booking.price}', isTotal: true, isSmall: isSmall),
          SizedBox(height: isSmall ? 12 : 16),
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 12),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isSmall ? 8 : 10)),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: isSmall ? 16 : 18),
                SizedBox(width: isSmall ? 6 : 8),
                Text('Cash on Delivery', style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w600, color: AppColors.success)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _buildPaymentRow(String label, String value, {bool isTotal = false, required bool isSmall}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isTotal ? (isSmall ? 14 : 15) : (isSmall ? 13 : 14), fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500, color: isTotal ? AppColors.textPrimary : AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: isTotal ? (isSmall ? 16 : 18) : (isSmall ? 13 : 14), fontWeight: FontWeight.w700, color: isTotal ? AppColors.primaryBlue : AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, double horizontalPadding, bool isSmall, BookingModel booking) {
    final canReschedule = ['pending', 'accepted'].contains(booking.status.toLowerCase());
    
    return Container(
      padding: EdgeInsets.all(isSmall ? horizontalPadding * 0.8 : horizontalPadding),
      decoration: BoxDecoration(color: AppColors.white, boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -5))]),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCancelDialog(context, booking.id),
                    child: Container(
                      height: isSmall ? 50 : 56,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1), 
                        borderRadius: BorderRadius.circular(isSmall ? 12 : 14),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Center(child: Text('Cancel', style: TextStyle(fontSize: isSmall ? 14 : 15, fontWeight: FontWeight.w600, color: AppColors.error))),
                    ),
                  ),
                ),
                if (canReschedule) ...[
                   SizedBox(width: isSmall ? 10 : 12),
                   Expanded(
                    child: GestureDetector(
                      onTap: () => _showRescheduleDialog(context, booking),
                      child: Container(
                        height: isSmall ? 50 : 56,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1), 
                          borderRadius: BorderRadius.circular(isSmall ? 12 : 14),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                         child: Center(child: Text('Reschedule', style: TextStyle(fontSize: isSmall ? 14 : 15, fontWeight: FontWeight.w600, color: Colors.orange))),
                      ),
                    ),
                  ),
                ]
              ],
            ),
            SizedBox(height: isSmall ? 10 : 12),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LiveTrackMapScreen(
                    bookingId: booking.id,
                    providerId: booking.providerId,
                    view: TrackView.customerWatchingProvider,
                    customerLat: booking.lat,
                    customerLng: booking.lng,
                    providerLat: booking.providerLat,
                    providerLng: booking.providerLng,
                    providerName: booking.providerName,
                  ),
                ));
              },
              child: Container(
                height: isSmall ? 50 : 56,
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(isSmall ? 12 : 14), boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))]),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Track', style: TextStyle(fontSize: isSmall ? 14 : 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCallDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Provider phone number will be available once backend is connected.'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.cancel_rounded, color: AppColors.primaryBlue, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Cancel Booking?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep It', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final bookingProvider = context.read<BookingProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final success = await bookingProvider.cancelBooking(bookingId);
              if (!mounted) return;
              if (success) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Booking cancelled successfully'), backgroundColor: AppColors.primaryBlue),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text(bookingProvider.errorMessage ?? 'Failed to cancel booking'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // --- RESCHEDULE LOGIC START ---
  void _showRescheduleDialog(BuildContext context, BookingModel booking) {
    if (!['pending', 'accepted'].contains(booking.status.toLowerCase())) {
      SnackBarHelper.showWarning(context, "Can only reschedule pending or accepted bookings.");
      return;
    }

    DateTime selectedDate = booking.bookingDate.toLocal();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(booking.bookingDate.toLocal());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final hour = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
          final minute = selectedTime.minute.toString().padLeft(2, '0');
          final period = selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
          final timeStr = '$hour:$minute $period';
          
          return AlertDialog(
            title: const Text("Reschedule Booking"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: AppColors.primaryBlue),
                  title: Text(DateFormat('EEE, MMM d, yyyy').format(selectedDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.access_time, color: AppColors.primaryBlue),
                  title: Text(timeStr),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) setState(() => selectedTime = picked);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final newDateTime = DateTime(
                    selectedDate.year, selectedDate.month, selectedDate.day,
                    selectedTime.hour, selectedTime.minute,
                  );
                  
                  final bookingProvider = context.read<BookingProvider>();
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await bookingProvider.rescheduleBooking(booking.id, newDateTime);
                  if (!mounted) return;
                  if (success) {
                    messenger.showSnackBar(const SnackBar(content: Text('Reschedule request sent — waiting for provider to accept.'), backgroundColor: AppColors.success));
                  } else {
                    messenger.showSnackBar(SnackBar(content: Text(bookingProvider.errorMessage ?? 'Reschedule Failed'), backgroundColor: Colors.red));
                  }
                },
                child: const Text("Confirm"),
              ),
            ],
          );
        },
      ),
    );
  }
  // --- RESCHEDULE LOGIC END ---
}
