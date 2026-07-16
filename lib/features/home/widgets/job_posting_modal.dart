// Job Posting Modal - Video, Image, Message, Voice options

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../../../core/constants/constants.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/services/video_compressor.dart';
import '../../job/providers/job_post_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class JobPostingModal extends StatefulWidget {
  final String serviceName;
  final String serviceId;
  final IconData? serviceIcon;
  final String? serviceIconUrl;
  final Color serviceColor;

  const JobPostingModal({
    super.key,
    required this.serviceName,
    required this.serviceId,
    this.serviceIcon,
    this.serviceIconUrl,
    required this.serviceColor,
  });

  @override
  State<JobPostingModal> createState() => _JobPostingModalState();
}

class _JobPostingModalState extends State<JobPostingModal> {
  String _selectedOption = 'Video'; // Default to Video
  bool _isRecording = false;
  bool _hasContent = false;
  final _messageController = TextEditingController();
  
  // REAL media handling
  String? _mediaPath;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  @override
  void dispose() {
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _clearContent() {
    setState(() {
      _hasContent = false;
      _isRecording = false;
      _mediaPath = null;
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    
    return Container(
      height: size.height * (isSmall ? 0.75 : 0.65),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(isSmall),
          _buildOptionTabs(isSmall),
          Expanded(child: _buildContent(isSmall)),
          _buildPostButton(isSmall),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildHeader(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [widget.serviceColor, widget.serviceColor.withValues(alpha: 0.8)]),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: widget.serviceIconUrl != null
                ? Image.network(
                    widget.serviceIconUrl!,
                    width: isSmall ? 20 : 24,
                    height: isSmall ? 20 : 24,
                    color: Colors.white,
                    errorBuilder: (context, error, stack) => Icon(widget.serviceIcon ?? Icons.work, color: Colors.white, size: isSmall ? 20 : 24),
                  )
                : Icon(widget.serviceIcon ?? Icons.work, color: Colors.white, size: isSmall ? 20 : 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Post Job - ${widget.serviceName}',
              style: TextStyle(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.close_rounded, color: Colors.white, size: isSmall ? 18 : 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTabs(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Row(
        children: [
          _buildTab('Video', Icons.videocam_rounded, AppColors.primaryBlue, isSmall),
          SizedBox(width: isSmall ? 6 : 8),
          _buildTab('Image', Icons.image_rounded, AppColors.primaryBlue, isSmall),
          SizedBox(width: isSmall ? 6 : 8),
          _buildTab('Message', Icons.message_rounded, AppColors.primaryBlue, isSmall),
          SizedBox(width: isSmall ? 6 : 8),
          _buildTab('Voice', Icons.mic_rounded, AppColors.primaryBlue, isSmall),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, Color color, bool isSmall) {
    final isSelected = _selectedOption == label;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedOption = label;
            _clearContent();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: isSmall ? 20 : 24, color: isSelected ? Colors.white : color),
              SizedBox(height: isSmall ? 2 : 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmall ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Column(
        children: [
          if (_selectedOption == 'Video') _buildVideoContent(isSmall),
          if (_selectedOption == 'Image') _buildImageContent(isSmall),
          if (_selectedOption == 'Message') _buildMessageContent(isSmall),
          if (_selectedOption == 'Voice') _buildVoiceContent(isSmall),
        ],
      ),
    );
  }

  // ============ REAL MEDIA FUNCTIONS ============

  Future<void> _pickImage({bool fromCamera = false}) async {
    debugPrint("[JobPostingModal] _pickImage called (fromCamera: $fromCamera)");
    Navigator.pop(context); // Close the selection bottom sheet
    
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
      );
      
      debugPrint("[JobPostingModal] Image picked: ${file?.path ?? 'None'}");
      
      if (file != null) {
        setState(() {
          _mediaPath = file.path;
          _hasContent = true;
        });
        if (mounted) SnackBarHelper.showSuccess(context, 'Image selected!');
      }
    } on PlatformException catch (e) {
      debugPrint("[JobPostingModal] PlatformException: ${e.code}");
      if (mounted) SnackBarHelper.showError(context, 'Permission denied. Enable in Settings.');
    } catch (e) {
      debugPrint("[JobPostingModal] Error: $e");
      if (mounted) SnackBarHelper.showError(context, 'Failed to pick image: $e');
    }
  }

  Future<void> _pickVideo({bool fromCamera = false}) async {
    debugPrint("[JobPostingModal] _pickVideo called (fromCamera: $fromCamera)");
    
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      
      debugPrint("[JobPostingModal] Video picked: ${file?.path ?? 'None'}");

      if (file != null) {
        setState(() { _isRecording = false; });
        if (mounted) SnackBarHelper.showInfo(context, 'Optimizing video…');
        // Compress on-device before it ever gets uploaded
        final compressedPath = await VideoCompressor.compress(file.path);
        if (!mounted) return;
        setState(() {
          _mediaPath = compressedPath;
          _hasContent = true;
        });
        SnackBarHelper.showSuccess(context, 'Video ready!');
      }
    } on PlatformException catch (e) {
      debugPrint("[JobPostingModal] PlatformException: ${e.code}");
      if (mounted) SnackBarHelper.showError(context, 'Permission denied. Enable in Settings.');
    } catch (e) {
      debugPrint("[JobPostingModal] Error: $e");
      if (mounted) SnackBarHelper.showError(context, 'Failed to pick video: $e');
    }
  }

  Future<void> _startVoiceRecording() async {
    debugPrint("[JobPostingModal] _startVoiceRecording called");
    
    if (_isRecording) {
      // Stop recording
      final path = await _audioRecorder.stop();
      debugPrint("[JobPostingModal] Recording stopped: $path");
      if (path != null) {
        setState(() {
          _isRecording = false;
          _mediaPath = path;
          _hasContent = true;
        });
        if (mounted) SnackBarHelper.showSuccess(context, 'Voice recorded!');
      }
      return;
    }
    
    // Request microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) SnackBarHelper.showError(context, 'Microphone permission denied');
      return;
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
      debugPrint("[JobPostingModal] Recording started at: $path");
    } catch (e) {
      debugPrint("[JobPostingModal] Recording error: $e");
      if (mounted) SnackBarHelper.showError(context, 'Failed to start recording: $e');
    }
  }

  Future<void> _playVoiceRecording() async {
    if (_mediaPath == null) return;
    
    if (_isPlayingAudio) {
      await _audioPlayer.pause();
      setState(() => _isPlayingAudio = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_mediaPath!));
      setState(() => _isPlayingAudio = true);
    }
  }

  // ============ LOCATION HANDLING ============
  // Returns the human-readable address plus the GPS coordinates, so the
  // job post (and later the booking/provider map) gets the real spot.
  Future<({String address, double? lat, double? lng})> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (address: 'Location Disabled', lat: null, lng: null);
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return (address: 'Permission Denied', lat: null, lng: null);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return (address: 'Permission Denied', lat: null, lng: null);
    }

    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> parts = [];
        if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) parts.add(place.administrativeArea!);

        return (address: parts.join(', '), lat: position.latitude, lng: position.longitude);
      }
      return (address: "Lat: ${position.latitude}, Lng: ${position.longitude}", lat: position.latitude, lng: position.longitude);
    } catch (e) {
      debugPrint("Location Error: $e");
      return (address: 'Unknown Location', lat: null, lng: null);
    }
  }

  // ============ POST JOB TO BACKEND ============
  Future<void> _postJob() async {
    if (!_hasContent) return;
    
    debugPrint("[JobPostingModal] _postJob called");
    
    final jobProvider = context.read<JobPostProvider>();
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Get Location
      final location = await _getCurrentLocation();
      debugPrint("[JobPostingModal] Fetched Location: ${location.address} (${location.lat}, ${location.lng})");

      // Create job via provider
      final mediaPaths = _mediaPath != null ? [_mediaPath!] : <String>[];
      final success = await jobProvider.createJob(
        widget.serviceName,  // title
        _messageController.text.isNotEmpty
            ? _messageController.text
            : 'Job request for ${widget.serviceName} ($_selectedOption)',  // description
        location.address,  // Actual address
        null,  // no budget — providers quote & the two negotiate
        mediaPaths,  // media files
        serviceId: widget.serviceId, // backend resolves the real category
        lat: location.lat,
        lng: location.lng,
      );
      
      // Close loading
      if (mounted) Navigator.pop(context);
      
      if (success && mounted) {
        // Close modal and navigate to provider map
        // Close modal and navigate to finding providers screen
        Navigator.pop(context);
        SnackBarHelper.showSuccess(context, 'Job posted successfully!');
        
        // Get the newly created job (inserted at the top of the list)
        final newJob = jobProvider.myJobs.first;

        // Go to the REAL provider/offers screen (real data), NOT the fake
        // simulated provider-map. serviceId uses the job category so the
        // backend can match relevant providers.
        Navigator.pushReplacementNamed(context, '/finding-providers', arguments: {
          'jobId': newJob.id,
          'serviceName': widget.serviceName,
          'serviceId': newJob.category ?? widget.serviceId,
          'jobData': newJob,
        });
      } else {
        if (mounted) {
          SnackBarHelper.showError(context, jobProvider.errorMessage ?? 'Failed to post job');
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);  // Close loading
      debugPrint("[JobPostingModal] Error posting job: $e");
      if (mounted) SnackBarHelper.showError(context, 'Error: $e');
    }
  }

  Widget _buildVideoContent(bool isSmall) {
    return Column(
      children: [
        if (!_hasContent)
          Container(
            height: isSmall ? 220 : 250,
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Camera icon
                  Container(
                    width: isSmall ? 80 : 100,
                    height: isSmall ? 60 : 75,
                    decoration: BoxDecoration(
                      color: AppColors.grey300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Camera body
                        Positioned(
                          left: isSmall ? 15 : 20,
                          top: isSmall ? 15 : 20,
                          child: Container(
                            width: isSmall ? 40 : 45,
                            height: isSmall ? 30 : 35,
                            decoration: BoxDecoration(
                              color: AppColors.grey400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        // Camera lens
                        Positioned(
                          right: isSmall ? 12 : 15,
                          top: isSmall ? 20 : 25,
                          child: Container(
                            width: isSmall ? 15 : 18,
                            height: isSmall ? 20 : 25,
                            decoration: BoxDecoration(
                              color: AppColors.grey400,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmall ? 20 : 24),
                  // Text
                  Text(
                    _isRecording ? 'Recording video...' : 'Record or upload a video',
                    style: TextStyle(
                      fontSize: isSmall ? 15 : 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isSmall ? 20 : 24),
                  // Button - REAL VIDEO PICKER
                  GestureDetector(
                    onTap: () {
                      // Show bottom sheet with camera/gallery options
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(height: 20),
                              const Text('Select Video', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 20),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.videocam_rounded, color: AppColors.error),
                                ),
                                title: const Text('Record Video'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickVideo(fromCamera: true);
                                },
                              ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.video_library_rounded, color: AppColors.primaryBlue),
                                ),
                                title: const Text('Choose from Gallery'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickVideo(fromCamera: false);
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: isSmall ? 180 : 200,
                      height: isSmall ? 48 : 52,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppColors.error : AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? AppColors.error : AppColors.primaryBlue).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isRecording ? 'Stop Recording' : 'Start Recording',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: isSmall ? 14 : 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: isSmall ? 160 : 180,
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        // REAL VIDEO - Show icon with file info
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_rounded, size: isSmall ? 50 : 60, color: AppColors.grey400),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _mediaPath != null ? _mediaPath!.split('/').last : 'video.mp4',
                                  style: TextStyle(color: Colors.white70, fontSize: isSmall ? 11 : 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Play button overlay - NOW FUNCTIONAL
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              if (_mediaPath != null) {
                                debugPrint("[JobPostingModal] Playing video: $_mediaPath");
                                OpenFilex.open(_mediaPath!);
                              }
                            },
                            child: Container(
                              width: isSmall ? 48 : 56,
                              height: isSmall ? 48 : 56,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.5), blurRadius: 16)],
                              ),
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: isSmall ? 28 : 32),
                            ),
                          ),
                        ),
                        // Ready badge
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: isSmall ? 12 : 14),
                                const SizedBox(width: 4),
                                Text('Video Ready', style: TextStyle(color: Colors.white, fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: _clearContent,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.3), blurRadius: 8)]),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              // Description field after video
              SizedBox(height: isSmall ? 12 : 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: 3,
                  style: TextStyle(fontSize: isSmall ? 13 : 14),
                  decoration: InputDecoration(
                    hintText: 'Add description (optional)...',
                    hintStyle: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.grey400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(isSmall ? 12 : 14),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue, size: isSmall ? 20 : 22),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: isSmall ? 36 : 40),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildImageContent(bool isSmall) {
    return Column(
      children: [
        if (!_hasContent)
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 20),
                        const Text('Select Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 20),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.camera_alt_rounded, color: AppColors.error),
                          ),
                          title: const Text('Take Photo'),
                          onTap: () => _pickImage(fromCamera: true),
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.photo_library_rounded, color: AppColors.primaryBlue),
                          ),
                          title: const Text('Choose from Gallery'),
                          onTap: () => _pickImage(fromCamera: false),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Container(
              height: isSmall ? 220 : 250,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, size: isSmall ? 70 : 80, color: AppColors.grey300),
                    SizedBox(height: isSmall ? 20 : 24),
                    Text('Tap to upload images', style: TextStyle(fontSize: isSmall ? 15 : 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    SizedBox(height: isSmall ? 20 : 24),
                    Container(
                      width: isSmall ? 180 : 200,
                      height: isSmall ? 48 : 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Center(
                        child: Text('Choose Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isSmall ? 14 : 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              Stack(
                children: [
                  // REAL IMAGE - Show actual captured image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _mediaPath != null
                        ? Image.file(
                            File(_mediaPath!),
                            height: isSmall ? 160 : 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              height: isSmall ? 160 : 180,
                              color: AppColors.grey200,
                              child: Center(child: Icon(Icons.broken_image_rounded, size: isSmall ? 50 : 56, color: AppColors.grey500)),
                            ),
                          )
                        : Container(
                            height: isSmall ? 160 : 180,
                            color: AppColors.grey200,
                            child: Center(child: Icon(Icons.image_rounded, size: isSmall ? 50 : 56, color: AppColors.grey500)),
                          ),
                  ),
                  // Image Ready badge
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: isSmall ? 12 : 14),
                          const SizedBox(width: 4),
                          Text('Image Ready', style: TextStyle(color: Colors.white, fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: _clearContent,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              // Description field after image
              SizedBox(height: isSmall ? 12 : 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: 3,
                  style: TextStyle(fontSize: isSmall ? 13 : 14),
                  decoration: InputDecoration(
                    hintText: 'Add description (optional)...',
                    hintStyle: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.grey400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(isSmall ? 12 : 14),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue, size: isSmall ? 20 : 22),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: isSmall ? 36 : 40),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMessageContent(bool isSmall) {
    return Container(
      height: isSmall ? 220 : 250,
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: isSmall ? 24 : 28, color: AppColors.grey400),
              const SizedBox(width: 8),
              Text('Describe your job', style: TextStyle(fontSize: isSmall ? 14 : 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          SizedBox(height: isSmall ? 12 : 16),
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              expands: true,
              style: TextStyle(fontSize: isSmall ? 13 : 14),
              decoration: InputDecoration(
                hintText: 'Enter job details...',
                hintStyle: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.grey400),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (text) => setState(() => _hasContent = text.isNotEmpty),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceContent(bool isSmall) {
    return Column(
      children: [
        if (!_hasContent)
          Container(
            height: isSmall ? 220 : 250,
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Microphone icon - REAL RECORDING
                  GestureDetector(
                    onTap: _startVoiceRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSmall ? 80 : 90,
                      height: isSmall ? 80 : 90,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppColors.error.withValues(alpha: 0.2) : AppColors.grey300,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording ? [BoxShadow(color: AppColors.error.withValues(alpha: 0.4), blurRadius: 16)] : null,
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        size: isSmall ? 36 : 40,
                        color: _isRecording ? AppColors.error : AppColors.grey500,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmall ? 20 : 24),
                  Text(
                    _isRecording ? 'Recording... Tap to Stop' : 'Record a voice message',
                    style: TextStyle(
                      fontSize: isSmall ? 15 : 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isSmall ? 20 : 24),
                  GestureDetector(
                    onTap: _startVoiceRecording,
                    child: Container(
                      width: isSmall ? 180 : 200,
                      height: isSmall ? 48 : 52,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppColors.error : AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: (_isRecording ? AppColors.error : AppColors.primaryBlue).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Center(
                        child: Text(
                          _isRecording ? 'Stop Recording' : 'Start Recording',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isSmall ? 14 : 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Stack(
            children: [
              Container(
                height: isSmall ? 140 : 160,
                padding: EdgeInsets.all(isSmall ? 14 : 16),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // REAL PLAYBACK - Use _playVoiceRecording
                    GestureDetector(
                      onTap: _playVoiceRecording,
                      child: Container(
                        width: isSmall ? 44 : 48,
                        height: isSmall ? 44 : 48,
                        decoration: BoxDecoration(color: _isPlayingAudio ? AppColors.error : AppColors.success, shape: BoxShape.circle),
                        child: Icon(_isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: isSmall ? 10 : 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.success, size: 14),
                              const SizedBox(width: 4),
                              Text('Voice Ready', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600, color: AppColors.success)),
                            ],
                          ),
                          SizedBox(height: isSmall ? 4 : 6),
                          Text(
                            _mediaPath != null ? _mediaPath!.split('/').last : 'voice.m4a',
                            style: TextStyle(fontSize: isSmall ? 11 : 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmall ? 6 : 8),
                          Container(
                            height: 4,
                            decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _isPlayingAudio ? 0.6 : 1.0,
                              child: Container(decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(2))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _clearContent,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPostButton(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // No budget field — the customer just posts the job; providers
            // send their quotes and the two negotiate the price.
            _buildPostButtonInner(isSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildPostButtonInner(bool isSmall) {
    return GestureDetector(
          onTap: _hasContent ? _postJob : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              gradient: _hasContent ? LinearGradient(colors: [widget.serviceColor, widget.serviceColor.withValues(alpha: 0.8)]) : null,
              color: _hasContent ? null : AppColors.grey200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _hasContent ? [BoxShadow(color: widget.serviceColor.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))] : null,
            ),
            child: Center(
              child: Text(
                'Post Job',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _hasContent ? Colors.white : AppColors.grey400,
                ),
              ),
            ),
          ),
        );
  }
}
