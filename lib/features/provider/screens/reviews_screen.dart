// Reviews Screen - Provider's reviews and ratings (Wired to Real API)

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/neu_theme.dart';
import '../providers/provider_controller.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Fetch reviews on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderController>().fetchReviews();
    });

    final isSmall = MediaQuery.of(context).size.height < 700;

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
        title: const Text('Reviews & Ratings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Consumer<ProviderController>(
        builder: (context, controller, child) {
          final reviewsData = controller.reviewsData;
          final isLoading = controller.isLoading && reviewsData.isEmpty;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = reviewsData['stats'] as Map<String, dynamic>? ?? {};
          final reviews = reviewsData['reviews'] as List<dynamic>? ?? [];
          final avgRating = (stats['averageRating'] ?? 0).toDouble();
          final totalReviews = stats['totalReviews'] ?? 0;
          final breakdown = stats['breakdown'] as Map<String, dynamic>? ?? {};

          if (totalReviews == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border_rounded, size: 80, color: AppColors.grey300),
                  const SizedBox(height: 16),
                  Text('No reviews yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Complete bookings to get reviews', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.fetchReviews(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverallRating(avgRating, totalReviews),
                  const SizedBox(height: 20),
                  _buildRatingBreakdown(breakdown, totalReviews),
                  const SizedBox(height: 24),
                  Text(
                    'All Reviews',
                    style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  ...reviews.asMap().entries.map((entry) => _buildReviewCard(entry.value, entry.key)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverallRating(double avgRating, int totalReviews) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            avgRating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return Icon(
                i < avgRating.floor() ? Icons.star_rounded : (i < avgRating ? Icons.star_half_rounded : Icons.star_border_rounded),
                color: Colors.amber,
                size: 28,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalReviews reviews',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRatingBreakdown(Map<String, dynamic> breakdown, int total) {
    return Column(
      children: [5, 4, 3, 2, 1].map((stars) {
        final count = (breakdown['$stars'] ?? 0) as int;
        return _buildRatingBar(stars, count, total);
      }).toList(),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final fraction = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$stars', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: AppColors.grey100,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text('$count', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(dynamic review, int index) {
    final authorName = review['author']?['name'] ?? 'Customer';
    final authorImage = review['author']?['profileImage'];
    final rating = (review['rating'] ?? 5) as int;
    final comment = review['comment'] ?? '';
    final serviceName = review['booking']?['service']?['name'] ?? '';
    final createdAt = review['created_at'] ?? review['createdAt'] ?? '';
    final date = createdAt is String ? DateTime.tryParse(createdAt) : null;
    final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: authorImage != null ? NetworkImage(authorImage) : null,
                backgroundColor: AppColors.grey100,
                child: authorImage == null
                    ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : 'C',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (serviceName.isNotEmpty)
                      Text(serviceName, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(dateStr, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: Colors.amber,
                size: 18,
              );
            }),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.05, end: 0);
  }
}
