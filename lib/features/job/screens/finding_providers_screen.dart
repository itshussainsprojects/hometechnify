// Finding Providers — Customer posts a job → providers quote on it.
// This screen shows ONLY the providers who have quoted (sent an offer)
// for this job, under "Available Providers".
//   - Quoted rate shows on the right ("Service Rate").
//   - "Book" accepts the quote and goes straight to the booking screen.
//   - "Negotiate" opens a popup (provider profile + amount + send) and the
//     back-and-forth happens in real time via socket.
// No chat and no map here — chat unlocks after booking; map lives on the
// booking screen (Track button).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/theme/neu_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../booking/data/models/booking_model.dart';
import '../../booking/providers/booking_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../provider/data/models/provider_model.dart';
import '../../provider/data/repositories/remote_provider_repository.dart';
import '../data/models/job_post_model.dart';

class FindingProvidersScreen extends StatefulWidget {
  final String jobId;
  final String serviceName;
  final String serviceId;
  final JobPostModel? jobData;

  const FindingProvidersScreen({
    super.key,
    required this.jobId,
    required this.serviceName,
    required this.serviceId,
    this.jobData,
  });

  @override
  State<FindingProvidersScreen> createState() => _FindingProvidersScreenState();
}

class _FindingProvidersScreenState extends State<FindingProvidersScreen> {
  final SocketService _socketService = SocketService();
  final RemoteProviderRepository _providerRepository =
      RemoteProviderRepository();

  // Used only to enrich quote cards with rating / photo / distance.
  final Map<String, ProviderModel> _providerInfo = {};
  bool _isLoadingOffers = true;

  // Poll while this screen is open. The socket is the fast path, but a dropped
  // socket must never mean the customer silently misses a provider's quote.
  Timer? _poll;
  Function(Map<String, dynamic>)? _prevNotificationListener;

  @override
  void initState() {
    super.initState();
    _initSocketListener();
    _fetchInitialOffers();
    _fetchProviderInfo();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchInitialOffers(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    // Restore whatever listener was in place before this screen hooked in,
    // otherwise the chain keeps growing with dead closures.
    _socketService.onNotification = _prevNotificationListener;
    super.dispose();
  }

  Future<void> _fetchProviderInfo() async {
    var result =
        await _providerRepository.getProviders(categoryId: widget.serviceId);
    if (result.isSuccess && (result.data == null || result.data!.isEmpty)) {
      result = await _providerRepository.getProviders();
    }
    if (!mounted) return;
    setState(() {
      for (final p in (result.data ?? <ProviderModel>[])) {
        _providerInfo[p.id] = p;
      }
    });
  }

  /// [silent] = background poll: don't flash the loading spinner.
  Future<void> _fetchInitialOffers({bool silent = false}) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) {
      if (mounted) setState(() => _isLoadingOffers = false);
      return;
    }
    await context.read<BookingProvider>().fetchMyBookings(authProvider.user!.id);
    if (mounted && !silent) setState(() => _isLoadingOffers = false);
  }

  void _initSocketListener() {
    final prev = _socketService.onNotification;
    _prevNotificationListener = prev;
    _socketService.onNotification = (data) {
      prev?.call(data);
      if (!mounted) return;
      final type = data['type'];
      if (['offer_received', 'counter_offer', 'booking_update',
           'booking_accepted', 'booking_cancelled'].contains(type)) {
        _fetchInitialOffers();
        if (type == 'offer_received' || type == 'counter_offer') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('New offer received!'),
                backgroundColor: AppColors.primaryBlue),
          );
        }
      }
    };
  }

  Future<void> _refresh() async {
    await Future.wait([_fetchInitialOffers(), _fetchProviderInfo()]);
  }

  // ─── ACTIONS ────────────────────────────────────────────────────────────

  /// "Book" — accept the provider's quoted rate and go straight to booking.
  Future<void> _bookOffer(BookingModel offer) async {
    final bookingProvider = context.read<BookingProvider>();
    final ok = await bookingProvider.acceptOffer(offer.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Booked with ${offer.providerName}!'),
            backgroundColor: AppColors.success),
      );
      Navigator.pushNamed(context, '/booking-detail',
          arguments: {'bookingId': offer.id});
      _fetchInitialOffers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                bookingProvider.errorMessage ?? 'Could not book right now'),
            backgroundColor: AppColors.error),
      );
    }
  }

  /// "Negotiate" — small popup with provider profile + amount + send.
  void _openNegotiatePopup(BookingModel offer) {
    final controller = TextEditingController();
    final info = _providerInfo[offer.providerId];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: NeuTheme.bg,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Negotiate',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              _neuAvatar(offer.providerName, AppColors.primaryBlue,
                  image: info?.profileImage, size: 56),
              const SizedBox(height: 10),
              Text(offer.providerName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Service Rate: Rs. ${offer.price.toInt()}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: NeuTheme.sm(radius: 12),
                child: Row(
                  children: [
                    const Text('Rs.',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter your amount',
                          hintStyle: TextStyle(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.normal,
                              fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: NeuTheme.sm(radius: 12),
                      alignment: Alignment.center,
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () async {
                      final amount = controller.text.trim();
                      if (amount.isEmpty) return;
                      Navigator.pop(ctx);
                      await _sendCounterOffer(offer, amount);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text('Send',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCounterOffer(BookingModel offer, String amount) async {
    final bookingProvider = context.read<BookingProvider>();
    final ok = await bookingProvider.counterOffer(offer.id, amount);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Offer of Rs. $amount sent to ${offer.providerName}'),
            backgroundColor: AppColors.success),
      );
      _fetchInitialOffers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                bookingProvider.errorMessage ?? 'Could not send offer'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _declineOffer(BookingModel offer) async {
    final bookingProvider = context.read<BookingProvider>();
    final ok = await bookingProvider.cancelBooking(offer.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Offer declined'),
            backgroundColor: AppColors.primaryBlue),
      );
      _fetchInitialOffers();
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final hp = Responsive.horizontalPadding(context);

    // Only providers who quoted on THIS job.
    final offers = bookingProvider.bookings
        .where((b) =>
            b.jobPostId == widget.jobId &&
            (b.status.toUpperCase() == 'NEGOTIATING' ||
                b.status.toUpperCase() == 'PENDING'))
        .toList();

    return Scaffold(
      backgroundColor: NeuTheme.bg,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primaryBlue,
        backgroundColor: NeuTheme.bg,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hp, 16, hp, 32),
          children: [
            _jobSummary(),
            const SizedBox(height: 22),
            _sectionHeader(
                'Available Providers', offers.length, AppColors.success),
            const SizedBox(height: 12),
            if (_isLoadingOffers)
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()))
            else if (offers.isEmpty)
              _emptyHint(
                  'Waiting for providers to quote on your job…',
                  Icons.hourglass_empty_rounded)
            else
              ...offers.asMap().entries.map(
                  (e) => _quotedProviderCard(e.value, e.key)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: NeuTheme.bg,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      title: const Text(
        'Finding Providers',
        style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/my-jobs'),
            child: Container(
              width: 36,
              height: 36,
              decoration: NeuTheme.circle(),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 18, color: AppColors.primaryBlue),
            ),
          ),
        ),
      ],
    );
  }

  // ─── WIDGETS ────────────────────────────────────────────────────────────

  Widget _jobSummary() {
    final job = widget.jobData;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.work_history_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job?.title ?? widget.serviceName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(job?.status ?? 'OPEN',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (job?.description != null && job!.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(job.description,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Colors.white70, size: 15),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(job?.location ?? '—',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Text(
                  job?.budget != null
                      ? 'Rs. ${job!.budget!.toInt()}'
                      : 'Negotiable',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    );
  }

  Widget _emptyHint(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: NeuTheme.sm(radius: 16),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: NeuTheme.circle(),
            child: Icon(icon, size: 26, color: AppColors.grey400),
          ),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5)),
        ],
      ),
    );
  }

  /// Card for a provider who has quoted on this job.
  /// Quoted rate on the right; Book + Negotiate below.
  Widget _quotedProviderCard(BookingModel offer, int index) {
    final info = _providerInfo[offer.providerId];
    final waitingOnProvider = offer.lastOfferBy == 'CUSTOMER';
    final providerCountered = offer.lastOfferBy == 'PROVIDER';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showProviderProfile(offer),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: NeuTheme.raised(radius: 18),
        child: Column(
          children: [
            Row(
              children: [
                _neuAvatar(offer.providerName, AppColors.primaryBlue,
                    image: info?.profileImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                            child: Text(offer.providerName,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis)),
                        if (info?.isVerified ?? false) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified_rounded,
                              size: 15, color: AppColors.primaryBlue),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text(
                            (info != null && info.rating > 0)
                                ? info.rating.toStringAsFixed(1)
                                : 'Rating',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                        if (info?.distanceKm != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: AppColors.success),
                          const SizedBox(width: 2),
                          Text(_fmtDistance(info!.distanceKm!),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ]),
                      // Trade + experience were only visible after tapping
                      // into the profile sheet — a customer deciding between
                      // several quotes had to open each one just to compare
                      // who's actually qualified for the job.
                      if ((info?.category.isNotEmpty ?? false) ||
                          (info?.experience ?? 0) > 0) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          if (info?.category.isNotEmpty ?? false) ...[
                            const Icon(Icons.engineering_rounded,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Flexible(
                                child: Text(info!.category,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis)),
                          ],
                          if ((info?.experience ?? 0) > 0) ...[
                            const SizedBox(width: 8),
                            Text('${info!.experience}y exp',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ]),
                      ],
                      if ((info?.bio ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          info!.bio!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
                // Quoted rate — right side
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rs. ${offer.price.toInt()}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark)),
                    const Text('Service Rate',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textTertiary)),
                  ],
                ),
              ],
            ),
            if (waitingOnProvider) ...[
              const SizedBox(height: 10),
              Row(children: [
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Your offer sent — waiting for ${offer.providerName}…',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ],
            if (providerCountered && offer.status.toUpperCase() == 'NEGOTIATING') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                    '${offer.providerName} offered Rs. ${offer.price.toInt()} — accept or negotiate',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => _bookOffer(offer),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 15, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Book',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openNegotiatePopup(offer),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: NeuTheme.sm(radius: 10),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.handshake_rounded,
                              size: 15, color: AppColors.primaryBlue),
                          SizedBox(width: 6),
                          Text('Negotiate',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (providerCountered) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _declineOffer(offer),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: NeuTheme.circle(),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: index * 60))
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  String _fmtDistance(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  /// Provider profile bottom sheet — no chat, no send-request.
  /// Book + Negotiate only. Quoted price shown as "Service Rate".
  void _showProviderProfile(BookingModel offer) {
    final p = _providerInfo[offer.providerId];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: NeuTheme.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBDCADB),
                offset: Offset(0, -6),
                blurRadius: 20),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            _neuAvatar(offer.providerName, AppColors.primaryBlue,
                image: p?.profileImage, size: 56),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(offer.providerName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              if (p?.isVerified ?? false) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded,
                    size: 18, color: AppColors.primaryBlue),
              ],
            ]),
            const SizedBox(height: 4),
            Text(p?.category ?? widget.serviceName,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            Row(
              children: [
                _profileStat(
                    Icons.star_rounded,
                    (p != null && p.rating > 0)
                        ? p.rating.toStringAsFixed(1)
                        : '—',
                    'Rating',
                    AppColors.warning),
                _profileStat(Icons.payments_rounded,
                    'Rs. ${offer.price.toInt()}', 'Service Rate',
                    AppColors.primaryBlue),
                if (p?.distanceKm != null)
                  _profileStat(Icons.location_on_rounded,
                      _fmtDistance(p!.distanceKm!), 'Away', AppColors.success),
                if ((p?.experience ?? 0) > 0)
                  _profileStat(Icons.workspace_premium_rounded,
                      '${p!.experience}y', 'Experience',
                      AppColors.primaryDark),
              ],
            ),
            if ((p?.bio ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('About',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary))),
              const SizedBox(height: 4),
              Text(p?.bio ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4)),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _openNegotiatePopup(offer);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: NeuTheme.sm(radius: 12),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.handshake_rounded,
                              size: 17, color: AppColors.primaryBlue),
                          SizedBox(width: 6),
                          Text('Negotiate',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _bookOffer(offer);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 17, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Book',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: NeuTheme.circle(),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _neuAvatar(String name, Color color,
      {String? image, double size = 48}) {
    if (image != null && image.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: NeuTheme.circle(),
        child: ClipOval(
          child: Image.network(image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _initials(name, size * 0.38, color: color)),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: NeuTheme.circle(),
      child: _initials(name, size * 0.34, color: color),
    );
  }

  Widget _initials(String name, double fontSize, {Color? color}) {
    final initials = name.trim().isNotEmpty
        ? name
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: color ?? AppColors.primaryBlue,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
