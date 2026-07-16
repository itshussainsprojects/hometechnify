import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/constants.dart';
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
  final _serviceInputController = TextEditingController(); // To add new service
  List<String> _services = [];
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
      _services = List.from(provider.services);
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
    _serviceInputController.dispose();
    super.dispose();
  }

  void _addService() {
    final text = _serviceInputController.text.trim();
    if (text.isNotEmpty && !_services.contains(text)) {
      setState(() {
        _services.add(text);
        _serviceInputController.clear();
      });
    }
  }

  void _removeService(String service) {
    setState(() {
      _services.remove(service);
    });
  }

  Future<void> _saveChanges() async {
    // Pricing is negotiation-based (per-job quotes), so no hourly rate here.
    final success = await context.read<ProviderController>().updateProfile({
      'bio': _bioController.text,
      'experience': _experienceController.text,
      'services': _services,
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
        title: const Text('My Services', style: TextStyle(fontWeight: FontWeight.bold)),
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
            // Category Card
            Container(
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
                          'Active Category',
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
                ],
              ),
            ).animate().slideY(begin: 0.1, duration: 400.ms),

            const SizedBox(height: 24),
            
            // Services List
            _buildInfoCard(
              title: 'Services Provided', 
              icon: Icons.list_alt_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_services.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No specific services listed.', style: TextStyle(color: AppColors.textTertiary)),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _services.map((service) => Chip(
                      label: Text(service, style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                      deleteIcon: _isEditing ? const Icon(Icons.close_rounded, size: 16, color: AppColors.primaryBlue) : null,
                      onDeleted: _isEditing ? () => _removeService(service) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                    )).toList(),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _serviceInputController,
                            decoration: const InputDecoration(
                              hintText: 'Add service (e.g. AC Cleaning)',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addService, 
                          icon: const Icon(Icons.add_circle_rounded, color: AppColors.primaryBlue),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
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
