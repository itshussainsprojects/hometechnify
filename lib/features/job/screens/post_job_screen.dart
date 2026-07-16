// Post Job Screen - User posts job with video/image/voice/message
// Premium design with brand colors and full responsiveness

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../providers/job_post_provider.dart';
import '../../address/providers/address_provider.dart';
import '../../address/data/models/address_model.dart';

class PostJobScreen extends StatefulWidget {
  final String serviceName;
  final String serviceId;
  final IconData serviceIcon;
  final Color serviceColor;

  const PostJobScreen({
    super.key,
    required this.serviceName,
    required this.serviceId,
    required this.serviceIcon,
    required this.serviceColor,
  });

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _descriptionController = TextEditingController();
  String _selectedMediaType = '';
  String? _mediaPath;
  bool _isPosting = false;
  // Audio Recording
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedPath;
  
  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    
    _audioPlayer.onPlayerComplete.listen((event) {
      if(mounted) setState(() => _isPlaying = false);
    });

    // Fetch addresses on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user; // PostJobScreen needs AuthProvider imported?
      // It might be available via context if imported in main, but better to import it here too to be safe/clean
      // Or just rely on AddressProvider if it knows the user ID... wait, AddressProvider.fetchAddresses needs ID.
      if (user != null) {
         context.read<AddressProvider>().fetchAddresses(user.id);
      }
    });
  }

  final List<MediaOption> _mediaOptions = [
    MediaOption(
      type: 'video',
      icon: Icons.videocam_rounded,
      label: 'Video',
      description: 'Record or upload video',
      color: const Color(0xFFE91E63),
    ),
    MediaOption(
      type: 'image',
      icon: Icons.photo_camera_rounded,
      label: 'Image',
      description: 'Take or upload photo',
      color: const Color(0xFF2196F3),
    ),
    MediaOption(
      type: 'voice',
      icon: Icons.mic_rounded,
      label: 'Voice',
      description: 'Record voice message',
      color: const Color(0xFF9C27B0),
    ),
    MediaOption(
      type: 'text',
      icon: Icons.message_rounded,
      label: 'Message',
      description: 'Type your description',
      color: const Color(0xFF4CAF50),
    ),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _selectMediaType(String type) {
    debugPrint("[PostJobScreen] === _selectMediaType CALLED with type: $type ===");
    
    setState(() {
      _selectedMediaType = type;
      _mediaPath = null;
    });
    
    if (type == 'video') {
      debugPrint("[PostJobScreen] Opening VIDEO picker...");
      _showMediaPicker(isVideo: true);
    } else if (type == 'image') {
      debugPrint("[PostJobScreen] Opening IMAGE picker...");
      _showMediaPicker(isVideo: false);
    } else if (type == 'voice') {
      debugPrint("[PostJobScreen] Opening VOICE recorder...");
      _showVoiceRecorder();
    } else if (type == 'text') {
      debugPrint("[PostJobScreen] TEXT selected - showing description field");
    }
  }

  Future<void> _pickMedia({required bool isVideo, required bool isCamera}) async {
    Navigator.pop(context); // Close bottom sheet FIRST
    
    debugPrint("[PostJobScreen] _pickMedia called: isVideo=$isVideo, isCamera=$isCamera");
    
    // NOTE: ImagePicker handles permissions internally on modern Android (10+)
    // We don't need to manually request permissions - it will prompt the user automatically
    // This avoids conflicts with Geolocator's location permission request
    
    try {
      final picker = ImagePicker();
      debugPrint("[PostJobScreen] Launching picker...");
      
      final XFile? file = isVideo 
          ? await picker.pickVideo(source: isCamera ? ImageSource.camera : ImageSource.gallery)
          : await picker.pickImage(source: isCamera ? ImageSource.camera : ImageSource.gallery);
      
      debugPrint("[PostJobScreen] Picker returned: ${file?.path ?? 'NULL/CANCELLED'}");
      
      if (file != null) {
        setState(() {
          _mediaPath = file.path;
        });
        debugPrint("[PostJobScreen] SUCCESS! _mediaPath set to: $_mediaPath");
        if (mounted) SnackBarHelper.showSuccess(context, 'Media selected!');
      } else {
        debugPrint("[PostJobScreen] User cancelled picker or no file selected");
      }
    } on PlatformException catch (e) {
      debugPrint("[PostJobScreen] PlatformException: ${e.code} - ${e.message}");
      if (e.code == 'photo_access_denied' || e.code == 'camera_access_denied') {
        // Permission was denied - show dialog to open settings
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Permission Required"),
              content: Text("Please enable ${isCamera ? 'camera' : 'gallery'} access in App Settings."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                TextButton(onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                }, child: const Text("Open Settings")),
              ],
            ),
          );
        }
      } else {
        if (mounted) SnackBarHelper.showError(context, 'Error: ${e.message}');
      }
    } catch (e) {
      debugPrint("[PostJobScreen] Picker ERROR: $e");
      if (mounted) SnackBarHelper.showError(context, 'Failed to pick media: $e');
    }
  }

  void _showMediaPicker({required bool isVideo}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isVideo ? 'Add Video' : 'Add Photo',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickMedia(isVideo: isVideo, isCamera: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickMedia(isVideo: isVideo, isCamera: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Voice Recording Logic ---

  Future<void> _startRecording(StateSetter setModalState) async {
    try {
      // Explicitly request permission if not granted
      if (!await _audioRecorder.hasPermission()) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          if(mounted) SnackBarHelper.showError(context, "Microphone permission required");
          return;
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(const RecordConfig(), path: path);
      setModalState(() {
        _isRecording = true;
        _recordedPath = path;
      });
      
    } catch (e) {
      debugPrint(e.toString());
      if(mounted) SnackBarHelper.showError(context, "Failed to start recording");
    }
  }

  Future<void> _stopRecording(StateSetter setModalState) async {
    try {
      final path = await _audioRecorder.stop();
      debugPrint("Recording stopped, saved to: $path");
      setModalState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    } catch (e) {
      debugPrint("Stop recording error: $e");
    }
  }

  void _showVoiceRecorder() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isRecording ? 'Recording...' : 'Record Voice Message',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _isRecording ? Colors.red : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Visual Indicator
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: _isRecording ? Colors.red : AppColors.grey400,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                 if (_recordedPath != null && !_isRecording) ...[
                   Text(
                    'Recorded!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                   ),
                   const SizedBox(height: 4),
                   Text(
                    _recordedPath!.split('/').last, 
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                   ),
                 ],

                const Spacer(),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Close/Cancel
                    GestureDetector(
                      onTap: () {
                         if(_isRecording) _stopRecording(setModalState);
                         Navigator.pop(context);
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.grey200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 28),
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Record / Stop Button
                    GestureDetector(
                      onTap: () {
                        if (_isRecording) {
                          _stopRecording(setModalState);
                        } else {
                          _startRecording(setModalState);
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? Colors.red : AppColors.primaryBlue).withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 36
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Confirm Button
                    GestureDetector(
                      onTap: () {
                        if (_isRecording) _stopRecording(setModalState);
                        
                        if (_recordedPath != null) {
                          setState(() => _mediaPath = _recordedPath);
                          Navigator.pop(context); 
                        } else {
                          SnackBarHelper.showError(context, "Please record something first");
                        }
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _recordedPath != null ? const Color(0xFF4CAF50) : AppColors.grey300,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  Future<void> _postJob() async {
    if (_descriptionController.text.isEmpty && _selectedMediaType != 'voice' && _selectedMediaType != 'image' && _selectedMediaType != 'video') {
       // Allow description to be empty if just sending media? No, description is required field in backend usually.
       // Let's enforce description OR make backend allow empty description if media present?
       // Backend logic (jobController.js) likely requires description.
    }

    if ((_descriptionController.text.isEmpty && _selectedMediaType == 'text') ||
        (_descriptionController.text.isEmpty && _selectedMediaType.isEmpty)) {
      SnackBarHelper.showError(context, 'Please add a description');
      return;
    }
    
    // If media type selected but no file
    if (_selectedMediaType != 'text' && _selectedMediaType.isNotEmpty && _mediaPath == null) {
       SnackBarHelper.showError(context, 'Please select/record media');
       return;
    }

    setState(() => _isPosting = true);
    
    // Ensure description is not empty if backend needs it (send "Voice Note" if voice only?)
    String description = _descriptionController.text;
    if (description.isEmpty && _selectedMediaType != 'text') {
      description = "${_selectedMediaType.toUpperCase()} Upload";
    }

    // Get location from address provider
    final addressProvider = context.read<AddressProvider>();
    final selectedAddress = addressProvider.selectedAddress;
    final locationToUse = selectedAddress != null 
        ? selectedAddress.address 
        : "Current Location";

    if (selectedAddress == null) {
       if (mounted) {
         SnackBarHelper.showWarning(context, "Please select a location");
       }
       setState(() => _isPosting = false);
       return;
    }

    final success = await context.read<JobPostProvider>().createJob(
      widget.serviceName, 
      description, 
      locationToUse, 
      null, // Budget optional
      _mediaPath != null ? [_mediaPath!] : [],
      category: widget.serviceName,
      lat: selectedAddress.lat,
      lng: selectedAddress.lng,
    );


    if (mounted) {
       setState(() => _isPosting = false);
       if (success) {
         SnackBarHelper.showSuccess(context, 'Job Posted Successfully!');
         
         // Get the newly created job (it's at index 0)
         final newJob = context.read<JobPostProvider>().myJobs.first;
         
         // Navigate to Finding Providers Screen
         Navigator.pushReplacementNamed(
           context, 
           '/finding-providers',
           arguments: {
             'jobId': newJob.id,
             'serviceName': widget.serviceName,
             'serviceId': widget.serviceId,
           }
         );
       } else {
         final error = context.read<JobPostProvider>().errorMessage ?? 'Failed to post';
         SnackBarHelper.showError(context, error);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Allow keyboard push
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.serviceColor.withValues(alpha: 0.08),
              Colors.white,
              AppColors.primaryBlue.withValues(alpha: 0.03),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(horizontalPadding, isSmall),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: isSmall ? 16 : 24),
                      _buildServiceHeader(isSmall),
                      SizedBox(height: isSmall ? 20 : 28),
                      _buildLocationSection(isSmall),
                      SizedBox(height: isSmall ? 20 : 28),
                      _buildMediaOptions(isSmall),
                      
                      // Show description field only for Video and Image 
                      if (_selectedMediaType == 'video' || _selectedMediaType == 'image') ...[
                        SizedBox(height: isSmall ? 20 : 28),
                        _buildDescriptionField(isSmall),
                      ],
                      // Show text input for Message tab
                      if (_selectedMediaType == 'text') ...[
                        SizedBox(height: isSmall ? 20 : 28),
                        _buildDescriptionField(isSmall),
                      ],
                      if (_mediaPath != null) ...[
                        SizedBox(height: isSmall ? 16 : 20),
                        _buildMediaPreview(isSmall),
                      ],
                      // If Voice, show instruction or player
                      if (_selectedMediaType == 'voice' && _mediaPath == null)
                         Padding(
                           padding: EdgeInsets.only(top: 20),
                           child: Text("Tap Voice above to record", style: TextStyle(color: AppColors.textSecondary)),
                         ),

                      SizedBox(height: isSmall ? 24 : 32),
                      _buildPostButton(isSmall),
                      SizedBox(height: isSmall ? 20 : 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(double horizontalPadding, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isSmall ? 12 : 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isSmall ? 44 : 48,
              height: isSmall ? 44 : 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grey200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: isSmall ? 20 : 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Post a Job',
              style: TextStyle(
                fontSize: isSmall ? 20 : 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildServiceHeader(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmall ? 56 : 64,
            height: isSmall ? 56 : 64,
            decoration: BoxDecoration(
              color: widget.serviceColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(widget.serviceIcon, color: widget.serviceColor, size: isSmall ? 28 : 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.serviceName,
                  style: TextStyle(
                    fontSize: isSmall ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Describe your job requirement',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildLocationSection(bool isSmall) {
    return Consumer<AddressProvider>(
      builder: (context, provider, _) {
        final selectedAddress = provider.selectedAddress;
        final displayAddress = selectedAddress != null 
            ? "${selectedAddress.label} (${selectedAddress.address})"
            : "Select Location"; 

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job Location',
              style: TextStyle(
                fontSize: isSmall ? 15 : 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.pushNamed(context, '/location-picker');
                if (result != null && result is String) {
                   // Update provider with selected address
                   // We need to parse or just set it. 
                   // AddressProvider expects AddressModel usually, but here we might just need to select it?
                   // Ideally LocationPicker returns an AddressModel, but it currently returns String.
                   // Let's create a temporary AddressModel or just use the string text if the provider supports it.
                   // Actually, AddressProvider.selectAddress takes an AddressModel.
                   // We should update AddressProvider to allow "manual" selection string, or create a dummy model.
                   
                   final parts = result.split(',');
                   final label = parts.isNotEmpty ? parts.first : "Custom Location";
                   
                   final tempAddress = AddressModel(
                     id: "temp_${DateTime.now().millisecondsSinceEpoch}",
                     userId: "temp",
                     label: label,
                     address: result,
                     lat: 0,
                     lng: 0,
                     createdAt: DateTime.now(),
                   );
                   
                   provider.selectAddress(tempAddress);
                }
              },
              child: Container(
                padding: EdgeInsets.all(isSmall ? 14 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isSmall ? 40 : 44,
                      height: isSmall ? 40 : 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.location_on_rounded, color: Colors.white, size: isSmall ? 20 : 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayAddress,
                        style: TextStyle(
                          fontSize: isSmall ? 14 : 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.edit_rounded, color: AppColors.primaryBlue, size: isSmall ? 20 : 22),
                  ],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
      }
    );
  }

  Widget _buildMediaOptions(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose how to describe your job',
          style: TextStyle(
            fontSize: isSmall ? 15 : 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isSmall ? 1.4 : 1.3,
          ),
          itemCount: _mediaOptions.length,
          itemBuilder: (context, index) {
            final option = _mediaOptions[index];
            final isSelected = _selectedMediaType == option.type;
            
            return GestureDetector(
              behavior: HitTestBehavior.opaque, // Ensure taps aren't absorbed by children
              onTap: () {
                debugPrint("[PostJobScreen] >>> BUTTON TAPPED: ${option.type} <<<");
                _selectMediaType(option.type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                decoration: BoxDecoration(
                  color: isSelected ? option.color.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? option.color : AppColors.grey200,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: option.color.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: isSmall ? 44 : 52,
                      height: isSmall ? 44 : 52,
                      decoration: BoxDecoration(
                        color: isSelected ? option.color : option.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        option.icon,
                        color: isSelected ? Colors.white : option.color,
                        size: isSmall ? 24 : 28,
                      ),
                    ),
                    SizedBox(height: isSmall ? 8 : 10),
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: isSmall ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? option.color : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 200 + index * 50));
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Details',
          style: TextStyle(
            fontSize: isSmall ? 15 : 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 4,
            style: TextStyle(
              fontSize: isSmall ? 14 : 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Describe your problem in detail...',
              hintStyle: TextStyle(
                color: AppColors.textHint,
                fontSize: isSmall ? 14 : 15,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _buildMediaPreview(bool isSmall) {
    if (_mediaPath == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey50, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 '${_selectedMediaType.toUpperCase()} ATTACHMENT',
                 style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
               ),
               GestureDetector(
                onTap: () => setState(() {
                  _mediaPath = null;
                  _selectedMediaType = '';
                  // Also stop player if playing
                }),
                child: const Icon(Icons.close_rounded, color: AppColors.grey500, size: 20),
              ),
             ],
           ),
           const SizedBox(height: 12),
           
           if (_selectedMediaType == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_mediaPath!),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (c,e,s) => Container(
                    height: 200, color: Colors.grey[200], 
                    child: Center(child: Text("Error loading image: $e", textAlign: TextAlign.center))
                  ),
                ),
              )
           else if (_selectedMediaType == 'video')
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text("Video Attached\n${_mediaPath!.split('/').last}", 
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white))
                    ],
                  )
                ),
              ) // Todo: Implement VideoPlayerController if needed, but icon proves file exists
           else if (_selectedMediaType == 'voice')
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                         if(_isPlaying) {
                           await _audioPlayer.pause();
                           setState(() => _isPlaying = false);
                         } else {
                           await _audioPlayer.play(DeviceFileSource(_mediaPath!));
                           setState(() => _isPlaying = true);
                         }
                      },
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                        child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Voice Recording", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                          Text(_mediaPath!.split('/').last, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPostButton(bool isSmall) {
    return GestureDetector(
      onTap: _isPosting ? null : _postJob,
      child: Container(
        width: double.infinity,
        height: isSmall ? 54 : 60,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: _isPosting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Find Providers',
                      style: TextStyle(
                        fontSize: isSmall ? 16 : 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 450.ms).slideY(begin: 0.15, end: 0);
  }
}

class MediaOption {
  final String type;
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  MediaOption({
    required this.type,
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });
}
