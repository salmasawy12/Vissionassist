import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class RecentChatsScreen extends StatefulWidget {
  const RecentChatsScreen({Key? key}) : super(key: key);

  @override
  State<RecentChatsScreen> createState() => _RecentChatsScreenState();
}

class _RecentChatsScreenState extends State<RecentChatsScreen>
    with TickerProviderStateMixin {
  final FlutterTts flutterTts = FlutterTts();
  final SpeechToText speechToText = SpeechToText();
  bool isListening = false;
  bool isSpeaking = false;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _initializeSpeechToText();
    _initializeAnimations();
  }

  void _initializeTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  void _initializeSpeechToText() async {
    bool available = await speechToText.initialize();
    if (available) {
      print("Speech to text initialized successfully");
    } else {
      print("Speech to text not available");
    }
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    flutterTts.stop();
    speechToText.stop();
    super.dispose();
  }

  void _openChat(String volunteerUid, String volunteerUsername) {
    print("=== OPENING CHAT ===");
    print("Volunteer UID: $volunteerUid");
    print("Volunteer Username: $volunteerUsername");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverUid: volunteerUid,
          receiverRole: 'volunteers',
          displayName: volunteerUsername,
        ),
      ),
    );
  }

  void _speak(String text) async {
    if (isSpeaking) return;
    setState(() {
      isSpeaking = true;
    });
    await flutterTts.speak(text);
    setState(() {
      isSpeaking = false;
    });
  }

  void _startListening() async {
    if (isListening) return;

    setState(() {
      isListening = true;
    });

    await speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          _handleVoiceCommand(result.recognizedWords.toLowerCase());
        }
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 3),
    );

    setState(() {
      isListening = false;
    });
  }

  void _handleVoiceCommand(String command) {
    print("Voice command received: $command");

    if (command.contains("help") || command.contains("commands")) {
      _speak(
          "Available commands: say 'help' for commands, 'back' to go back, 'refresh' to refresh the screen, 'debug' to check messages");
    } else if (command.contains("back")) {
      _speak("Going back");
      Navigator.pop(context);
    } else if (command.contains("refresh")) {
      _speak("Refreshing the screen");
      setState(() {});
    } else if (command.contains("debug")) {
      _debugMessages();
    } else {
      _speak("Command not recognized. Say 'help' for available commands");
    }
  }

  void _debugMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("=== DEBUG: Checking all messages ===");

    // Get all chats
    final chats = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('chats')
        .get();

    for (var chatDoc in chats.docs) {
      print("Chat with: ${chatDoc.id}");

      final messages = await chatDoc.reference.collection('messages').get();
      for (var msgDoc in messages.docs) {
        final data = msgDoc.data();
        print(
            "  Message: ${data['content']} | isUser: ${data['isUser']} | read: ${data['read']}");

        // Fix messages without read field
        if (data['read'] == null) {
          bool shouldBeRead =
              data['isUser'] == true; // User's own messages should be read
          await msgDoc.reference.update({'read': shouldBeRead});
          print("    -> Fixed: set read to $shouldBeRead");
        }
      }
    }

    print("=== DEBUG: Fixed all messages ===");
  }

  void _fixAllMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("=== FIXING ALL MESSAGES ===");

    // Get all chats
    final chats = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('chats')
        .get();

    for (var chatDoc in chats.docs) {
      final messages = await chatDoc.reference.collection('messages').get();
      for (var msgDoc in messages.docs) {
        final data = msgDoc.data();
        if (data['read'] == null) {
          bool shouldBeRead =
              data['isUser'] == true; // User's own messages should be read
          await msgDoc.reference.update({'read': shouldBeRead});
          print("Fixed message: ${data['content']} -> read: $shouldBeRead");
        }
      }
    }

    print("=== ALL MESSAGES FIXED ===");
    setState(() {}); // Refresh the UI
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to view chats'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Recent Chats',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: isListening ? Colors.red : const Color(0xFF1F2937),
            ),
            onPressed: _startListening,
          ),
        ],
      ),
      body: Column(
        children: [
          // Voice command help
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF3F4F6),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Say "help" for voice commands',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('volunteers')
                  .where('available', isEqualTo: true)
                  .snapshots(),
              builder: (context, volunteerSnapshot) {
                if (volunteerSnapshot.hasError) {
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
                          'Something went wrong',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again later',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!volunteerSnapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF1370C2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading volunteers...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final volunteerDocs = volunteerSnapshot.data!.docs;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Users')
                      .doc(user.uid)
                      .collection('chats')
                      .snapshots(),
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
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF1370C2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading chats...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final chatDocs = chatSnapshot.data!.docs;

                    // Separate volunteers into two lists: with chats and without chats
                    List<QueryDocumentSnapshot> volunteersWithChats = [];
                    List<QueryDocumentSnapshot> volunteersWithoutChats = [];

                    for (var volunteer in volunteerDocs) {
                      final volunteerUid = volunteer.id;
                      final hasChat =
                          chatDocs.any((chat) => chat.id == volunteerUid);
                      if (hasChat) {
                        volunteersWithChats.add(volunteer);
                      } else {
                        volunteersWithoutChats.add(volunteer);
                      }
                    }

                    // Sort volunteers with chats by most recent chat timestamp
                    volunteersWithChats.sort((a, b) {
                      final aChat =
                          chatDocs.firstWhere((chat) => chat.id == a.id);
                      final bChat =
                          chatDocs.firstWhere((chat) => chat.id == b.id);

                      final aTimestamp = aChat['timestamp'] as Timestamp?;
                      final bTimestamp = bChat['timestamp'] as Timestamp?;

                      if (aTimestamp == null && bTimestamp == null) return 0;
                      if (aTimestamp == null) return 1;
                      if (bTimestamp == null) return -1;

                      return bTimestamp
                          .compareTo(aTimestamp); // Most recent first
                    });

                    return Column(
                      children: [
                        // Show volunteers without chats as circle avatars at the top
                        if (volunteersWithoutChats.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Available Volunteers",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: volunteersWithoutChats.length,
                                    itemBuilder: (context, index) {
                                      final volunteer =
                                          volunteersWithoutChats[index];
                                      final volunteerUid = volunteer.id;
                                      final volunteerUsername =
                                          volunteer['username'] ?? 'Unknown';

                                      return GestureDetector(
                                        onTap: () => _openChat(
                                            volunteerUid, volunteerUsername),
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(right: 16),
                                          child: Column(
                                            children: [
                                              // Circle avatar with green dot
                                              Stack(
                                                children: [
                                                  Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF1370C2),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(
                                                                  0xFF1370C2)
                                                              .withOpacity(0.3),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                              0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        volunteerUsername[0]
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Green dot for online status
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      width: 16,
                                                      height: 16,
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                          width: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                volunteerUsername,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey[700],
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Show existing chats below
                        if (volunteersWithChats.isNotEmpty) ...[
                          if (volunteersWithoutChats.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Divider(color: Colors.grey[300]),
                            ),
                          Expanded(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: volunteersWithChats.length,
                              itemBuilder: (context, index) {
                                final volunteer = volunteersWithChats[index];
                                final volunteerUid = volunteer.id;
                                final volunteerUsername =
                                    volunteer['username'] ?? 'Unknown';
                                final isAvailable =
                                    volunteer['available'] == true;

                                return AnimatedBuilder(
                                  animation: _fadeAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                          0, 20 * (1 - _fadeAnimation.value)),
                                      child: Opacity(
                                        opacity: _fadeAnimation.value,
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('Users')
                                              .doc(user.uid)
                                              .collection('chats')
                                              .doc(volunteerUid)
                                              .collection('messages')
                                              .orderBy('timestamp',
                                                  descending: true)
                                              .limit(1)
                                              .snapshots(),
                                          builder: (context, messageSnapshot) {
                                            String lastMessage =
                                                "No messages yet";
                                            String timestamp = "--:--";
                                            String displayMessage = '';
                                            if (messageSnapshot.hasData &&
                                                messageSnapshot
                                                    .data!.docs.isNotEmpty) {
                                              final messageData =
                                                  messageSnapshot
                                                          .data!.docs.first
                                                          .data()
                                                      as Map<String, dynamic>;
                                              if (messageData != null) {
                                                final lastMessageType =
                                                    messageData['type'] ?? '';
                                                displayMessage =
                                                    messageData['content'] ??
                                                        '';
                                                if (lastMessageType ==
                                                        'audio' ||
                                                    displayMessage ==
                                                        '[Audio]') {
                                                  displayMessage = '[Audio]';
                                                } else if (lastMessageType ==
                                                        'image' ||
                                                    displayMessage ==
                                                        '[Image]') {
                                                  displayMessage = '[Image]';
                                                }
                                              }
                                              final timestampValue =
                                                  messageData['timestamp'];
                                              timestamp = (timestampValue !=
                                                          null &&
                                                      timestampValue
                                                          is Timestamp)
                                                  ? DateFormat('h:mm a').format(
                                                      timestampValue.toDate())
                                                  : "--:--";
                                            }

                                            return StreamBuilder<QuerySnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('Users')
                                                  .doc(user.uid)
                                                  .collection('chats')
                                                  .doc(volunteerUid)
                                                  .collection('messages')
                                                  .where('isUser',
                                                      isEqualTo: false)
                                                  .where('read',
                                                      isEqualTo: false)
                                                  .snapshots(),
                                              builder:
                                                  (context, unreadSnapshot) {
                                                int unreadCount =
                                                    unreadSnapshot.hasData
                                                        ? unreadSnapshot
                                                            .data!.docs.length
                                                        : 0;
                                                bool hasUnreadMessages =
                                                    unreadCount > 0;

                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                      bottom: 12),
                                                  decoration: BoxDecoration(
                                                    color: hasUnreadMessages
                                                        ? const Color(
                                                            0xFFF0F9FF) // Light blue background for unread
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: hasUnreadMessages
                                                        ? Border.all(
                                                            color: const Color(
                                                                    0xFF1370C2)
                                                                .withOpacity(
                                                                    0.3),
                                                            width: 1,
                                                          )
                                                        : null,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.05),
                                                        blurRadius: 10,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      onTap: () => _openChat(
                                                          volunteerUid,
                                                          volunteerUsername),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(16),
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
                                                                    color: isAvailable
                                                                        ? const Color(
                                                                            0xFF1370C2)
                                                                        : Colors
                                                                            .grey[400],
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: (isAvailable
                                                                                ? const Color(0xFF1370C2)
                                                                                : Colors.grey[400]!)
                                                                            .withOpacity(0.3),
                                                                        blurRadius:
                                                                            8,
                                                                        offset: const Offset(
                                                                            0,
                                                                            2),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: Center(
                                                                    child: Text(
                                                                      volunteerUsername[
                                                                              0]
                                                                          .toUpperCase(),
                                                                      style:
                                                                          const TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                        fontSize:
                                                                            20,
                                                                        fontWeight:
                                                                            FontWeight.bold,
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
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: Colors
                                                                            .red,
                                                                        borderRadius:
                                                                            BorderRadius.circular(10),
                                                                        border:
                                                                            Border.all(
                                                                          color:
                                                                              Colors.white,
                                                                          width:
                                                                              2,
                                                                        ),
                                                                      ),
                                                                      child:
                                                                          Text(
                                                                        unreadCount >
                                                                                99
                                                                            ? '99+'
                                                                            : unreadCount.toString(),
                                                                        style:
                                                                            const TextStyle(
                                                                          color:
                                                                              Colors.white,
                                                                          fontSize:
                                                                              10,
                                                                          fontWeight:
                                                                              FontWeight.bold,
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
                                                                  Row(
                                                                    children: [
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          volunteerUsername,
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                16,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            color: hasUnreadMessages
                                                                                ? const Color(0xFF1370C2) // Blue text for unread
                                                                                : const Color(0xFF1F2937),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      if (!isAvailable)
                                                                        Container(
                                                                          padding:
                                                                              const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                8,
                                                                            vertical:
                                                                                4,
                                                                          ),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                Colors.red[50],
                                                                            borderRadius:
                                                                                BorderRadius.circular(12),
                                                                            border:
                                                                                Border.all(color: Colors.red[200]!),
                                                                          ),
                                                                          child:
                                                                              Text(
                                                                            'Unavailable',
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 10,
                                                                              color: Colors.red[700],
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    displayMessage,
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          14,
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
                                                                        : Colors
                                                                            .grey[500],
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
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
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                        // Show empty state if no volunteers at all
                        if (volunteerDocs.isEmpty) ...[
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No volunteers available',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Check back later for available volunteers',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
