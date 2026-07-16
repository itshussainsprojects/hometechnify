// Job Post Detail Screen - View job with video/message/voice

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/date_formatter.dart';
import '../../job/data/models/job_post_model.dart';
import '../../../core/widgets/video_player_screen.dart'; // Added Import
import '../../../core/widgets/voice_note_tile.dart';

class JobPostDetailScreen extends StatefulWidget {
  final JobPostModel job;
  
  const JobPostDetailScreen({super.key, required this.job});

  @override
  State<JobPostDetailScreen> createState() => _JobPostDetailScreenState();
}

class _JobPostDetailScreenState extends State<JobPostDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    final job = widget.job;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text('Job Details', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomerInfo(job, isSmall),
            const SizedBox(height: 20),
            _buildServiceInfo(job, isSmall),
            const SizedBox(height: 20),
            if (job.mediaUrls.isNotEmpty) ...[
                 _buildMediaSection(job, isSmall),
                 const SizedBox(height: 20),
            ],
            _buildLocationSection(job, isSmall),
            const SizedBox(height: 30),
            _buildDescriptionSection(job, isSmall),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: _buildSetPriceButton(horizontalPadding, job),
    );
  }

  Widget _buildCustomerInfo(JobPostModel job, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
             // ... existing avatar ...
             width: isSmall ? 56 : 64,
             height: isSmall ? 56 : 64,
             decoration: BoxDecoration(
               color: AppColors.primaryBlue,
               borderRadius: BorderRadius.circular(12),
               image: job.customerProfileImage != null 
                   ? DecorationImage(image: NetworkImage(job.customerProfileImage!), fit: BoxFit.cover)
                   : null,
             ),
             child: job.customerProfileImage == null ? Center(
               child: Text(
                 (job.customerName ?? job.customerId).split(' ').map((e) => e[0]).take(2).join(),
                 style: TextStyle(
                   color: Colors.white,
                   fontSize: isSmall ? 18 : 20,
                   fontWeight: FontWeight.w700,
                   fontStyle: FontStyle.normal, // Explicit check
                 ),
               ),
             ) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.customerName ?? 'Customer',
                  style: TextStyle(
                    fontSize: isSmall ? 16 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      DateFormatter.timeAgo(job.createdAt),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildServiceInfo(JobPostModel job, bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Required',
          style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(isSmall ? 14 : 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.build_rounded, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  job.title, 
                  style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildMediaSection(JobPostModel job, bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: job.mediaUrls.length,
            separatorBuilder: (_, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
                final url = job.mediaUrls[index];
                final isVideo = _isVideo(url);

                // A voice note is not an image - rendering it as one just shows
                // a broken thumbnail, which is why voice job posts looked empty
                // to providers.
                if (_isAudio(url)) {
                  return Center(child: VoiceNoteTile(url: url));
                }

                return GestureDetector(
                  onTap: () {
                    if (isVideo) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoUrl: url,
                            isNetwork: true,
                          ),
                        ),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: EdgeInsets.zero,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: double.infinity,
                                child: InteractiveViewer(
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 40,
                                right: 20,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
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
                        image: isVideo ? null : DecorationImage( // Only show image if NOT video
                           image: NetworkImage(url),
                           fit: BoxFit.cover,
                           onError: (error, stack) {},
                        ),
                    ),
                    child: Center(
                      child: isVideo 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_fill_rounded, color: AppColors.primaryBlue, size: 32),
                                SizedBox(height: 4),
                                Text("Video", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                              ],
                            )
                          : const Icon(Icons.attachment, color: Colors.white), // Fallback if image loading
                    ),
                  ),
                );
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildLocationSection(JobPostModel job, bool isSmall) {
    // Use Helper to get best address - prioritize customer address if available
    final displayAddress = (job.customerAddress != null && job.customerAddress!.isNotEmpty) 
        ? job.customerAddress! 
        : job.location;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(isSmall ? 14 : 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
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
                child: Icon(Icons.location_on_rounded, color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayAddress,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
  
  Widget _buildDescriptionSection(JobPostModel job, bool isSmall) {
      if (job.description.isEmpty) return const SizedBox.shrink();
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
               Text(
                  'Description',
                  style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700),
               ),
               const SizedBox(height: 10),
               Text(
                   job.description,
                   style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
               ),
          ],
      );
  }

  Widget _buildSetPriceButton(double horizontalPadding, JobPostModel job) {
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/provider/set-price', arguments: job);
          },
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Set Your Price',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') || 
           lower.endsWith('.mov') || 
           lower.endsWith('.avi') || 
           lower.endsWith('.mkv') ||
           lower.endsWith('.webm');
  }

  // Customers record voice job descriptions as .m4a; the rest are here so a
  // different recorder or platform doesn't silently regress to a broken image.
  bool _isAudio(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.m4a') ||
           lower.endsWith('.aac') ||
           lower.endsWith('.mp3') ||
           lower.endsWith('.wav') ||
           lower.endsWith('.ogg');
  }
}
