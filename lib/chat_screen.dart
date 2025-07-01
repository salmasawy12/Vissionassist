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

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController messageController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    initSocket();
    _speech = stt.SpeechToText();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
    _loadMessages();
    platform.setMethodCallHandler((call) async {
      if (call.method == "volumeUpPressed") {
        print("Volume up detected from native code");
        if (!_isListening && !_isResponding) {
          startListening();
        }
      }
    });
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
        'type': 'text',
        'content': data['content'],
        'isUser': false,
        'timestamp': DateTime.now(),
      };

      setState(() {
        messages.add(message);
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
        });

        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('chats')
            .doc(data['senderId'])
            .set({
          'lastMessage': data['content'],
          'timestamp': Timestamp.now(),
          'receiverId': data['senderId'],
        }, SetOptions(merge: true));
      }

      _speak("New message from ${data['senderId']}");
    });

    socket.onDisconnect((_) => print('disconnected from socket server'));
  }

  void _loadMessages() async {
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
        .add(message);

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
    });

    await receiverCollection.collection('chats').doc(senderId).set({
      'lastMessage': text,
      'timestamp': timestamp,
      'receiverId': senderId,
    }, SetOptions(merge: true));

    _speak("Message sent.");

    _waitingForMessage = false;
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
        "Command not recognized. Try saying 'Send message' or 'Read last message'.");
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

    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) {
      _speak("No image captured.");
      return;
    }

    _speak("Sending picture...");

    try {
      final imageBytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final message = {
        'type': 'image',
        'content': base64Image,
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

      _speak("Picture sent.");
    } catch (e) {
      _speak("Failed to send image.");
      print("Encoding error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with ${widget.receiverUid}")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isUser = message['isUser'] ?? false;
                final isImage = message['type'] ==
                    'image'; // Check if the message is an image
                return Row(
                  mainAxisAlignment:
                      isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isUser)
                      CircleAvatar(
                        child: Icon(Icons.smart_toy),
                        backgroundColor: Colors.greenAccent,
                      ),
                    if (!isUser) SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          // Message container
                          Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 10, horizontal: 14),
                            margin: EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Colors.blueAccent.withOpacity(0.7)
                                  : Colors.greenAccent.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: isImage
                                ? Image.memory(
                                    base64Decode(message['content']),
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  )
                                : Text(
                                    message['content'],
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black87),
                                  ),
                          ),
                          // Timestamp
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(DateFormat('h:mm a').format(
                              (message['timestamp'] is Timestamp)
                                  ? (message['timestamp'] as Timestamp).toDate()
                                  : message['timestamp'] ?? DateTime.now(),
                            )),
                          ),
                        ],
                      ),
                    ),
                    if (isUser) SizedBox(width: 8),
                    if (isUser)
                      CircleAvatar(
                        child: Icon(Icons.account_circle),
                        backgroundColor: Colors.blueAccent,
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Color(0xff1370C2),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: () => sendMessage(messageController.text.trim()),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
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
