import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/provider_location_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../booking/providers/booking_provider.dart';
import '../../booking/data/models/booking_model.dart';
import '../../booking/provider_work_flow_screen.dart';
import '../../booking/live_track_map_screen.dart';
import '../../booking/reschedule_deadline.dart';
import '../../../core/theme/neu_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../chat/providers/chat_provider.dart';
import '../../../core/services/socket_service.dart';

class OngoingServiceScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData; // Passed from nav args
  
  const OngoingServiceScreen({super.key, this.bookingData});

  @override
  State<OngoingServiceScreen> createState() => _OngoingServiceScreenState();
}

class _OngoingServiceScreenState extends State<OngoingServiceScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isStarted = false;
  final ProviderLocationService _locationService = ProviderLocationService();
  bool _isBroadcastingLocation = false;
  
  BookingModel? _booking;
  bool _isLoading = true;

  final SocketService _socketService = SocketService();

  // Restored on dispose so the callback chain doesn't grow dead closures.
  Function(Map<String, dynamic>)? _prevNotification;
  Function(Map<String, dynamic>)? _prevStatusChanged;

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _initSocketListeners();
  }

  void _initSocketListeners() {
    _prevNotification = _socketService.onNotification;
    final prevListener = _prevNotification;
    _socketService.onNotification = (data) {
       prevListener?.call(data);
       if (!mounted) return;

       final type = data['type'];
       // 'offer_received' = the customer countered. Without it the provider's
       // screen kept showing the old price until a manual refresh.
       if (['booking_rescheduled', 'booking_update', 'booking_accepted',
            'booking_cancelled', 'offer_received'].contains(type)) {
          final payload = data['data'];
          if (payload != null && payload['bookingId'] != null) {
              if (_booking?.id == payload['bookingId']) {
                 _loadBooking();
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Booking Updated!'), backgroundColor: AppColors.primaryBlue),
                 );
              }
          }
       }
    };

    // Dedicated status event the backend emits on every counter / accept.
    _prevStatusChanged = _socketService.onBookingStatusChanged;
    final prevStatus = _prevStatusChanged;
    _socketService.onBookingStatusChanged = (data) {
      prevStatus?.call(data);
      if (!mounted) return;
      if (data['bookingId'] == _booking?.id) _loadBooking();
    };
  }

  Future<void> _loadBooking() async {
    final bookingId = widget.bookingData?['bookingId'];
    if (bookingId != null) {
        final provider = context.read<BookingProvider>();

        // Try to find in list first
        try {
           _booking = provider.bookings.firstWhere((b) => b.id == bookingId);
           setState(() => _isLoading = false);
        } catch (_) {
           // Not found locally, fetch from API
           _booking = await provider.fetchBookingById(bookingId);
           setState(() => _isLoading = false);
        }
    } else {
        setState(() => _isLoading = false);
    }
    _maybeBroadcastLocation();
  }

  /// The customer needs to see the provider coming — that is, while they are
  /// TRAVELLING, not once the work has begun. Broadcasting used to be started
  /// from a method that nothing ever called, so no location was ever sent and
  /// the tracking map had nothing to show.
  void _maybeBroadcastLocation() {
    final b = _booking;
    if (b == null || _isBroadcastingLocation) return;
    final onTheJob = ['accepted', 'ongoing', 'in_progress'].contains(b.status.toLowerCase());
    if (onTheJob) _startLocationBroadcasting();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _socketService.onNotification = _prevNotification;
    _socketService.onBookingStatusChanged = _prevStatusChanged;
    if (_isBroadcastingLocation) {
      _locationService.stopBroadcasting();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isStarted = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
    });
    _startLocationBroadcasting();
  }
  
  Future<void> _startLocationBroadcasting() async {
    if (_booking == null) return;
    try {
        await _locationService.startBroadcasting(
          bookingId: _booking!.id,
          providerId: _booking!.providerId,
        );
        setState(() => _isBroadcastingLocation = true);
        if (mounted) SnackBarHelper.showSuccess(context, 'Sharing location with customer');
    } catch (e) {
      debugPrint('Location broadcast error: $e');
    }
  }


  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Open the real map: provider's live location → customer's job location,
  // with the road route + real distance + ETA (OSRM).
  Future<void> _openRouteToCustomer() async {
    final b = _booking;
    if (b == null) return;
    if (b.lat == 0 || b.lng == 0) {
      SnackBarHelper.showError(context, 'Customer location not available for this job.');
      return;
    }
    double? myLat, myLng;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));
      myLat = pos.latitude;
      myLng = pos.longitude;
    } catch (_) {/* fall back to provider profile location below */}
    myLat ??= b.providerLat;
    myLng ??= b.providerLng;
    if (!mounted) return;

    // Live map: the provider's own GPS drives the marker and is broadcast to the
    // customer at the same time, so both sides watch the same journey.
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => LiveTrackMapScreen(
        bookingId: b.id,
        providerId: b.providerId,
        view: TrackView.providerGoingToCustomer,
        customerLat: b.lat,
        customerLng: b.lng,
        providerLat: myLat,
        providerLng: myLng,
        customerName: b.customerName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_booking == null) return const Scaffold(body: Center(child: Text("Booking not found. Please refresh.")));

    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    
    final isNegotiating = _booking!.status.toLowerCase() == 'negotiating';
    final isAccepted = ['accepted', 'in_progress', 'ongoing'].contains(_booking!.status.toLowerCase());

    return Scaffold(
      backgroundColor: NeuTheme.bg,
      appBar: AppBar(
        backgroundColor: NeuTheme.bg,
        surfaceTintColor: NeuTheme.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: Text(
           isNegotiating ? 'Negotiation' : 'Ongoing Service',
           style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 18)
        ),
        centerTitle: true,
        actions: [
          // Real map + route + distance + ETA to the customer
          IconButton(
            tooltip: 'Route to customer',
            icon: const Icon(Icons.map_rounded, color: AppColors.primaryBlue),
            onPressed: _openRouteToCustomer,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'cancel') {
                _showCancelDialog();
              } else if (value == 'reschedule') {
                _showRescheduleDialog();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                if (!['completed', 'cancelled', 'rejected'].contains(_booking?.status.toLowerCase()))
                  const PopupMenuItem(
                    value: 'reschedule',
                    child: Row(
                      children: [
                        Icon(Icons.edit_calendar_rounded, color: Colors.orange, size: 20),
                         SizedBox(width: 8),
                        Text('Reschedule'),
                      ],
                    ),
                  ),
                if (!['completed', 'cancelled', 'rejected'].contains(_booking?.status.toLowerCase()))
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                         SizedBox(width: 8),
                        Text('Cancel Booking'),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_booking!.rescheduleProposedAt != null) ...[
               _buildReschedulePanel(isSmall),
               const SizedBox(height: 20),
            ],
            if (isNegotiating)
               _buildNegotiationPanel(isSmall)
            else if (isAccepted)
               _buildTimerCard(isSmall),

            const SizedBox(height: 20),
            _buildCustomerCard(isSmall),
            const SizedBox(height: 20),
            _buildServiceDetails(isSmall),
            const SizedBox(height: 20),
            _buildLocationCard(isSmall),
            const SizedBox(height: 16),
            _buildTrackCustomerButton(),

            const SizedBox(height: 80), // Space for bottom button
          ],
        ),
      ),
      bottomNavigationBar: (isAccepted || _booking!.status.toUpperCase() == 'ONGOING')
          ? _buildSecureFlowButton(horizontalPadding)
          : null,
    );
  }

  // Opens the two-OTP secure work flow (arrive -> start OTP + before photo ->
  // complete OTP + after photo). Replaces the old direct "complete" bypass.
  /// Mirror of the customer's "Track Provider" button: the provider gets the
  /// road route, distance and ETA to the customer's door.
  Widget _buildTrackCustomerButton() {
    final b = _booking!;
    if (b.lat == 0 || b.lng == 0) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openRouteToCustomer,
        icon: const Icon(Icons.navigation_rounded, size: 18),
        label: const Text('Track Customer on Map'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
          foregroundColor: AppColors.primaryBlue,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildSecureFlowButton(double horizontalPadding) {
    final ongoing = _booking!.status.toUpperCase() == 'ONGOING';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 14),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => ProviderWorkFlowScreen(booking: _booking!)),
              );
              if (updated == true && mounted) {
                await context.read<BookingProvider>().fetchBookingById(_booking!.id);
                if (mounted) setState(() {});
              }
            },
            icon: const Icon(Icons.lock_open_rounded, size: 20),
            label: Text(ongoing ? 'Complete Work (OTP)' : 'Start Work (OTP)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
          ),
        ),
      ),
    );
  }
  
  // Pending reschedule proposal — accept / decline (real-time via socket).
  Widget _buildReschedulePanel(bool isSmall) {
    final proposed = _booking!.rescheduleProposedAt!.toLocal();
    final when = DateFormat('dd MMM yyyy, hh:mm a').format(proposed);
    // On the PROVIDER screen: action required when CUSTOMER proposed.
    final actionRequired = _booking!.rescheduleBy == 'CUSTOMER';

    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.event_repeat_rounded, color: Colors.orange, size: 22),
            SizedBox(width: 10),
            Text('Reschedule Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Text(
            actionRequired
                ? '${_booking!.customerName} wants to reschedule to:\n$when'
                : 'You requested to reschedule to:\n$when\nWaiting for the customer to accept…',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
          ),
          RescheduleDeadline(booking: _booking!, actionRequired: actionRequired),

          // The proposer could not take their own request back — pick the wrong
          // date and you were stuck waiting for the other side (or the 24h
          // expiry) to clear it.
          if (!actionRequired) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelRescheduleRequest,
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
                  onPressed: () => _respondReschedule(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondReschedule(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
  Future<void> _cancelRescheduleRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel your reschedule request?'),
        content: const Text(
            'The booking keeps its original time and the customer is told the request was withdrawn.'),
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
    final ok = await bookingProvider.cancelReschedule(_booking!.id);
    if (!mounted) return;

    if (ok) await _loadBooking();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Request withdrawn — the original time stands.'
          : (bookingProvider.errorMessage ?? 'Could not withdraw the request')),
      backgroundColor: ok ? AppColors.primaryBlue : AppColors.error,
    ));
  }

  Future<void> _respondReschedule(bool accept) async {
    final bookingProvider = context.read<BookingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await bookingProvider.respondReschedule(_booking!.id, accept);
    if (!mounted) return;
    if (ok) {
      await _loadBooking();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(accept ? 'Reschedule accepted — booking updated!' : 'Reschedule declined.'),
        backgroundColor: accept ? AppColors.success : AppColors.primaryBlue,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(bookingProvider.errorMessage ?? 'Something went wrong'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _buildNegotiationPanel(bool isSmall) {
     final actionRequired = _booking!.lastOfferBy == 'CUSTOMER';
     
     return Container(
       padding: EdgeInsets.all(isSmall ? 16 : 24),
       decoration: BoxDecoration(
          color: actionRequired ? AppColors.warning.withValues(alpha: 0.1) : AppColors.grey50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: actionRequired ? AppColors.warning : AppColors.grey200),
       ),
       child: Column(
          children: [
             Icon(Icons.handshake_rounded, size: 40, color: actionRequired ? AppColors.warning : AppColors.textSecondary),
             const SizedBox(height: 12),
             Text(
               actionRequired ? 'Customer Countered!' : 'Offer Sent',
               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
             ),
             const SizedBox(height: 8),
             Text(
               actionRequired 
                 ? 'Customer has countered with a new price. Accept or Counter again.' 
                 : 'Waiting for customer response.',
               textAlign: TextAlign.center,
               style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
             ),
             const SizedBox(height: 24),
             _buildInfoRow('Current Offer', 'Rs. ${_booking!.price}', isTotal: true),
             
             if (actionRequired) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showCounterDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.grey300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Counter'),
                      ),
                    ),
                    const SizedBox(width: 12),
                     Expanded(
                      child: ElevatedButton(
                        onPressed: _acceptOffer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Accept', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
             ]
          ],
       ),
     );
  }
  
  void _showCounterDialog() {
      final controller = TextEditingController();
      showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
              title: const Text("Counter Offer"),
              content: TextField(
                  controller: controller, 
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'New Price (Rs)')
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  ElevatedButton(
                      onPressed: () async {
                          if (controller.text.isEmpty) return;
                          Navigator.pop(ctx);
                          await context.read<BookingProvider>().counterOffer(_booking!.id, controller.text);
                          setState(() {}); // Refresh UI
                      }, 
                      child: const Text("Send")
                  )
              ],
          )
      );
  }
  
  void _acceptOffer() async {
      final bookingProvider = context.read<BookingProvider>();
      final chatProvider = context.read<ChatProvider>();
      final messenger = ScaffoldMessenger.of(context);

      final success = await bookingProvider.acceptOffer(_booking!.id);
      if (!mounted) return;
      if (success) {
           await _loadBooking();
           try {
             final message = "Hello! I have accepted your booking request for ${_booking!.serviceName} at Rs. ${_booking!.price}. Let's discuss the details.";
             await chatProvider.sendMessage(
               senderId: _booking!.providerId,
               receiverId: _booking!.customerId,
               text: message,
             );
             if (!mounted) return;
             messenger.showSnackBar(const SnackBar(content: Text('Offer Accepted! Auto-message sent.'), backgroundColor: AppColors.success));
             Navigator.pushNamed(context, '/chat', arguments: {
                'recipientId': _booking!.customerId,
                'name': _booking!.customerName,
                'service': _booking!.serviceName
             });
           } catch (e) {
              debugPrint("Auto-message error: $e");
           }
      }
  }

  void _showCancelDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Are you sure you want to cancel this booking? This action cannot be undone."),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: "Reason for cancellation", border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Keep Booking")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide a reason")));
                 return;
              }
              final bookingProvider = context.read<BookingProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              Navigator.pop(ctx);
              final success = await bookingProvider.cancelBooking(_booking!.id, reason: reasonController.text);
              if (!mounted) return;
              if (success) {
                 messenger.showSnackBar(const SnackBar(content: Text("Booking Cancelled")));
                 navigator.pop();
              }
            },
            child: const Text("Confirm Cancel", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showRescheduleDialog() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _booking!.bookingDate.toLocal(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_booking!.bookingDate.toLocal()),
    );
    if (pickedTime == null) return;

    final newDateTime = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Reschedule"),
        content: Text("Reschedule to ${DateFormat('dd MMM yyyy, hh:mm a').format(newDateTime)}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final bookingProvider = context.read<BookingProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await bookingProvider.rescheduleBooking(_booking!.id, newDateTime);
              if (!mounted) return;
              if (success) {
                 await _loadBooking();
                 messenger.showSnackBar(const SnackBar(content: Text("Reschedule request sent — waiting for customer to accept.")));
              }
            },
            child: const Text("Confirm"),
          )
        ],
      ),
    );
  }

  Widget _buildTimerCard(bool isSmall) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 24 : 30),
      decoration: BoxDecoration(
        gradient: _isStarted ? AppColors.primaryGradient : null,
        color: _isStarted ? null : AppColors.grey100,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _isStarted ? [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ] : null,
      ),
      child: Column(
        children: [
          Icon(
            _isStarted ? Icons.timer_rounded : Icons.play_circle_filled_rounded,
            size: 50,
            color: _isStarted ? Colors.white : AppColors.primaryBlue,
          ),
          const SizedBox(height: 16),
          Text(
            _isStarted ? 'Service In Progress' : 'Ready to Start?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _isStarted ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(_elapsedSeconds),
            style: TextStyle(
              fontSize: isSmall ? 40 : 48,
              fontWeight: FontWeight.w800,
              color: _isStarted ? Colors.white : AppColors.textPrimary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          if (!_isStarted)
            GestureDetector(
              onTap: _startTimer,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  'Start Service',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildCustomerCard(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _booking!.customerName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customer', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(_booking!.customerName, style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
           // Call icon removed as requested
           const SizedBox(width: 8),
          GestureDetector(
             onTap: () {
               // Chat logic
               if (_booking!.status.toLowerCase() == 'negotiating') {
                   SnackBarHelper.showWarning(context, "Finish negotiation first");
                   return;
               }
               // Go to specific chat
               Navigator.pushNamed(context, '/chat', arguments: {
                  'recipientId': _booking!.customerId,
                  'name': _booking!.customerName,
                  'service': _booking!.serviceName
               });
             },
            child: CircleAvatar(
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
              child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildServiceDetails(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          _buildInfoRow('Booking ID', '#${_booking!.id.length >= 4 ? _booking!.id.substring(_booking!.id.length - 4).toUpperCase() : _booking!.id.toUpperCase()}'),
          const SizedBox(height: 12),
          _buildInfoRow('Service', _booking!.serviceName),
          const SizedBox(height: 12),
          _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(_booking!.bookingDate.toLocal())),
          const SizedBox(height: 12),
          _buildInfoRow('Time', DateFormat('hh:mm a').format(_booking!.bookingDate.toLocal())),
           const SizedBox(height: 12),
          _buildInfoRow('Price', 'Rs. ${_booking!.price}', isTotal: true),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildLocationCard(bool isSmall) {
    return Container(
          padding: EdgeInsets.all(isSmall ? 14 : 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _booking!.address,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              const Icon(Icons.navigation_rounded, color: AppColors.primaryBlue, size: 22),
            ],
          ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isTotal ? 16 : 14, color: isTotal ? AppColors.primaryBlue : AppColors.textPrimary)),
      ],
    );
  }
}
