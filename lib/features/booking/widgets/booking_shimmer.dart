
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';

class BookingShimmer extends StatelessWidget {
  const BookingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // AppBar Shimmer
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: 20,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 120, height: 24),
                    const SizedBox(height: 8),
                    _ShimmerBox(width: 180, height: 14),
                  ],
                ),
                const _ShimmerBox(width: 40, height: 40, radius: 20),
              ],
            ),
          ),
          
          // Tab Bar Shimmer
          Padding(
             padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
             child: const _ShimmerBox(width: double.infinity, height: 45, radius: 25),
          ),
          
          const SizedBox(height: 10),
          
          // Booking List Shimmer
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(horizontalPadding),
              itemCount: 5,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _ShimmerBox(width: 52, height: 52, radius: 14),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ShimmerBox(width: 120, height: 16),
                                const SizedBox(height: 8),
                                _ShimmerBox(width: 80, height: 12),
                              ],
                            ),
                          ),
                          _ShimmerBox(width: 60, height: 24, radius: 20),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ShimmerBox(width: double.infinity, height: 40, radius: 12),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _ShimmerBox({this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
