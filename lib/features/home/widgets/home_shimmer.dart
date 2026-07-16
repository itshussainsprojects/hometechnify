
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Shimmer
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerBox(width: 80, height: 12),
                        const SizedBox(height: 8),
                        _ShimmerBox(width: 150, height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _ShimmerBox(width: 46, height: 46, radius: 14),
                ],
              ),
            ),
            
            // Search Bar Shimmer
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: _ShimmerBox(height: isSmall ? 48 : 52, radius: 14)),
                  const SizedBox(width: 12),
                  _ShimmerBox(width: isSmall ? 48 : 52, height: isSmall ? 48 : 52, radius: 14),
                ],
              ),
            ),
            
            // Banner Shimmer
            Padding(
               padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
               child: _ShimmerBox(width: double.infinity, height: isSmall ? 140 : 160, radius: 20),
            ),
            
            const SizedBox(height: 24),
            
            // Services Title
            Padding(
               padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   _ShimmerBox(width: 100, height: 20),
                   _ShimmerBox(width: 60, height: 14),
                 ],
               ),
            ),
            
            const SizedBox(height: 16),
            
            // Services Grid Shimmer
            GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ShimmerBox(width: 48, height: 48, radius: 12),
                      const SizedBox(height: 12),
                      _ShimmerBox(width: 60, height: 10),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (index) => const _ShimmerBox(width: 24, height: 24, radius: 4)),
        ),
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
