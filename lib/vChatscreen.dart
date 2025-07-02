import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

class VolunteerChatScreen extends StatefulWidget {
  final String receiverUid; // blind user UID
  final String displayName;

  const VolunteerChatScreen({
    required this.receiverUid,
    required this.displayName,
  });

  @override
  State<VolunteerChatScreen> createState() => _VolunteerChatScreenState();
}

class _VolunteerChatScreenState extends State<VolunteerChatScreen>
    with TickerProviderStateMixin {
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late IO.Socket socket;
  bool _isTyping = false;
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  bool _isSendingImage = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  bool _isPlayingAudio = false;
  AudioPlayer? _audioPlayer;
  int? _currentlyPlayingAudioIndex;
  Map<int, Duration> _audioDurations = {};

  // Project color scheme
  final Color primaryColor = Color(0xFF1370C2);
  final Color secondaryColor = Color(0xFF1370C2).withOpacity(0.8);
  final Color volunteerBubbleColor = Color(0xFF1370C2);
  final Color userBubbleColor = Color(0xFFF3F4F6);
  final Color volunteerTextColor = Colors.white;
  final Color userTextColor = Color(0xFF1F2937);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color inputBackgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    initSocket();
    loadMessages();

    _typingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _typingAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _typingAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void initSocket() {
    socket = IO.io(
      'http://172.20.10.3:3000', // Replace with your socket server IP
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket.connect();

    socket.onConnect((_) => print("Connected to socket"));

    socket.on('receive_message', (data) {
      print("Socket: received message: $data");

      final message = {
        'type': data['type'] ?? 'text',
        'content': data['content'],
        'isUser': false,
        'timestamp': DateTime.now(),
      };

      setState(() => messages.add(message));

      // Auto-scroll to bottom for new messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Store in Firestore
      final volunteer = FirebaseAuth.instance.currentUser;
      if (volunteer != null) {
        FirebaseFirestore.instance
            .collection('volunteers')
            .doc(volunteer.uid)
            .collection('chats')
            .doc(data['senderId'])
            .collection('messages')
            .add({
          ...message,
          'timestamp': Timestamp.now(),
          'read': false, // Mark as unread
        });

        FirebaseFirestore.instance
            .collection('volunteers')
            .doc(volunteer.uid)
            .collection('chats')
            .doc(data['senderId'])
            .set({
          'lastMessage':
              data['type'] == 'voice' ? "[Voice Message]" : data['content'],
          'timestamp': Timestamp.now(),
          'receiverId': data['senderId'],
        }, SetOptions(merge: true));
      }
    });

    socket.onDisconnect((_) => print("Socket disconnected"));
  }

  void loadMessages() async {
    final volunteer = FirebaseAuth.instance.currentUser;
    if (volunteer == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('volunteers')
        .doc(volunteer.uid)
        .collection('chats')
        .doc(widget.receiverUid)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    setState(() {
      messages.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        messages.add({
          'type': data['type'],
          'content': data['content'],
          'isUser': data['isUser'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        });
      }
    });

    // Auto-scroll to bottom after loading messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    // Mark all unread messages as read when opening chat
    await _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    final volunteer = FirebaseAuth.instance.currentUser;
    if (volunteer == null) return;

    print("=== VOLUNTEER MARKING MESSAGES AS READ ===");
    print("Receiver UID: ${widget.receiverUid}");

    // Get all unread messages from this sender
    final unreadMessages = await FirebaseFirestore.instance
        .collection('volunteers')
        .doc(volunteer.uid)
        .collection('chats')
        .doc(widget.receiverUid)
        .collection('messages')
        .where('isUser', isEqualTo: false)
        .where('read', isEqualTo: false)
        .get();

    print("Found ${unreadMessages.docs.length} unread messages");

    // Mark them as read
    for (var doc in unreadMessages.docs) {
      final data = doc.data();
      print("Marking as read: ${data['content']}");
      await doc.reference.update({'read': true});
    }

    print("=== ALL MESSAGES MARKED AS READ ===");
  }

  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final volunteer = FirebaseAuth.instance.currentUser;
    if (volunteer == null) return;

    final senderId = volunteer.uid;
    final receiverId = widget.receiverUid;
    print(
        'DEBUG: sendMessage called with senderId=[32m$senderId[0m, receiverId=[34m$receiverId[0m');
    if (senderId == receiverId) {
      print('WARNING: senderId and receiverId are the same! Message not sent.');
      // Optionally show a dialog or snackbar here
      return;
    }
    final timestamp = Timestamp.now();

    final message = {
      'type': 'text',
      'content': text,
      'isUser': true,
      'timestamp': timestamp,
      'senderId': senderId,
      'receiverId': receiverId,
    };

    setState(() {
      messages.add(message);
      messageController.clear();
      _isTyping = false;
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Emit through socket
    socket.emit('send_message', {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': text,
    });

    // Save in Firestore
    final senderRef =
        FirebaseFirestore.instance.collection('volunteers').doc(senderId);
    final receiverRef =
        FirebaseFirestore.instance.collection('Users').doc(receiverId);

    await senderRef
        .collection('chats')
        .doc(receiverId)
        .collection('messages')
        .add({
      ...message,
      'read': true, // Mark as read for the volunteer
    });
    await senderRef.collection('chats').doc(receiverId).set({
      'lastMessage': text,
      'timestamp': timestamp,
      'receiverId': receiverId,
    }, SetOptions(merge: true));

    await receiverRef
        .collection('chats')
        .doc(senderId)
        .collection('messages')
        .add({
      ...message,
      'isUser': false,
      'read': false, // Mark as unread for the blind user
    });
    await receiverRef.collection('chats').doc(senderId).set({
      'lastMessage': text,
      'timestamp': timestamp,
      'receiverId': senderId,
    }, SetOptions(merge: true));
  }

  Future<void> _takeAndSendPicture() async {
    final volunteer = FirebaseAuth.instance.currentUser;
    if (volunteer == null) return;

    final ImagePicker _picker = ImagePicker();
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image captured.')),
      );
      return;
    }

    setState(() {
      _isSendingImage = true;
    });

    try {
      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        pickedFile.path,
        minWidth: 800,
        minHeight: 800,
        quality: 75,
      );
      File file;
      if (compressedBytes == null) {
        file = File(pickedFile.path);
      } else {
        final tempDir = await getTemporaryDirectory();
        file = File(
            '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(compressedBytes);
      }

      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(
              '${volunteer.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      final message = {
        'type': 'image',
        'content': imageUrl, // Save URL
        'isUser': true,
        'timestamp': Timestamp.now(),
        'senderId': volunteer.uid,
        'receiverId': widget.receiverUid,
      };

      setState(() {
        messages.add(message);
      });

      // Save in Firestore
      final senderRef = FirebaseFirestore.instance
          .collection('volunteers')
          .doc(volunteer.uid);
      final receiverRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.receiverUid);

      await senderRef
          .collection('chats')
          .doc(widget.receiverUid)
          .collection('messages')
          .add({
        ...message,
        'read': true,
      });
      await senderRef.collection('chats').doc(widget.receiverUid).set({
        'lastMessage': '[Image]',
        'timestamp': Timestamp.now(),
        'receiverId': widget.receiverUid,
      }, SetOptions(merge: true));

      await receiverRef
          .collection('chats')
          .doc(volunteer.uid)
          .collection('messages')
          .add({
        ...message,
        'isUser': false,
        'read': false,
      });
      await receiverRef.collection('chats').doc(volunteer.uid).set({
        'lastMessage': '[Image]',
        'timestamp': Timestamp.now(),
        'receiverId': volunteer.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image.')),
      );
      print('Image upload error: $e');
    } finally {
      setState(() {
        _isSendingImage = false;
      });
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      setState(() => _isRecording = true);
      final tempDir = await getTemporaryDirectory();
      _audioPath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: _audioPath!);
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    setState(() => _isRecording = false);
    final path = await _audioRecorder.stop();
    if (path == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSendingImage = true);
    try {
      final file = File(path);
      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('voice_messages')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await storageRef.putFile(file);
      final audioUrl = await storageRef.getDownloadURL();
      final message = {
        'type': 'audio',
        'content': audioUrl,
        'isUser': false,
        'timestamp': Timestamp.now(),
      };
      setState(() {
        messages.add({
          ...message,
          'timestamp': DateTime.now(),
        });
      });
      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(user.uid)
          .collection('chats')
          .doc(widget.receiverUid)
          .collection('messages')
          .add(message);
      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(user.uid)
          .collection('chats')
          .doc(widget.receiverUid)
          .set({
        'lastMessage': '[Audio]',
        'timestamp': Timestamp.now(),
      }, SetOptions(merge: true));
      // Also save to user's collection
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.receiverUid)
          .collection('chats')
          .doc(user.uid)
          .collection('messages')
          .add({
        ...message,
        'isUser': true,
        'read': false,
      });
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.receiverUid)
          .collection('chats')
          .doc(user.uid)
          .set({
        'lastMessage': '[Audio]',
        'timestamp': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Audio upload error: $e');
    } finally {
      setState(() => _isSendingImage = false);
    }
  }

  Future<void> _playAudio(String url, int index) async {
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
      await _audioPlayer!.dispose();
    }
    setState(() => _currentlyPlayingAudioIndex = index);
    _audioPlayer = AudioPlayer();
    await _audioPlayer!.play(UrlSource(url));
    _audioPlayer!.onPlayerComplete.listen((event) {
      setState(() => _currentlyPlayingAudioIndex = null);
    });
  }

  Future<void> _fetchAudioDuration(String url, int index) async {
    if (_audioDurations.containsKey(index)) return;
    final player = AudioPlayer();
    try {
      await player.setSource(UrlSource(url));
      final duration = await player.getDuration();
      if (duration != null) {
        setState(() {
          _audioDurations[index] = duration;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      await player.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [backgroundColor, backgroundColor.withOpacity(0.8)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Modern App Bar
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.displayName,
                                style: TextStyle(
                                  color: userTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Blind User',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.circle,
                            color: Colors.blue,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Messages Area
                  Expanded(
                    child: messages.isEmpty
                        ? _buildEmptyState()
                        : _buildMessagesList(),
                  ),

                  // Input Area
                  _buildInputArea(),
                ],
              ),
            ),
          ),
        ),
        if (_isSendingImage)
          ModalBarrier(
              dismissible: false, color: Colors.black.withOpacity(0.2)),
        if (_isSendingImage)
          Center(
            child: Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Sending image...',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Start helping!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: userTextColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send a message to begin assisting this user',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '🤝 Ready to help!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isUser = message['isUser'] ?? false;
        final isImage = message['type'] == 'image';
        final isAudio = message['type'] == 'audio';
        final timestamp = message['timestamp'] is Timestamp
            ? message['timestamp'].toDate()
            : message['timestamp'] ?? DateTime.now();

        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) _buildUserAvatar(),
              if (!isUser) SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isUser ? volunteerBubbleColor : userBubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(isUser ? 20 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isImage
                          ? (message['content'] != null &&
                                  message['content']
                                      .toString()
                                      .startsWith('http')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    message['content'],
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    base64Decode(message['content']),
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ))
                          : isAudio
                              ? Builder(
                                  builder: (context) {
                                    _fetchAudioDuration(
                                        message['content'], index);
                                    final duration = _audioDurations[index];
                                    String durationText = duration != null
                                        ? duration.inMinutes > 0
                                            ? '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'
                                            : '0:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'
                                        : '';
                                    final bool sentByUser =
                                        message['isUser'] == true;
                                    final bubbleColor = sentByUser
                                        ? Color(0xFF1370C2)
                                        : Colors.grey[200];
                                    final iconColor = sentByUser
                                        ? Colors.white
                                        : Color(0xFF1370C2);
                                    return Align(
                                      alignment: sentByUser
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _currentlyPlayingAudioIndex == index
                                                ? null
                                                : _playAudio(
                                                    message['content'], index),
                                        child: Container(
                                          constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: bubbleColor,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color:
                                                  _currentlyPlayingAudioIndex ==
                                                          index
                                                      ? Color(0xFF1370C2)
                                                      : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _currentlyPlayingAudioIndex ==
                                                        index
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_fill,
                                                color: iconColor,
                                                size: 32,
                                              ),
                                              SizedBox(width: 12),
                                              Icon(Icons.graphic_eq,
                                                  color: iconColor, size: 28),
                                              SizedBox(width: 12),
                                              Flexible(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            'Voice message',
                                                            style: TextStyle(
                                                              color: sentByUser
                                                                  ? Colors.white
                                                                  : Color(
                                                                      0xFF1370C2),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 16,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (durationText
                                                            .isNotEmpty) ...[
                                                          SizedBox(width: 8),
                                                          Text(
                                                            durationText,
                                                            style: TextStyle(
                                                              color: sentByUser
                                                                  ? Colors
                                                                      .white70
                                                                  : Colors.grey[
                                                                      700],
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    if (_currentlyPlayingAudioIndex ==
                                                        index)
                                                      Text(
                                                        'Playing...',
                                                        style: TextStyle(
                                                          color: sentByUser
                                                              ? Colors.white
                                                              : Color(
                                                                  0xFF1370C2),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Text(
                                  message['content'],
                                  style: TextStyle(
                                    color: isUser
                                        ? volunteerTextColor
                                        : userTextColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                    ),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('h:mm a').format(timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isUser) SizedBox(width: 8),
              if (isUser) _buildVolunteerAvatar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.visibility,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildVolunteerAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.volunteer_activism,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inputBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Camera Button
          GestureDetector(
            onTap: _takeAndSendPicture,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                color: primaryColor,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: 12),
          // Record Button
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressUp: _stopAndSendRecording,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red[100] : backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                color: _isRecording ? Colors.red : primaryColor,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: 12),

          // Text Input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                controller: messageController,
                style: TextStyle(
                  fontSize: 16,
                  color: userTextColor,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _isTyping = value.isNotEmpty;
                  });
                },
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    sendMessage(value.trim());
                  }
                },
              ),
            ),
          ),
          SizedBox(width: 12),

          // Send Button
          GestureDetector(
            onTap: () {
              if (messageController.text.trim().isNotEmpty) {
                sendMessage(messageController.text.trim());
              }
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isTyping ? primaryColor : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isTyping
                    ? [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isTyping ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
