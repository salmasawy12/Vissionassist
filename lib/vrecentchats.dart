import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:test1/vChatscreen.dart';

/// Recent Chats screen for volunteers.
/// Shows all chats with blind users, last message, and allows opening chat screens.
class VolunteerRecentChatsScreen extends StatefulWidget {
  @override
  VolunteerRecentChatsScreenState createState() =>
      VolunteerRecentChatsScreenState();
}

class VolunteerRecentChatsScreenState extends State<VolunteerRecentChatsScreen>
    with TickerProviderStateMixin {
  String? volunteerId;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      volunteerId = user.uid; // Use UID directly
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Add a small delay to ensure widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                "Not logged in",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (volunteerId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF1370C2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Loading...",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final volunteerChatsCollection = FirebaseFirestore.instance
        .collection('volunteers')
        .doc(volunteerId)
        .collection('chats');

    print("DEBUG: Volunteer ID: $volunteerId");
    print("DEBUG: Querying chats at: volunteers/$volunteerId/chats");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: const Text(
            'Recent Chats',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Header section
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1370C2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.volunteer_activism,
                            color: const Color(0xFF1370C2),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Your Conversations",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Help blind users by responding to their messages",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Volunteer status indicator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle,
                              color: Colors.green[600], size: 12),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You are available to help",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Chats list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: volunteerChatsCollection.snapshots(),
                  builder: (context, chatSnapshot) {
                    if (chatSnapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading chats',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!chatSnapshot.hasData) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF1370C2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Loading conversations...",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final chatDocs = chatSnapshot.data!.docs;

                    print(
                        "DEBUG: Found ${chatDocs.length} chats for volunteer");
                    for (var chat in chatDocs) {
                      print("DEBUG: Chat with blind user: ${chat.id}");
                    }

                    if (chatDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No conversations yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Blind users will appear here when they start chatting',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort chats by most recent timestamp
                    chatDocs.sort((a, b) {
                      final aTimestamp = a['timestamp'] as Timestamp?;
                      final bTimestamp = b['timestamp'] as Timestamp?;

                      if (aTimestamp == null && bTimestamp == null) return 0;
                      if (aTimestamp == null) return 1;
                      if (bTimestamp == null) return -1;

                      return bTimestamp
                          .compareTo(aTimestamp); // Most recent first
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: chatDocs.length,
                      itemBuilder: (context, index) {
                        final chatDoc = chatDocs[index];
                        final blindUserUid = chatDoc.id;

                        return AnimatedBuilder(
                          animation: _fadeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset:
                                  Offset(0, 20 * (1 - _fadeAnimation.value)),
                              child: Opacity(
                                opacity: _fadeAnimation.value,
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: volunteerChatsCollection
                                      .doc(blindUserUid)
                                      .collection('messages')
                                      .orderBy('timestamp', descending: true)
                                      .limit(1)
                                      .snapshots(),
                                  builder: (context, messageSnapshot) {
                                    String lastMessage = "No messages yet";
                                    String timestamp = "--:--";
                                    if (messageSnapshot.hasData &&
                                        messageSnapshot.data!.docs.isNotEmpty) {
                                      final messageData = messageSnapshot
                                          .data!.docs.first
                                          .data() as Map<String, dynamic>;
                                      if (messageData['type'] == 'image') {
                                        lastMessage = '[Image]';
                                      } else {
                                        lastMessage =
                                            messageData['content'] ?? '';
                                      }
                                      final timestampValue =
                                          messageData['timestamp'];
                                      timestamp = (timestampValue != null &&
                                              timestampValue is Timestamp)
                                          ? DateFormat('h:mm a')
                                              .format(timestampValue.toDate())
                                          : "--:--";
                                    }

                                    // Get unread message count
                                    return StreamBuilder<QuerySnapshot>(
                                      stream: volunteerChatsCollection
                                          .doc(blindUserUid)
                                          .collection('messages')
                                          .where('isUser', isEqualTo: false)
                                          .where('read', isEqualTo: false)
                                          .snapshots(),
                                      builder: (context, unreadSnapshot) {
                                        int unreadCount = unreadSnapshot.hasData
                                            ? unreadSnapshot.data!.docs.length
                                            : 0;
                                        bool hasUnreadMessages =
                                            unreadCount > 0;

                                        // Get blind user's display name
                                        return FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection('Users')
                                              .doc(blindUserUid)
                                              .get(),
                                          builder: (context, userSnapshot) {
                                            String displayName = "Blind User";
                                            if (userSnapshot.hasData &&
                                                userSnapshot.data != null &&
                                                userSnapshot.data!.exists) {
                                              final data =
                                                  userSnapshot.data!.data()
                                                      as Map<String, dynamic>;
                                              if (data.containsKey(
                                                      'username') &&
                                                  data['username'] is String) {
                                                displayName = data['username'];
                                              }
                                            }

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 12),
                                              decoration: BoxDecoration(
                                                color: hasUnreadMessages
                                                    ? const Color(
                                                        0xFFF0F9FF) // Light blue background for unread
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: hasUnreadMessages
                                                    ? Border.all(
                                                        color: const Color(
                                                                0xFF1370C2)
                                                            .withOpacity(0.3),
                                                        width: 1,
                                                      )
                                                    : null,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            VolunteerChatScreen(
                                                          receiverUid:
                                                              blindUserUid,
                                                          displayName:
                                                              displayName,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    child: Row(
                                                      children: [
                                                        // Avatar with notification badge
                                                        Stack(
                                                          children: [
                                                            Container(
                                                              width: 56,
                                                              height: 56,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                    0xFF1370C2),
                                                                shape: BoxShape
                                                                    .circle,
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: const Color(
                                                                            0xFF1370C2)
                                                                        .withOpacity(
                                                                            0.3),
                                                                    blurRadius:
                                                                        8,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            2),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  displayName[0]
                                                                      .toUpperCase(),
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            // Unread notification badge
                                                            if (hasUnreadMessages)
                                                              Positioned(
                                                                right: -2,
                                                                top: -2,
                                                                child:
                                                                    Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .red,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10),
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: Colors
                                                                          .white,
                                                                      width: 2,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    unreadCount >
                                                                            99
                                                                        ? '99+'
                                                                        : unreadCount
                                                                            .toString(),
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            width: 16),
                                                        // Content
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                displayName,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: hasUnreadMessages
                                                                      ? const Color(0xFF1370C2) // Blue text for unread
                                                                      : const Color(0xFF1F2937),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(
                                                                lastMessage,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 14,
                                                                  color: hasUnreadMessages
                                                                      ? const Color(0xFF1370C2) // Blue text for unread
                                                                      : Colors.grey[600],
                                                                  fontWeight: hasUnreadMessages
                                                                      ? FontWeight
                                                                          .w500
                                                                      : FontWeight
                                                                          .normal,
                                                                ),
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        // Timestamp
                                                        Text(
                                                          timestamp,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                hasUnreadMessages
                                                                    ? const Color(
                                                                        0xFF1370C2) // Blue text for unread
                                                                    : Colors.grey[
                                                                        500],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
