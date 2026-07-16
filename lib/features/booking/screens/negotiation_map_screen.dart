import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:home_technify/core/constants/constants.dart';
import 'package:home_technify/core/services/socket_service.dart';
import 'package:home_technify/features/booking/data/models/booking_model.dart';
import 'package:home_technify/features/booking/providers/booking_provider.dart';
import 'package:home_technify/features/chat/providers/chat_provider.dart';
import 'package:home_technify/features/chat/data/models/message_model.dart';
import 'package:home_technify/features/auth/providers/auth_provider.dart';
import '../../auth/data/models/user_model.dart'; // Import UserModel

class NegotiationMapScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String serviceName;
  final String? jobId;
  final String? bookingId;

  const NegotiationMapScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.serviceName,
    this.jobId,
    this.bookingId,
  });

  @override
  State<NegotiationMapScreen> createState() => _NegotiationMapScreenState();
}

class _NegotiationMapScreenState extends State<NegotiationMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService _socketService = SocketService();
  
  LatLng? _currentLocation;
  LatLng? _providerLocation;
  // Booking State
  BookingModel? _booking;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenToProviderLocation();
    _initSocketListeners(); 
    
    if (widget.bookingId != null) {
      _fetchBooking();
    }
  }
  
  Future<void> _fetchBooking() async {
    final booking = await context.read<BookingProvider>().fetchBookingById(widget.bookingId!);
    if (mounted) {
      setState(() => _booking = booking);
    }
  }

  // Socket Listener for Offer Updates? 
  // Ideally SocketService should listen for 'offer_received' or 'booking_accepted' and update BookingProvider.
  // BookingProvider updates state, and if we watch it, we update.
  // But here we are using local _booking state from fetch.
  // We should watch provider for updates.

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ... Location methods (Keep same) ...
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _fitBounds();
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  void _initSocketListeners() {
    // We need to chain because SocketService might have only one callback property?
    // Looking at SocketService implementation usually, callbacks are properties.
    // If FindingProvidersScreen also listens, it might overwrite?
    // SocketService usually broadcasts or allows multiple listeners if using Streams.
    // Use the singleton instance's stream if available, or just overwrite if screens are exclusive.
    // Assuming we overwrite for this screen.
    
    _socketService.onNotification = (data) {
       if (!mounted) return;
       final type = data['type'];
       final payload = data['data'];
       // Check if this notification relates to OUR booking
       bool relevant = false;
       if (payload != null && payload['bookingId'] == widget.bookingId) {
         relevant = true;
       }
       
       if (relevant || type == 'booking_update' || type == 'booking_accepted' || type == 'offer_received') {
          // Ideally check ID, but refresh safely anyway
          if (widget.bookingId != null) {
             _fetchBooking();
             // Also show snackbar?
             if (type == 'offer_received') ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("New Counter Offer received!")));
             if (type == 'booking_accepted') ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Offer Accepted!")));
             if (type == 'booking_update') ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking Updated/Cancelled")));
          }
       }
    };
  }

  void _listenToProviderLocation() {
    _socketService.onProviderLocation = (data) {
      if (data['providerId'] == widget.providerId) {
        setState(() {
          _providerLocation = LatLng(data['latitude'], data['longitude']);
        });
        // Optional: fit bounds
      }
    };
  }
  
  void _fitBounds() {
    if (_currentLocation != null && _providerLocation != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([_currentLocation!, _providerLocation!]),
          padding: const EdgeInsets.all(50),
        ),
      );
    } else if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    }
  }
  // ... End Location methods ...

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    _messageController.clear();

    final messenger = ScaffoldMessenger.of(context);
    context.read<ChatProvider>().sendMessage(
      senderId: user.id,
      receiverId: widget.providerId,
      text: text,
      senderName: user.name,
      receiverName: widget.providerName,
    ).catchError((e) {
      messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
    });
  }
  
  Future<void> _submitCounterOffer() async {
     final bookingProvider = context.read<BookingProvider>();
     final messenger = ScaffoldMessenger.of(context);
     double? price;
     final controller = TextEditingController();

     final confirm = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: Text("Counter Offer"),
         content: TextField(
           controller: controller,
           keyboardType: TextInputType.number,
           decoration: InputDecoration(labelText: "Enter Amount (Rs.)", prefixText: "Rs. "),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel")),
           ElevatedButton(
             onPressed: () {
               if (controller.text.isNotEmpty) {
                 price = double.tryParse(controller.text);
                 Navigator.pop(ctx, true);
               }
             },
             child: Text("Submit"),
           )
         ],
       )
     );
     
     if (confirm == true && price != null && widget.bookingId != null) {
        final success = await bookingProvider.counterOffer(widget.bookingId!, price.toString());
        if (!mounted) return;
        if (success) {
           _fetchBooking();
           messenger.showSnackBar(const SnackBar(content: Text("Counter offer sent!")));
        }
     }
  }

  Future<void> _acceptOffer() async {
    if (widget.bookingId == null) return;

    final bookingProvider = context.read<BookingProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Accept Offer"),
        content: const Text("Are you sure you want to accept this price?"),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
           ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Accept")),
        ]
      )
    );

    if (confirm == true) {
       final success = await bookingProvider.acceptOffer(widget.bookingId!);
       if (!mounted) return;
       if (success) {
          _fetchBooking();
          messenger.showSnackBar(const SnackBar(content: Text("Offer Accepted! Deal Finalized.")));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    // Watch booking provider for realtime updates if we want
    // But we are using local _fetchBooking. 
    // Ideally, we should use Consumer<BookingProvider> to get the booking if it's in the list.
    // Let's rely on _fetchBooking for now, or add a listener. 
    // Actually, context.watch<BookingProvider>().bookings could work if we find it.
    
    BookingModel? liveBooking;
    if (widget.bookingId != null) {
       try {
         liveBooking = context.watch<BookingProvider>().bookings.firstWhere((b) => b.id == widget.bookingId);
       } catch (_) {
         liveBooking = _booking;
       }
    }
    
    final isNegotiating = liveBooking?.status == 'NEGOTIATING' || liveBooking?.status == 'PENDING';
    final isConfirmed = ['ACCEPTED', 'ONGOING', 'IN_PROGRESS', 'COMPLETED'].contains(liveBooking?.status);

    if (isConfirmed && liveBooking != null) {
      return _buildBookingConfirmedView(liveBooking, user);
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(31.5204, 74.3587),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.home_technify',
              ),
              MarkerLayer(
                markers: [
                  if (_currentLocation != null)
                     Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryBlue, width: 2),
                        ),
                        child:  Icon(Icons.home_rounded, color: AppColors.primaryBlue, size: 24),
                      ),
                    ),
                  if (_providerLocation != null)
                     Marker(
                      point: _providerLocation!,
                      width: 50,
                      height: 50,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
                            ),
                            child: const Icon(Icons.build_circle_rounded, color: AppColors.primaryBlue, size: 28),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                            child: Text(widget.providerName, style: const TextStyle(color: Colors.white, fontSize: 10), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // 2. Back Button & Header
          Positioned(
            top: 40, left: 16, right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)]),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)]),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 16, backgroundColor: AppColors.grey200, child: Text(widget.providerName[0].toUpperCase())),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.providerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(liveBooking?.status ?? "Tracking", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isNegotiating ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                             liveBooking?.status ?? "Active", 
                             style: TextStyle(
                               color: isNegotiating ? Colors.orange : Colors.green, 
                               fontSize: 10, fontWeight: FontWeight.bold
                             )
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Sheet (Chat & Offers)
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.2,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
                ),
                child: Column(
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 5, margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    
                    // --- NEGOTIATION PANEL ---
                    if (isNegotiating && liveBooking != null)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1))
                        ),
                        child: Column(
                          children: [
                            Text("Current Offer: Rs. ${liveBooking.price.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue)),
                            SizedBox(height: 8),
                            if (widget.bookingId != null) // Ensure we have ID
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _submitCounterOffer,
                                    child: Text("Counter Offer"),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _acceptOffer,
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                                    child: Text("Accept"),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    
                    // Messages
                    Expanded(
                      child: user == null ? const Center(child: CircularProgressIndicator()) : StreamBuilder(
                        stream: context.read<ChatProvider>().getMessages(user.id, widget.providerId),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return const Center(child: Text("Error loading chats"));
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          
                          final messages = snapshot.data!;
                          final reversedMessages = messages.reversed.toList();
                          
                          return ListView.builder(
                            controller: scrollController, 
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: reversedMessages.length,
                            itemBuilder: (context, index) {
                              final msg = reversedMessages[index];
                              final isMe = msg.senderId == user.id;
                              return _buildMapChatBubble(msg, isMe);
                            },
                          );
                        },
                      ),
                    ),
                    
                    // Input Area or Status Message
                    if (isNegotiating)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[50],
                        child: const Text(
                          "Finalize the deal to start chatting.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.only(
                          left: 16, 
                          right: 16, 
                          top: 16, 
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(24)),
                                child: TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
                                  onChanged: (val) {},
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapChatBubble(MessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryBlue : AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.type == 'text')
              Text(message.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87))
            else
              Text("[${message.type}]", style: TextStyle(fontStyle: FontStyle.italic, color: isMe ? Colors.white70 : Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingConfirmedView(BookingModel booking, UserModel? user) {
     return Scaffold(
        appBar: AppBar(
          title: const Text("Booking Confirmed"),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
             // Status Card
             Container(
               margin: const EdgeInsets.all(16),
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: AppColors.success.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(color: AppColors.success),
               ),
               child: Row(
                 children: [
                   const CircleAvatar(
                     backgroundColor: AppColors.success,
                     child: Icon(Icons.check, color: Colors.white),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text("Deal Finalized!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.success)),
                         const SizedBox(height: 4),
                         Text("Agreed Price: Rs. ${booking.price}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                       ],
                     ),
                   ),
                 ],
               ),
             ),
             
             const Divider(),
             
             // Chat Area
             Expanded(
                child: user == null ? const Center(child: CircularProgressIndicator()) : StreamBuilder(
                  stream: context.read<ChatProvider>().getMessages(user.id, widget.providerId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Error loading chats"));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final messages = snapshot.data!;
                    final reversedMessages = messages.reversed.toList();
                    
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: reversedMessages.length,
                            itemBuilder: (context, index) {
                              final msg = reversedMessages[index];
                              final isMe = msg.senderId == user.id;
                              return _buildMapChatBubble(msg, isMe);
                            },
                          ),
                        ),
                        // Input Area
                        Container(
                          padding: EdgeInsets.only(
                            left: 16, 
                            right: 16, 
                            top: 16, 
                            bottom: MediaQuery.of(context).viewInsets.bottom + 16
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(24)),
                                  child: TextField(
                                    controller: _messageController,
                                    decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _sendMessage,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
             ),
          ],
        ),
     );
  }
}
