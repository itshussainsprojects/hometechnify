// Favorite Providers Screen - Shows user's favorite service providers

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/constants.dart';
import '../../core/services/favorites_service.dart';

class FavoriteProvidersScreen extends StatefulWidget {
  const FavoriteProvidersScreen({super.key});

  @override
  State<FavoriteProvidersScreen> createState() => _FavoriteProvidersScreenState();
}

class _FavoriteProvidersScreenState extends State<FavoriteProvidersScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final horizontalPadding = isSmall ? 16.0 : 20.0;
    final favorites = favoritesService.favoritesWithDetails;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
        ),
        title: Text(
          'Favorite Providers',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: isSmall ? 18 : 20,
          ),
        ),
        centerTitle: true,
      ),
      body: favorites.isEmpty
          ? _buildEmptyState(isSmall)
          : ListView.builder(
              padding: EdgeInsets.all(horizontalPadding),
              itemCount: favorites.length,
              itemBuilder: (context, index) => _buildProviderCard(
                favorites[index],
                index,
                isSmall,
              ),
            ),
    );
  }

  Widget _buildEmptyState(bool isSmall) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_outline_rounded,
              size: 48,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Favorites Yet',
            style: TextStyle(
              fontSize: isSmall ? 20 : 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the heart icon on any provider in your messages to add them to favorites',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmall ? 13 : 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/chats'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Go to Messages',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildProviderCard(Map<String, dynamic> provider, int index, bool isSmall) {
    final name = provider['name'] as String? ?? 'Provider';
    final initials = provider['initials'] as String? ?? name.substring(0, 2).toUpperCase();
    final color = provider['color'] as Color? ?? AppColors.primaryBlue;
    final isOnline = provider['isOnline'] as bool? ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 10 : 14),
      padding: EdgeInsets.all(isSmall ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: isSmall ? 44 : 50,
                height: isSmall ? 44 : 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmall ? 14 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          // Provider Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.favorite_rounded, size: 12, color: Colors.red),
                    const SizedBox(width: 3),
                    Text(
                      'Favorite',
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Message Button
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: {'name': name, 'service': 'Service Provider'},
                ),
                child: Container(
                  width: isSmall ? 34 : 38,
                  height: isSmall ? 34 : 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: isSmall ? 16 : 18,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Remove Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    favoritesService.removeFavorite(name);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name removed from favorites'),
                      backgroundColor: AppColors.textSecondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: Container(
                  width: isSmall ? 34 : 38,
                  height: isSmall ? 34 : 38,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: isSmall ? 16 : 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}
