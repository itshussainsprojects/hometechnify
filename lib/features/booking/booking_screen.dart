import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:home_technify/features/auth/providers/auth_provider.dart';
import 'package:home_technify/features/booking/providers/booking_provider.dart';
import 'package:home_technify/features/booking/data/models/booking_model.dart';
import 'package:home_technify/features/address/providers/address_provider.dart';
import 'package:home_technify/features/address/data/models/address_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/services/payment_service.dart';
import '../payment/payment_webview_screen.dart';

class BookingScreen extends StatefulWidget {
  final String? providerName;
  final String? serviceName;
  final String? price;
  final bool? negotiated;
  final String? providerId;
  final String? serviceId;

  const BookingScreen({
    super.key,
    this.providerName,
    this.serviceName,
    this.price,
    this.negotiated,
    this.providerId,

    this.serviceId,
    this.initialAddress,
  });

  final String? initialAddress;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedPayment = 'cash';
  String _selectedWallet = 'jazzcash';
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();

  int _servicePrice = 500; // Default price
  final int _platformFee = 50;

  // Current user location address (auto-fetched)
  String _currentAddress = 'Current Location';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    // Parse the negotiated price if provided
    if (widget.price != null && widget.price.toString().isNotEmpty) {
      _servicePrice = int.tryParse(widget.price.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 500;
    }
    
    // Set initial address from GPS if available
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
        _addressController.text = widget.initialAddress!;
    } else {
        // Auto-fetch location if no initial address
        _getCurrentLocation();
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        final addressProvider = context.read<AddressProvider>();
        addressProvider.fetchAddresses(user.id).then((_) {
           // Only use default address if NO GPS address was passed AND controller is empty
           if (mounted && 
               addressProvider.addresses.isNotEmpty && 
               _addressController.text.isEmpty && 
               (widget.initialAddress == null || widget.initialAddress!.isEmpty)) {
             setState(() {
               _addressController.text = addressProvider.addresses.first.address;
             });
           }
        });
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _currentAddress = 'Locating...');
    
    // Check permissions and fetch location similar to HomeScreen
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) setState(() => _currentAddress = 'Location Disabled');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted) setState(() => _currentAddress = 'Permission Denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if(mounted) setState(() => _currentAddress = 'Permission Denied');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _currentPosition = position;
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> parts = [];
        if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);

        final address = parts.join(', ');
        if (mounted) {
          setState(() {
            _currentAddress = address.isNotEmpty ? address : "Lat: ${position.latitude}, Lng: ${position.longitude}";
            if (_addressController.text.isEmpty) {
              _addressController.text = _currentAddress;
            }
          });
        }
      }
    } catch (e) {
      if(mounted) setState(() => _currentAddress = 'Failed to get location');
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text('Book Service', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSection(),
            const SizedBox(height: 24),
            _buildTimeSection(),
            const SizedBox(height: 24),
            _buildAddressSection(),
            const SizedBox(height: 24),
            _buildPaymentSection(),
            const SizedBox(height: 24),
            _buildSummary(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildConfirmButton(horizontalPadding),
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        // Current date display - Clickable
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                 BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildTimeSection() {
    // 12-hour format logic
    final localTime = _selectedTime; 
    final hour = localTime.hourOfPeriod == 0 ? 12 : localTime.hourOfPeriod;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.period == DayPeriod.am ? 'AM' : 'PM';
    final currentTime = '$hour:$minute $period';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _selectTime(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  currentTime,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
         return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: child!,
        );
      }
    );
    if (picked != null && picked != _selectedTime) {
      if (mounted) {
        setState(() {
          _selectedTime = picked;
        });
      }
    }
  }

  Widget _buildAddressSection() {
    return Consumer<AddressProvider>(
      builder: (context, provider, _) {
        final addresses = provider.addresses;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (addresses.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/my-addresses'),
                  child: Text('Manage', style: TextStyle(fontSize: 14, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (addresses.isEmpty)
              GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/my-addresses'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.grey300, style: BorderStyle.solid),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_location_alt_outlined, color: AppColors.primaryBlue),
                          SizedBox(width: 8),
                          Text('Add New Address', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Column(
                  children: [
                    // Always show Current Location Option
                    _buildAddressRadio(_currentAddress, isCurrentLocation: true), 
                    
                    if (addresses.isNotEmpty) ...[
                       const Divider(height: 1),
                       ...addresses.map((addr) => _buildAddressRadio(addr)),
                    ],

                    const Divider(height: 1),
                     _buildCustomAddressInput(),
                  ],
                ),
              ),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
      }
    );
  }

  Widget _buildAddressRadio(dynamic addr, {bool isCurrentLocation = false}) { // Accept AddressModel or String
     final addressText = addr is AddressModel ? addr.address : addr.toString();
     final isSelected = _addressController.text == addressText;
     
     return GestureDetector(
       onTap: () => setState(() => _addressController.text = addressText),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
         decoration: BoxDecoration(
           color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.transparent,
           border: Border(bottom: BorderSide(color: AppColors.grey100)),
         ),
         child: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.grey50,
                 shape: BoxShape.circle,
               ),
               child: Icon(
                 addr is AddressModel 
                     ? (addr.label.toLowerCase().contains('home') ? Icons.home_rounded : 
                        addr.label.toLowerCase().contains('work') ? Icons.work_rounded : Icons.location_on_rounded)
                     : Icons.my_location_rounded, // GPS Icon
                 color: isSelected ? AppColors.primaryBlue : AppColors.grey500,
                 size: 20
               ),
             ),
             const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addr is AddressModel ? addr.label : (isCurrentLocation ? "Current Location" : "Other"), 
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary)
                    ),
                   const SizedBox(height: 2),
                   Text(
                     addr is AddressModel ? addr.address : addr.toString(), 
                     style: TextStyle(fontSize: 13, color: AppColors.textSecondary), 
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis
                   ),
                 ],
               ),
             ),
             if (isSelected) 
               Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 22)
             else
               Container(
                 width: 22, height: 22,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: AppColors.grey300),
                 ),
               ),
           ],
         ),
       ),
     );
  }

  Widget _buildCustomAddressInput() {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _addressController,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'Or enter custom address...',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
              prefixIcon: Icon(Icons.edit_location_alt_outlined, color: AppColors.grey400, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (val) => setState((){}), // Trigger rebuild to update selection UI
          ),
        );
  }

  Widget _buildPaymentSection() {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        
        // Cash on Delivery
        _buildPaymentOption(
          id: 'cash',
          title: 'Cash on Delivery',
          subtitle: 'Pay when service is completed',
          icon: Icons.payments_rounded,
        ),
        const SizedBox(height: 12),
        
        // Wallet
        _buildPaymentOption(
          id: 'wallet',
          title: 'Wallet',
          subtitle: 'Pay via mobile wallet',
          icon: Icons.account_balance_wallet_rounded,
        ),
        
        // Show wallet options when wallet is selected
        if (_selectedPayment == 'wallet') ...[
          const SizedBox(height: 12),
          _buildWalletSubOption('jazzcash', 'JazzCash', Icons.phone_android_rounded, isSmall),
          const SizedBox(height: 10),
          _buildWalletSubOption('easypaisa', 'EasyPaisa', Icons.account_balance_wallet_rounded, isSmall),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
  
  Widget _buildWalletSubOption(String id, String name, IconData icon, bool isSmall) {
    final isSelected = _selectedWallet == id;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedWallet = id),
      child: Container(
        margin: const EdgeInsets.only(left: 20),
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.grey200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.primaryBlue.withValues(alpha: 0.1)
                  : AppColors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isSmall ? 42 : 46,
              height: isSmall ? 42 : 46,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primaryBlue.withValues(alpha: 0.1)
                    : AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon, 
                size: isSmall ? 20 : 22, 
                color: isSelected ? AppColors.primaryBlue : AppColors.grey500,
              ),
            ),
            SizedBox(width: isSmall ? 12 : 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                ),
              ),
            ),
            // Sub-option selection indicator
            _buildSelectionIndicator(isSelected, isSmall),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSelectionIndicator(bool isSelected, bool isSmall) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSmall ? 20 : 22,
      height: isSmall ? 20 : 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : AppColors.grey300,
          width: 2,
        ),
        color: isSelected ? AppColors.primaryBlue : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check_rounded, size: isSmall ? 12 : 14, color: Colors.white)
          : null,
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPayment == id;
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(isSmall ? 16 : 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.08) : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.grey200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.primaryBlue.withValues(alpha: 0.15)
                  : AppColors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 16 : 8,
              offset: Offset(0, isSelected ? 6 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: isSmall ? 52 : 56,
              height: isSmall ? 52 : 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected 
                      ? [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.8)]
                      : [AppColors.primaryBlue.withValues(alpha: 0.15), AppColors.primaryBlue.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primaryBlue,
                size: isSmall ? 24 : 26,
              ),
            ),
            const SizedBox(width: 16),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmall ? 15 : 16,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.8) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Radio button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSmall ? 24 : 26,
              height: isSmall ? 24 : 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : AppColors.grey300,
                  width: 2,
                ),
                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: isSmall ? 14 : 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final total = _servicePrice + _platformFee;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
      child: Column(
        children: [
          if (widget.negotiated == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'Negotiated Price Applied!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          _buildSummaryRow('Service Fee', 'Rs. $_servicePrice'),
          const SizedBox(height: 12),
          _buildSummaryRow('Travelling Fee', 'Rs. $_platformFee'),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          _buildSummaryRow('Total', 'Rs. $total', isTotal: true),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 500.ms);
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500, color: isTotal ? AppColors.textPrimary : AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: FontWeight.w700, color: isTotal ? AppColors.primaryBlue : AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildConfirmButton(double horizontalPadding) {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: EdgeInsets.all(horizontalPadding),
          decoration: BoxDecoration(color: AppColors.white, boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -5))]),
          child: SafeArea(
            child: GestureDetector(
              onTap: provider.isLoading ? null : _handleBooking,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Center(
                  child: provider.isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleBooking() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      SnackBarHelper.showWarning(context, 'Please login to book a service');
      return;
    }

    if (widget.providerId == null || widget.serviceId == null) {
       SnackBarHelper.showError(context, 'Invalid booking data');
       return;
    }

    // Combine Date + Time
    final finalBookingDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final booking = BookingModel(
      id: '', // Backend generates ID
      customerId: user.id,
      providerId: widget.providerId!,
      providerName: widget.providerName ?? 'Provider',
      serviceId: widget.serviceId!,
      serviceName: widget.serviceName ?? 'Service',
      address: _addressController.text.isNotEmpty ? _addressController.text : _currentAddress,
      price: (_servicePrice + _platformFee).toDouble(),
      bookingDate: finalBookingDateTime,
      status: 'pending',
      lat: _currentPosition?.latitude ?? context.read<AddressProvider>().selectedAddress?.lat ?? 0.0,
      lng: _currentPosition?.longitude ?? context.read<AddressProvider>().selectedAddress?.lng ?? 0.0,
      paymentStatus: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create booking first
    final success = await context.read<BookingProvider>().createBooking(booking);

    if (!success) {
      if (mounted) {
        final error = context.read<BookingProvider>().errorMessage ?? 'Booking failed';
        SnackBarHelper.showError(context, error);
      }
      return;
    }

    if (!mounted) return;
    // Get booking ID from provider (assuming it's set after creation)
    final bookingId = context.read<BookingProvider>().lastCreatedBookingId;

    if (bookingId == null || bookingId.isEmpty) {
      SnackBarHelper.showError(context, 'Failed to get booking ID');
      return;
    }

    // Process payment based on selected method
    if (_selectedPayment == 'cash') {
      // Cash on service - No payment gateway needed
      await _processCashPayment(bookingId);
    } else if (_selectedPayment == 'wallet') {
      // Open payment gateway (JazzCash or EasyPaisa)
      await _processWalletPayment(bookingId);
    }
  }

  Future<void> _processCashPayment(String bookingId) async {
    try {
      final paymentService = PaymentService();
      
      // Inform backend about cash payment
      await paymentService.initiatePayment(
        bookingId: bookingId,
        paymentMethod: 'CASH',
      );
      
      if (mounted) {
        // Carry the booking through, or the receipt has nothing real to show.
        Navigator.pushReplacementNamed(context, '/booking-success',
            arguments: {'bookingId': bookingId});
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to process booking: $e');
      }
    }
  }

  Future<void> _processWalletPayment(String bookingId) async {
    try {
      final paymentService = PaymentService();
      final user = context.read<AuthProvider>().user;
      
      // Determine payment method
      final paymentMethod = _selectedWallet == 'jazzcash' ? 'JAZZCASH' : 'EASYPAISA';
      
      // Get payment URL from backend
      final response = await paymentService.initiatePayment(
        bookingId: bookingId,
        paymentMethod: paymentMethod,
        customerPhone: user?.phone,
        customerEmail: user?.email,
      );
      
      if (!response['success']) {
        throw Exception(response['message'] ?? 'Payment initiation failed');
      }
      
      final paymentUrl = response['data']['paymentUrl'];
      final paymentData = response['data']['paymentData'];
      
      // Open WebView for payment
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewScreen(
              paymentUrl: paymentUrl,
              paymentData: paymentData,
              paymentMethod: paymentMethod,
            ),
          ),
        );
        
        // Handle payment result
        if (result != null && result['success'] == true) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/booking-success',
                arguments: {'bookingId': bookingId});
          }
        } else {
          if (mounted) {
            SnackBarHelper.showError(
              context, 
              result?['message'] ?? 'Payment failed'
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Payment error: $e');
      }
    }
  }
}
