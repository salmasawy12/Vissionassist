import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:gradproj/chat_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:test1/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ChatDetailScreen extends StatefulWidget {
  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  static const platform = MethodChannel('com.example.volume_button');

  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _voiceInput = "";

  bool _waitingForMessage = false;
  bool _isResponding = false;
  bool _commandProcessed = false;
  Timer? _listeningTimer;

  // Mock list of recent chats with timestamp
  List<Map<String, String>> recentChats = [];

  @override
  void initState() {
    super.initState();
    _initializeSpeechRecognition();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
    loadChatsFromFirestore();
    platform.setMethodCallHandler((call) async {
      if (call.method == "volumeUpPressed") {
        print("Volume up detected from native code");
        if (!_isListening && !_isResponding) {
          _startListening();
        }
      }
    });
  }

  void stopListening() {
    _speech.stop();
    _listeningTimer?.cancel();
    setState(() => _isListening = false);
  }

  void _showAddContactDialog() {
    String newContactName = "";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add New Contact"),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: "Enter contact name"),
            onChanged: (value) {
              newContactName = value.trim();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close dialog
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (newContactName.isNotEmpty) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    _speak("You must be logged in.");
                    return;
                  }

                  // Create an empty chat document
                  final chatRef = FirebaseFirestore.instance
                      .collection('Users')
                      .doc(user.uid)
                      .collection('chats')
                      .doc(newContactName);

// Create empty chat doc
                  await chatRef
                      .set({'createdAt': FieldValue.serverTimestamp()});

// Add initial message
                  await chatRef.collection('messages').add({
                    'content': 'Chat started with $newContactName.',
                    'sender': user.uid,
                    'receiver': newContactName,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _speak("Contact $newContactName added.");
                  loadChatsFromFirestore(); // Refresh chat list
                } else {
                  _speak("Name cannot be empty.");
                }
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, String>>> _buildRecentChats(
      List<QueryDocumentSnapshot> chatDocs,
      CollectionReference userChatsCollection) async {
    List<Map<String, String>> loadedChats = [];

    for (var doc in chatDocs) {
      final chatId = doc.id;

      final messagesSnapshot = await userChatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        final messageData =
            messagesSnapshot.docs.first.data() as Map<String, dynamic>;

        loadedChats.add({
          "name": chatId,
          "lastMessage": messageData['content'] ?? '',
          "timestamp": (messageData['timestamp'] as Timestamp)
              .toDate()
              .toLocal()
              .toString()
              .substring(11, 16),
        });
      }
    }

    return loadedChats;
  }

  Future<void> loadChatsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not logged in.");
      return;
    }

    final userChatsCollection = FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('chats');

    final chatDocs = await userChatsCollection.get();

    print("Found ${chatDocs.docs.length} chats.");

    List<Map<String, String>> loadedChats = [];

    for (var doc in chatDocs.docs) {
      final chatId = doc.id;
      print("Loading chat with $chatId");

      final messagesSnapshot = await userChatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        final messageData = messagesSnapshot.docs.first.data();
        print("Last message in $chatId: ${messageData['content']}");

        loadedChats.add({
          "name": chatId,
          "lastMessage": messageData['content'] ?? '',
          "timestamp": (messageData['timestamp'] as Timestamp)
              .toDate()
              .toLocal()
              .toString()
              .substring(11, 16),
        });
      } else {
        print("No messages in chat $chatId");
      }
    }

    setState(() {
      recentChats = loadedChats;
      print("Recent chats set: $recentChats");
    });
  }

  void _initializeSpeechRecognition() async {
    bool available = await _speech.initialize();
    if (!available) {
      print("Speech recognition is not available.");
    }
  }

  void _speak(String text) async {
    _isResponding = true;
    await _flutterTts.speak(text);
    await Future.delayed(Duration(seconds: 2));
    _isResponding = false;
  }

  void _startListening() async {
    // Prevent starting a new listening session if we're already listening or responding
    if (_isListening || _isResponding) return;

    // Initialize the speech-to-text service
    bool available = await _speech.initialize();
    if (available) {
      // Update the state to reflect that we're now listening
      setState(() {
        _isListening = true;
        _commandProcessed = false;
        _voiceInput = "";
      });

      // Set a timer to stop listening after 5 seconds
      _listeningTimer = Timer(Duration(seconds: 5), () {
        _stopListening();
        if (_voiceInput.isEmpty) {
          _speak("No command detected. Try again.");
        } else {
          _processVoiceInput(); // Process the command after 5 seconds
        }
      });

      // Start listening for speech and capturing the result
      _speech.listen(
        onResult: (result) async {
          // If we are already responding or have processed a command, don't process further
          if (_isResponding || _commandProcessed) return;

          // Store the recognized voice input and print the result
          _voiceInput = result.recognizedWords.toLowerCase().trim();
          print("Detected command: $_voiceInput");
        },
      );
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _processVoiceInput() {
    if (_voiceInput.isEmpty) {
      _speak("No command detected. Try again.");
      return;
    }

    // Check if the voice command contains "open chat with"
    if (_voiceInput.contains("open chat with")) {
      String chatName = _voiceInput.replaceAll("open chat with", "").trim();
      _openChat(chatName);
    } else {
      _speak("I didn't catch that. Please say 'open chat with [name]'.");
    }
  }

  void _openChat(String chatName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _speak("You must be logged in.");
      return;
    }

    final userChatsCollection = FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('chats');

    final chatDocs = await userChatsCollection.get();

    bool chatFound = false;

    for (var doc in chatDocs.docs) {
      final docId = doc.id;
      if (docId.toLowerCase() == chatName.toLowerCase()) {
        _speak("Opening chat with $chatName");

        // Stop listening after 5 seconds
        Timer(Duration(seconds: 5), () {
          _stopListening();
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(username: docId),
          ),
        );

        chatFound = true;
        break;
      }
    }

    if (!chatFound) {
      _speak("Chat with $chatName not found.");
      _stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    final userChatsCollection = FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('chats');

    return Scaffold(
      appBar: AppBar(title: Text('Recent Chats')),
      body: StreamBuilder<QuerySnapshot>(
        stream: userChatsCollection.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final chatDocs = snapshot.data!.docs;

          if (chatDocs.isEmpty) {
            return Center(child: Text("No chats found."));
          }

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              final chatDoc = chatDocs[index];
              final chatId = chatDoc.id;

              return StreamBuilder<QuerySnapshot>(
                stream: userChatsCollection
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, messageSnapshot) {
                  String lastMessage = "";
                  String timestamp = "";

                  if (messageSnapshot.hasData &&
                      messageSnapshot.data!.docs.isNotEmpty) {
                    final messageData = messageSnapshot.data!.docs.first.data()
                        as Map<String, dynamic>;

                    lastMessage = messageData['content'] ?? '';
                    timestamp = (messageData['timestamp'] as Timestamp)
                        .toDate()
                        .toLocal()
                        .toString()
                        .substring(11, 16);
                  }

                  return Card(
                    margin:
                        EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    elevation: 5,
                    child: ListTile(
                      contentPadding: EdgeInsets.all(10),
                      leading: CircleAvatar(
                        backgroundColor: Color(0xff1370C2),
                        child: Text(chatId[0].toUpperCase()),
                      ),
                      title: Text(chatId),
                      subtitle: Text(lastMessage),
                      trailing: Text(
                        timestamp,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () => _openChat(chatId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "add_contact",
            backgroundColor: Color(0xff1370C2),
            onPressed: _showAddContactDialog,
            child: Icon(Icons.person_add),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}
