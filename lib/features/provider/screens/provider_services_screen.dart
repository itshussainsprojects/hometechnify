import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/services/api_service.dart';
import '../providers/provider_controller.dart';
import '../../auth/providers/auth_provider.dart';

class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // Fetch provider details using auth user ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<ProviderController>().fetchProviderDetails(userId);
      }
    });
  }

  void _updateFieldsFromProvider() {
    final provider = context.read<ProviderController>().selectedProvider;
    if (provider != null) {
      _bioController.text = provider.bio ?? '';
      _experienceController.text = provider.experience.toString();
    }
  }

  bool _fieldsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<ProviderController>().selectedProvider;
    if (provider != null && !_fieldsInitialized) {
      _updateFieldsFromProvider();
      _fieldsInitialized = true;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  /// Was a separate "My Trade" card on the main Profile screen. Merged in
  /// here since both screens showed/edited the same category field one tap
  /// apart in the same "Service" section — this is the single place a
  /// provider sets their trade, bio, experience, and services list.
  Future<void> _showTradePicker() async {
    final controller = context.read<ProviderController>();
    final messenger = ScaffoldMessenger.of(context);

    List<dynamic> categories;
    try {
      final res = await ApiService().dio.get('/categories');
      categories = (res.data['data'] as List?) ?? [];
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not load the trade list: $e'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (!mounted) return;

    if (categories.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No trades are available yet. Please contact support.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    final current = controller.selectedProvider?.category;

    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Choose your trade',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'You will only be shown jobs in this trade.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 16),
              ...categories.map((c) {
                final name = (c['name'] ?? '') as String;
                final isCurrent = name == current;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isCurrent
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isCurrent ? AppColors.primaryBlue : AppColors.grey300,
                  ),
                  title: Text(name,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      )),
                  onTap: () => Navigator.pop(context, c as Map<String, dynamic>),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    final name = chosen['name'] as String;
    if (name == current) return;

    final ok = await controller.updateProfile({'service_category_id': chosen['id']});
    if (!mounted) return;

    if (ok) {
      final me = context.read<AuthProvider>().user;
      if (me != null) await controller.fetchProviderDetails(me.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Your trade is now $name — you will receive $name jobs.'),
        backgroundColor: AppColors.success,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(controller.errorMessage ?? 'Could not update your trade'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _saveChanges() async {
    // Pricing is negotiation-based (per-job quotes), so no hourly rate here.
    final success = await context.read<ProviderController>().updateProfile({
      'bio': _bioController.text,
      'experience': _experienceController.text,
    });

    if (success && mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service details updated successfully!'), backgroundColor: AppColors.success),
      );
      // Refresh details
      final userId = context.read<ProviderController>().selectedProvider?.id;
      if (userId != null) {
        context.read<ProviderController>().fetchProviderDetails(userId);
      }
    } else if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update details'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerController = context.watch<ProviderController>();
    final provider = providerController.selectedProvider;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF4),
      appBar: AppBar(
        title: const Text('My Trade & Services', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded, color: AppColors.primaryBlue),
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Trade / Category Card — tap to change. This is the one place
            // that edits service_category_id; the main Profile screen only
            // shows a read-only summary of the same field, not a second editor.
            GestureDetector(
              onTap: _showTradePicker,
              child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.category_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Trade — tap to change',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider?.category ?? 'Loading...',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ],
              ),
              ),
            ).animate().slideY(begin: 0.1, duration: 400.ms),

            const SizedBox(height: 24),


            const SizedBox(height: 16),

            _buildInfoCard(
              title: 'Experience (Years)', // simplified
              icon: Icons.work_history_outlined,
              child: TextField(
                controller: _experienceController,
                enabled: _isEditing,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. 5 Years',
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildInfoCard(
              title: 'Bio / Description',
              icon: Icons.description_outlined,
              child: TextField(
                controller: _bioController,
                enabled: _isEditing,
                maxLines: 4,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Tell customers about your expertise...',
                ),
              ),
            ),
            
            if (providerController.isLoading)
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator())
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }
}
