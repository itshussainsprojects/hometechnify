// Chat Screen - Real-time with Firestore

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../data/models/message_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/services/video_compressor.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ChatScreen extends StatefulWidget {
  final String? recipientId;
  final String? recipientName;
  final String? recipientService;
  
  const ChatScreen({super.key, this.recipientId, this.recipientName, this.recipientService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isTyping = false;
  bool _isUploading = false; 
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  
  @override
  void dispose() {
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Toggle voice recording: tap to start, tap again to stop & send
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // Explicitly check and request permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        SnackBarHelper.showError(context, "Microphone permission is required. Please enable it in App Settings.");
        openAppSettings();
      }
      return;
    }

    if (!status.isGranted) {
      if (mounted) SnackBarHelper.showError(context, "Microphone permission denied");
      return;
    }

    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
           _isRecording = true;
           _recordingStartTime = DateTime.now();
        });
        debugPrint("🎙️ Recording started: $path");
      } else {
        if (mounted) SnackBarHelper.showError(context, "Microphone not available");
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
      if (mounted) SnackBarHelper.showError(context, "Could not start recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingStartTime = null;
      });
      debugPrint("🎙️ Recording stopped: $path");
      
      if (path != null) {
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          _sendMedia(file, 'audio');
        } else {
          debugPrint("Recording file empty or missing");
          if (mounted) SnackBarHelper.showError(context, "Recording too short");
        }
      }
    } catch (e) {
      debugPrint("Error stopping record: $e");
      setState(() {
        _isRecording = false;
        _recordingStartTime = null;
      });
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingStartTime = null;
      });
      if (mounted) SnackBarHelper.showSuccess(context, "Recording cancelled");
    } catch (e) {
      debugPrint("Error cancelling record: $e");
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final user = context.read<AuthProvider>().user;
    if (user == null || widget.recipientId == null) return;

    _messageController.clear();
    setState(() => _isTyping = false);

    context.read<ChatProvider>().sendMessage(
      senderId: user.id,
      receiverId: widget.recipientId!,
      text: text,
      senderName: user.name,
      receiverName: widget.recipientName,
    ).then((_) {
      _scrollToBottom();
    }).catchError((e) {
      debugPrint("Error sending message: $e");
      if (mounted) SnackBarHelper.showError(context, "Failed to send message: $e");
    });
    
    _messageController.clear();
    setState(() => _isTyping = false);
    _scrollToBottom();
    _scrollToBottom();
  }

  Future<void> _pickAndSendMedia({required bool isVideo, required bool isCamera}) async {
    final picker = ImagePicker();
    final XFile? file = isVideo 
        ? await picker.pickVideo(source: isCamera ? ImageSource.camera : ImageSource.gallery)
        : await picker.pickImage(source: isCamera ? ImageSource.camera : ImageSource.gallery);
    
    if (file != null) {
      var path = file.path;
      if (isVideo) {
        path = await VideoCompressor.compress(path); // shrink before upload
      }
      _sendMedia(File(path), isVideo ? 'video' : 'image');
    }
  }

  Future<void> _sendMedia(File file, String type) async {
     setState(() => _isUploading = true);
     try {
        final user = context.read<AuthProvider>().user;
        if (user != null && widget.recipientId != null) {
          await context.read<ChatProvider>().sendMediaMessage(
            senderId: user.id,
            receiverId: widget.recipientId!,
            file: file,
            type: type,
          );
          _scrollToBottom();
        }
     } catch (e) {
        if (mounted) SnackBarHelper.showError(context, "Failed to send media");
     } finally {
        if (mounted) setState(() => _isUploading = false);
     }
  }

  void _showAttachmentOptions() {
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
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryBlue),
              title: const Text('Camera'),
              onTap: () { Navigator.pop(context); _pickAndSendMedia(isVideo: false, isCamera: true); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryBlue),
              title: const Text('Gallery'),
              onTap: () { Navigator.pop(context); _pickAndSendMedia(isVideo: false, isCamera: false); },
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _confirmDeleteMessage(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This message will be deleted for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = context.read<AuthProvider>().user;
      if (user != null && widget.recipientId != null) {
        await context.read<ChatProvider>().deleteMessageForPair(
          user.id, 
          widget.recipientId!, 
          message.id
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final user = context.watch<AuthProvider>().user;
    debugPrint("🔍 ChatScreen Build - RecipientID: ${widget.recipientId}");
    debugPrint("🔍 ChatScreen Build - RecipientName: ${widget.recipientName}");
    
    if (user == null || widget.recipientId == null) {
      return Scaffold(
        body: Center(child: Text("Error: Missing User or Recipient ID")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(isSmall),
          Expanded(child: _buildMessageList(isSmall, user.id)),
          _buildInputArea(isSmall),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isSmall) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isSmall ? 10 : 14),
        left: 16,
        right: 16,
        bottom: isSmall ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: isSmall ? 44 : 50,
            height: isSmall ? 44 : 50,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(widget.recipientName != null && widget.recipientName!.isNotEmpty ? widget.recipientName![0].toUpperCase() : 'U', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isSmall ? 16 : 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.recipientName ?? 'Provider User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmall ? 15 : 17)),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Online', style: TextStyle(color: AppColors.success, fontSize: isSmall ? 11 : 12)),
                    if (widget.recipientService != null) ...[
                      const SizedBox(width: 8),
                      Text('• ${widget.recipientService}', style: TextStyle(color: AppColors.textHint, fontSize: isSmall ? 11 : 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Call icon removed as requested

        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildMessageList(bool isSmall, String currentUserId) {
    return StreamBuilder<List<MessageModel>>(
      stream: context.read<ChatProvider>().getMessages(currentUserId, widget.recipientId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final messages = snapshot.data ?? [];
        
        // Auto scroll to bottom only if at bottom or initial load
        // Simply jumping to end for now on new data might be jarring if user scrolled up.
        // For simplicity in this iteration, we just show the list.
        
        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 12 : 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == currentUserId;
            return _buildMessageBubble(message, isMe, isSmall, index);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe, bool isSmall, int index) {
    final mediaUrl = message.mediaUrl ?? (message.type != 'text' ? message.text : null);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _confirmDeleteMessage(message),
        child: Container(
        margin: EdgeInsets.only(bottom: isSmall ? 8 : 12, left: isMe ? 60 : 0, right: isMe ? 0 : 60),
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 14 : 18, vertical: isSmall ? 10 : 14),
        decoration: BoxDecoration(
          gradient: isMe ? AppColors.primaryGradient : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: (isMe ? AppColors.primaryBlue : Colors.black).withValues(alpha: isMe ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.type == 'image' && mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl, 
                  width: 200, 
                  height: 200, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                ),
              )
            else if (message.type == 'video' && mediaUrl != null)
              _VideoMessageBubble(videoUrl: mediaUrl)
            else if (message.type == 'audio' && mediaUrl != null)
              _AudioMessageBubble(audioUrl: mediaUrl, isMe: isMe)
            else
              Text(
                message.text,
                style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: isSmall ? 14 : 15, height: 1.4),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textHint, fontSize: isSmall ? 10 : 11),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return "$hour12:$minute $period";
  }

  Widget _buildInputArea(bool isSmall) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, isSmall ? 12 : 16, 16, MediaQuery.of(context).padding.bottom + (isSmall ? 12 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: _isRecording ? _buildRecordingBar(isSmall) : _buildNormalInputBar(isSmall),
    );
  }

  /// Recording mode: shows timer, cancel, and stop/send buttons
  Widget _buildRecordingBar(bool isSmall) {
    return Row(
      children: [
        // Cancel button
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        // Recording indicator
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 10 : 14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text("Recording...", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: isSmall ? 14 : 15)),
                const Spacer(),
                StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, _) {
                    final elapsed = _recordingStartTime != null 
                        ? DateTime.now().difference(_recordingStartTime!) 
                        : Duration.zero;
                    final mins = elapsed.inMinutes.toString().padLeft(2, '0');
                    final secs = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
                    return Text('$mins:$secs', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: isSmall ? 14 : 15));
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Stop & Send button
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: isSmall ? 48 : 52,
            height: isSmall ? 48 : 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.send_rounded, color: Colors.white, size: isSmall ? 20 : 22),
            ),
          ),
        ),
      ],
    );
  }

  /// Normal mode: text input with attachment and mic buttons
  Widget _buildNormalInputBar(bool isSmall) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 8 : 10),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showAttachmentOptions, 
                  child: _isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : Icon(Icons.attach_file_rounded, color: AppColors.grey500, size: isSmall ? 20 : 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: (v) => setState(() => _isTyping = v.trim().isNotEmpty),
                    style: TextStyle(fontSize: isSmall ? 14 : 15),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Write a reply',
                      hintStyle: TextStyle(color: AppColors.textHint, fontSize: isSmall ? 14 : 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Mic button (tap to start recording)
        if (!_isTyping)
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: isSmall ? 44 : 48,
              height: isSmall ? 44 : 48,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic_rounded, color: AppColors.primaryBlue, size: isSmall ? 22 : 24),
            ),
          ),
        if (!_isTyping) const SizedBox(width: 8),
        // Send button
        GestureDetector(
          onTap: _isTyping ? _sendMessage : null,
          child: Container(
            width: isSmall ? 48 : 52,
            height: isSmall ? 48 : 52,
            decoration: BoxDecoration(
              gradient: _isTyping ? AppColors.primaryGradient : LinearGradient(colors: [AppColors.grey300, AppColors.grey300]),
              shape: BoxShape.circle,
              boxShadow: _isTyping ? [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ] : null,
            ),
            child: Center(
              child: Icon(Icons.send_rounded, color: Colors.white, size: isSmall ? 20 : 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoMessageBubble extends StatefulWidget {
  final String videoUrl;
  const _VideoMessageBubble({required this.videoUrl});

  @override
  State<_VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<_VideoMessageBubble> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoPlayerController.initialize();
    
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: false,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      placeholder: const Center(child: CircularProgressIndicator()),
      autoInitialize: true,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null) {
        return const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator()));
    }
    return SizedBox(
      width: 200,
      height: 150, // Fixed height for bubble
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}

class _AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  const _AudioMessageBubble({required this.audioUrl, required this.isMe});

  @override
  State<_AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<_AudioMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, 
               color: widget.isMe ? Colors.white : AppColors.primaryBlue, size: 32),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.audioUrl));
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                   data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 2,
                      activeTrackColor: widget.isMe ? Colors.white : AppColors.primaryBlue,
                      inactiveTrackColor: widget.isMe ? Colors.white.withValues(alpha: 0.3) : AppColors.grey300,
                      thumbColor: widget.isMe ? Colors.white : AppColors.primaryBlue,
                   ),
                   child: Slider(
                      min: 0,
                      max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                      value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble()),
                      onChanged: (v) async {
                         await _audioPlayer.seek(Duration(milliseconds: v.toInt()));
                      },
                   ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text(_formatDuration(_position), style: TextStyle(fontSize: 10, color: widget.isMe ? Colors.white70 : AppColors.textSecondary)),
                        Text(_formatDuration(_duration), style: TextStyle(fontSize: 10, color: widget.isMe ? Colors.white70 : AppColors.textSecondary)),
                     ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

