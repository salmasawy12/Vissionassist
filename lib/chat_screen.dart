import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart'; // For formatting timestamps
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:audioplayers/audioplayers.dart';

late IO.Socket socket;

class ChatScreen extends StatefulWidget {
  final String receiverUid;
  final String receiverRole; // 'users' or 'volunteers'
  final String displayName;

  ChatScreen({
    required this.receiverUid,
    required this.receiverRole,
    required this.displayName,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const platform = MethodChannel('com.example.volume_button');
  final ImagePicker _picker = ImagePicker();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _waitingForMessage = false;
  bool _isResponding = false;
  bool _commandProcessed = false;
  Timer? _listeningTimer;
  String _spokenText = "";
  FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _voiceCommandRecorder = AudioRecorder();
  String? _voiceCommandRecordingPath;
  bool _isVoiceCommandRecording = false;
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
  final Color userBubbleColor = Color(0xFF1370C2);
  final Color volunteerBubbleColor = Color(0xFFF3F4F6);
  final Color userTextColor = Colors.white;
  final Color volunteerTextColor = Color(0xFF1F2937);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color inputBackgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    initSocket();
    _speech = stt.SpeechToText();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
    _loadMessages();

    _typingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _typingAnimationController, curve: Curves.easeInOut),
    );

    platform.setMethodCallHandler((call) async {
      if (call.method == "volumeUpPressed") {
        print("Volume up detected from native code");
        if (!_isListening && !_isResponding) {
          startListening();
        }
      }
    });
  }

  @override
  void dispose() {
    _typingAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void initSocket() {
    socket = IO.io(
      'http://172.20.10.3:3000', // Replace with your local IP if testing on physical device
      IO.OptionBuilder()
          .setTransports(['websocket']) // for Flutter or Dart VM
          .disableAutoConnect() // disable auto-connect so we call connect() manually
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('connected to socket server');
    });

    socket.on('receive_message', (data) async {
      print('Message received: $data');

      final message = {
        'type': data['type'] ?? 'text',
        'content': data['content'],
        'isUser': false,
        'timestamp': DateTime.now(),
      };

      setState(() {
        messages.add(message);
      });

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

      // Optionally save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('chats')
            .doc(data['senderId']) // sender is now the receiver
            .collection('messages')
            .add({
          ...message,
          'timestamp': Timestamp.now(),
          'read': false, // Mark as unread
        });

        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('chats')
            .doc(data['senderId'])
            .set({
          'lastMessage':
              data['type'] == 'voice' ? "[Voice Message]" : data['content'],
          'timestamp': Timestamp.now(),
          'receiverId': data['senderId'],
        }, SetOptions(merge: true));
      }

      _speak(
          "New ${data['type'] == 'voice' ? 'voice message' : 'message'} from ${data['senderId']}");
    });

    socket.onDisconnect((_) => print('disconnected from socket server'));
  }

  Future<void> _loadMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
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

    // Ensure all existing messages have read field
    await _ensureReadFieldExists();
  }

  Future<void> _markMessagesAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("=== MARKING MESSAGES AS READ ===");
    print("Receiver UID: ${widget.receiverUid}");

    // Get all unread messages from this sender
    final unreadMessages = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
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

  Future<void> _ensureReadFieldExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get all messages without read field
    final messagesWithoutRead = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('chats')
        .doc(widget.receiverUid)
        .collection('messages')
        .get();

    // Add read field to messages that don't have it
    for (var doc in messagesWithoutRead.docs) {
      final data = doc.data();
      if (!data.containsKey('read')) {
        await doc.reference.update({
          'read': data['isUser'] ==
              true, // User's own messages are read, others are unread
        });
      }
    }
  }

  void sendMessage(String text) async {
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      messageController.clear();
    });

    final senderId = user.uid;
    final receiverId = widget.receiverUid;
    print(
        'DEBUG: sendMessage called with senderId=$senderId, receiverId=$receiverId');
    if (senderId == receiverId) {
      print('WARNING: senderId and receiverId are the same! Message not sent.');
      _speak("Cannot send a message to yourself.");
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
    socket.emit('send_message', {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': text,
    });

    // Determine sender and receiver collections
    final senderCollection =
        FirebaseFirestore.instance.collection('Users').doc(senderId);
    final receiverCollection = FirebaseFirestore.instance
        .collection(
            widget.receiverRole == 'volunteers' ? 'volunteers' : 'Users')
        .doc(receiverId);

    // Save to sender's chat
    await senderCollection
        .collection('chats')
        .doc(receiverId)
        .collection('messages')
        .add({
      ...message,
      'read': true, // Mark as read for sender
    });

    await senderCollection.collection('chats').doc(receiverId).set({
      'lastMessage': text,
      'timestamp': timestamp,
      'receiverId': receiverId,
    }, SetOptions(merge: true));

    // Save to receiver's chat
    await receiverCollection
        .collection('chats')
        .doc(senderId)
        .collection('messages')
        .add({
      ...message,
      'isUser': false,
      'read': false, // Mark as unread for receiver
    });

    await receiverCollection.collection('chats').doc(senderId).set({
      'lastMessage': text,
      'timestamp': timestamp,
      'receiverId': senderId,
    }, SetOptions(merge: true));

    _speak("Message sent.");

    _waitingForMessage = false;
  }

  Future<String> _uploadAudioFile(File file, String userId) async {
    final storageRef = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('voice_messages')
        .child('$userId/${DateTime.now().millisecondsSinceEpoch}.m4a');
    await storageRef.putFile(file);
    return await storageRef.getDownloadURL();
  }

  void readLastMessage() {
    if (messages.isNotEmpty) {
      _speak("Last message was: ${messages.last['content']}");
    } else {
      _speak("No messages to read.");
    }
  }

  void startListening() async {
    if (_isListening || _isResponding) return;

    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _commandProcessed = false;
        _spokenText = "";
      });

      _listeningTimer = Timer(Duration(seconds: 5), () {
        stopListening();
        if (_spokenText.isEmpty) {
          _speak("No command detected. Try again.");
        } else {
          processCommand(_spokenText);
        }
      });

      _speech.listen(
        onResult: (result) async {
          if (_isResponding || _commandProcessed) return;
          _spokenText = result.recognizedWords.toLowerCase().trim();
          print("Detected command: $_spokenText");
        },
      );
    }
  }

  void stopListening() {
    _speech.stop();
    _listeningTimer?.cancel();
    setState(() => _isListening = false);
  }

  void processCommand(String spokenText) {
    _commandProcessed = true;

    if (_waitingForMessage) {
      sendMessage(spokenText);
      return;
    }
    if (spokenText.contains("send picture")) {
      _speak("Please take a picture.").then((_) {
        _takeAndSendPicture();
      });
      return;
    }

    if (spokenText.contains("read last message")) {
      readLastMessage();
      return;
    }

    if (spokenText.contains("send message")) {
      _speak("What would you like to say?");
      _waitingForMessage = true;
      return;
    }

    if (spokenText.contains("go back")) {
      _speak("Going back.");
      Navigator.pop(context);
      return;
    }

    _speak(
        "Command not recognized. Try saying 'Send message', 'Send voice message', or 'Read last message'.");
  }

  Future<void> _speak(String text) async {
    _isResponding = true;
    await _flutterTts.speak(text);
    await Future.delayed(Duration(seconds: 2)); // Optional
    _isResponding = false;
  }

  Future<void> _takeAndSendPicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final status = await Permission.camera.status;

    if (status.isDenied || status.isPermanentlyDenied) {
      final result = await Permission.camera.request();

      if (!result.isGranted) {
        _speak(
            "Camera permission denied. Please enable it in your phone settings.");
        openAppSettings(); // Open app settings for the user
        return;
      }
    }

    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (pickedFile == null) {
      _speak("No image captured.");
      return;
    }

    setState(() {
      _isSendingImage = true;
    });
    _speak("Sending picture...");

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
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      final message = {
        'type': 'image',
        'content': imageUrl, // Save URL instead of base64
        'isUser': true,
        'timestamp': Timestamp.now(),
      };

      setState(() {
        messages.add({
          ...message,
          'timestamp': DateTime.now(),
        });
      });

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('chats')
          .doc(widget.receiverUid)
          .collection('messages')
          .add(message);

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('chats')
          .doc(widget.receiverUid)
          .set({
        'lastMessage': "[Image]",
        'timestamp': Timestamp.now(),
      }, SetOptions(merge: true));

      // Also save to volunteer's collection
      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(widget.receiverUid)
          .collection('chats')
          .doc(user.uid)
          .collection('messages')
          .add({
        ...message,
        'isUser': false,
        'read': false,
      });

      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(widget.receiverUid)
          .collection('chats')
          .doc(user.uid)
          .set({
        'lastMessage': "[Image]",
        'timestamp': Timestamp.now(),
      }, SetOptions(merge: true));

      _speak("Picture sent.");
    } catch (e) {
      _speak("Failed to send image.");
      print("Image upload error: $e");
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
        'isUser': true,
        'timestamp': Timestamp.now(),
      };
      setState(() {
        messages.add({
          ...message,
          'timestamp': DateTime.now(),
        });
      });
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('chats')
          .doc(widget.receiverUid)
          .collection('messages')
          .add(message);
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('chats')
          .doc(widget.receiverUid)
          .set({
        'lastMessage': '[Audio]',
        'timestamp': Timestamp.now(),
      }, SetOptions(merge: true));
      // Also save to volunteer's collection
      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(widget.receiverUid)
          .collection('chats')
          .doc(user.uid)
          .collection('messages')
          .add({
        ...message,
        'isUser': false,
        'read': false,
      });
      await FirebaseFirestore.instance
          .collection('volunteers')
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
                            Icons.volunteer_activism,
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
                                  color: volunteerTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Volunteer',
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
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.circle,
                            color: Colors.green,
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
            'Start a conversation!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: volunteerTextColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send a message to begin chatting with your volunteer',
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
              '👋 Say hello!',
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
              if (!isUser) _buildVolunteerAvatar(),
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
                        color: isUser ? userBubbleColor : volunteerBubbleColor,
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
                                    return GestureDetector(
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
                                          color: isUser
                                              ? primaryColor.withOpacity(0.12)
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color:
                                                _currentlyPlayingAudioIndex ==
                                                        index
                                                    ? primaryColor
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
                                              color: primaryColor,
                                              size: 32,
                                            ),
                                            SizedBox(width: 12),
                                            Icon(Icons.graphic_eq,
                                                color: primaryColor, size: 28),
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
                                                            color: isUser
                                                                ? primaryColor
                                                                : Colors
                                                                    .black87,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 16,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (durationText
                                                          .isNotEmpty) ...[
                                                        SizedBox(width: 8),
                                                        Text(
                                                          durationText,
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[700],
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
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
                                                        color: primaryColor,
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
                                    );
                                  },
                                )
                              : Text(
                                  message['content'],
                                  style: TextStyle(
                                    color: isUser
                                        ? userTextColor
                                        : volunteerTextColor,
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
              if (isUser) _buildUserAvatar(),
            ],
          ),
        );
      },
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
        Icons.person,
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
            onTap: () => _takeAndSendPicture(),
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
                  color: volunteerTextColor,
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

  void _checkAndRequestPermissions() async {
    // Request camera permission
    PermissionStatus status = await Permission.camera.request();

    if (status.isGranted) {
      // Proceed with accessing the camera
    } else {
      // Handle permission denied case
      _speak("Camera permission denied. Please enable it in settings.");
    }
  }
}
