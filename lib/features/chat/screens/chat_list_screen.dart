// Chat List Screen - Professional Design with Brand Colors

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/neu_theme.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    final isTiny = size.height < 550;
    final horizontalPadding = isTiny ? 14.0 : isSmall ? 16.0 : 20.0;



    return Scaffold(
      body: Container(
        color: NeuTheme.bg,
        child: Column(
          children: [
            // App Bar
            _buildAppBar(isSmall, isTiny),
            // Search Bar
            _buildSearchBar(horizontalPadding, isSmall),
            // Conversations List
            Expanded(
              child: _buildChatList(horizontalPadding, isSmall, isTiny),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isSmall, bool isTiny) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isTiny ? 8 : isSmall ? 12 : 16),
        left: isTiny ? 12 : 16,
        right: isTiny ? 12 : 16,
        bottom: isTiny ? 8 : 12,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              // ChatListScreen is a tab inside HomeScreen's IndexedStack.
              // Navigator.pop() would close the app since there's nothing to pop.
              // Correct behavior: switch back to Home tab (index 0).
              context.read<NavigationProvider>().setIndex(0);
            },
            child: Container(
              width: isTiny ? 38 : isSmall ? 42 : 46,
              height: isTiny ? 38 : isSmall ? 42 : 46,
              decoration: NeuTheme.sm(radius: 12),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: isTiny ? 18 : 20,
              ),
            ),
          ),
          SizedBox(width: isTiny ? 12 : 16),
          // Title
          Text(
            'Messages',
            style: TextStyle(
              fontSize: isTiny ? 18 : isSmall ? 20 : 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.15, end: 0);
  }

  Widget _buildSearchBar(double horizontalPadding, bool isSmall) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isSmall ? 8 : 12),
      child: Container(
        height: isSmall ? 46 : 52,
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 14 : 18),
        decoration: NeuTheme.inset(radius: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.grey400, size: isSmall ? 20 : 22),
            SizedBox(width: isSmall ? 10 : 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    color: AppColors.textHint,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () => _searchController.clear(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: AppColors.grey500, size: 14),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildChatList(double padding, bool isSmall, bool isTiny) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return _buildEmptyState(isSmall, isTiny);
    
    // Initialize favorites sync
    favoritesService.init(user.id);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: user.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState(isSmall, isTiny);

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final otherUserId = (data['users'] as List).firstWhere((id) => id != user.id, orElse: () => '');
            
            if (otherUserId == '') return const SizedBox.shrink();

            // Read name directly from userNames map stored in chat doc
            final userNames = data['userNames'] as Map<String, dynamic>?;
            String? name = userNames?[otherUserId];
            
            Widget buildItem(String displayName) {
                final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
                final lastMessage = data['lastMessage'] ?? 'No messages';
                final timestamp = (data['lastTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

                final conversation = {
                  'id': docs[index].id,
                  'name': displayName,
                  'initials': initials,
                  'otherUserId': otherUserId,
                  'lastMessage': lastMessage,
                  'time': _formatTime(timestamp),
                  'unread': 0, 
                  'isOnline': false,
                  'color': AppColors.primaryBlue,
                };
                
                return Dismissible(
                  key: Key(docs[index].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Chat?'),
                        content: const Text('This will remove the chat from your list properly.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    context.read<ChatProvider>().deleteChat(docs[index].id, user.id);
                    SnackBarHelper.showSuccess(context, "Chat deleted");
                  },
                  child: _buildConversationItem(conversation, index, isSmall, isTiny),
                );
            }

            // Fallback: If name is missing or 'User', fetch from users collection
            if (name == null || name == 'User') {
               return FutureBuilder<DocumentSnapshot>(
                 future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                 builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                       final userData = snapshot.data!.data() as Map<String, dynamic>?;
                       name = userData?['name'] ?? 'User';
                    }
                    return buildItem(name ?? 'User');
                 }
               );
            }

            return buildItem(name);
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  Widget _buildEmptyState(bool isSmall, bool isTiny) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isTiny ? 70 : isSmall ? 80 : 90,
            height: isTiny ? 70 : isSmall ? 80 : 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryBlue.withValues(alpha: 0.15),
                  AppColors.primaryBlue.withValues(alpha: 0.08),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: isTiny ? 32 : isSmall ? 38 : 44,
              color: AppColors.primaryBlue,
            ),
          ),
          SizedBox(height: isSmall ? 14 : 18),
          Text(
            'No Conversations',
            style: TextStyle(
              fontSize: isTiny ? 15 : isSmall ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start chatting with service providers',
            style: TextStyle(
              fontSize: isTiny ? 11 : isSmall ? 12 : 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation, int index, bool isSmall, bool isTiny) {
    final hasUnread = conversation['unread'] > 0;
    final avatarColor = conversation['color'] as Color;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'name': conversation['name'], 
          'service': 'Service Provider',
          'recipientId': conversation['otherUserId'], // Pass ID!
        },
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: isTiny ? 8 : isSmall ? 10 : 12),
        padding: EdgeInsets.all(isTiny ? 12 : isSmall ? 14 : 16),
        decoration: hasUnread
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : NeuTheme.sm(radius: 16),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: isTiny ? 48 : isSmall ? 52 : 58,
                  height: isTiny ? 48 : isSmall ? 52 : 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [avatarColor, avatarColor.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      conversation['initials'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTiny ? 16 : isSmall ? 18 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                // Online indicator
                if (conversation['isOnline'])
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: isTiny ? 12 : 14,
                      height: isTiny ? 12 : 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: isTiny ? 10 : isSmall ? 12 : 14),
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation['name'],
                          style: TextStyle(
                            fontSize: isTiny ? 13 : isSmall ? 14 : 15,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        conversation['time'],
                        style: TextStyle(
                          fontSize: isTiny ? 9 : isSmall ? 10 : 11,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          color: hasUnread ? AppColors.primaryBlue : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Favorite Icon
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            favoritesService.toggleFavorite(
                              conversation['name'],
                              details: {
                                'initials': conversation['initials'],
                                'isOnline': conversation['isOnline'],
                                'color': conversation['color'],
                              },
                            );
                          });
                        },
                        child: Icon(
                          favoritesService.isFavorite(conversation['name'])
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: isTiny ? 16 : isSmall ? 18 : 20,
                          color: favoritesService.isFavorite(conversation['name'])
                              ? Colors.red
                              : AppColors.grey400,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTiny ? 3 : 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation['lastMessage'],
                          style: TextStyle(
                            fontSize: isTiny ? 11 : isSmall ? 12 : 13,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                            color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: isTiny ? 18 : isSmall ? 20 : 22,
                          height: isTiny ? 18 : isSmall ? 20 : 22,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${conversation['unread']}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTiny ? 9 : isSmall ? 10 : 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}
