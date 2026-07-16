// Provider Messages Screen - Chat with Customers
// Premium design with blue theme

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';

class ProviderMessagesScreen extends StatefulWidget {
  const ProviderMessagesScreen({super.key});

  @override
  State<ProviderMessagesScreen> createState() => _ProviderMessagesScreenState();
}

class _ProviderMessagesScreenState extends State<ProviderMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _conversations = [
    {
      'name': 'Sara Ahmed',
      'initials': 'SA',
      'lastMessage': 'When will you arrive?',
      'time': 'Just now',
      'unread': 2,
      'isOnline': true,
      'service': 'AC Repair',
    },
    {
      'name': 'Hassan Ali',
      'initials': 'HA',
      'lastMessage': 'Thank you for the great service!',
      'time': '10 min ago',
      'unread': 0,
      'isOnline': true,
      'service': 'Electrician',
    },
    {
      'name': 'Fatima Khan',
      'initials': 'FK',
      'lastMessage': 'Is tomorrow at 2 PM okay?',
      'time': '1 hour ago',
      'unread': 1,
      'isOnline': false,
      'service': 'Plumber',
    },
    {
      'name': 'Ali Raza',
      'initials': 'AR',
      'lastMessage': 'Please share your location',
      'time': 'Yesterday',
      'unread': 0,
      'isOnline': false,
      'service': 'Carpenter',
    },
    {
      'name': 'Zara Malik',
      'initials': 'ZM',
      'lastMessage': 'The work is done, thanks!',
      'time': '2 days ago',
      'unread': 0,
      'isOnline': false,
      'service': 'Cleaning',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final horizontalPadding = Responsive.horizontalPadding(context);

    final filteredConversations = _searchQuery.isEmpty
        ? _conversations
        : _conversations.where((c) =>
            c['name'].toLowerCase().contains(_searchQuery) ||
            c['service'].toLowerCase().contains(_searchQuery)
          ).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/provider/dashboard');
            }
          },
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: isSmall ? 14 : 15),
                      decoration: InputDecoration(
                        hintText: 'Search customers...',
                        hintStyle: TextStyle(
                          color: AppColors.textHint,
                          fontSize: isSmall ? 14 : 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chat list
          Expanded(
            child: filteredConversations.isEmpty
                ? _buildEmptyState(isSmall)
                : ListView.builder(
                    padding: EdgeInsets.all(horizontalPadding),
                    itemCount: filteredConversations.length,
                    itemBuilder: (context, index) {
                      final chat = filteredConversations[index];
                      return _buildChatItem(chat, isSmall, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, bool isSmall, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/chat', arguments: {
          'name': chat['name'],
          'service': chat['service'],
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isSmall ? 12 : 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                Container(
                  width: isSmall ? 50 : 54,
                  height: isSmall ? 50 : 54,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      chat['initials'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmall ? 16 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (chat['isOnline'])
                  Positioned(
                    right: 2,
                    bottom: 2,
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
            const SizedBox(width: 12),
            // Chat info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['name'],
                          style: TextStyle(
                            fontSize: isSmall ? 14 : 15,
                            fontWeight: chat['unread'] > 0 ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        chat['time'],
                        style: TextStyle(
                          fontSize: isSmall ? 10 : 11,
                          color: chat['unread'] > 0 ? AppColors.primaryBlue : AppColors.textHint,
                          fontWeight: chat['unread'] > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chat['service'],
                    style: TextStyle(
                      fontSize: isSmall ? 10 : 11,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['lastMessage'],
                          style: TextStyle(
                            fontSize: isSmall ? 12 : 13,
                            color: chat['unread'] > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: chat['unread'] > 0 ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat['unread'] > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${chat['unread']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.05);
  }

  Widget _buildEmptyState(bool isSmall) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 20),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: isSmall ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting with your customers',
            style: TextStyle(
              fontSize: isSmall ? 13 : 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
