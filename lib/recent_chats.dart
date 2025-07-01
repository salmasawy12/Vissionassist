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

    // Step 1: Get all available volunteers
    final availableVolunteersSnapshot = await FirebaseFirestore.instance
        .collection('volunteers')
        .where('available', isEqualTo: true)
        .get();

    final List<Map<String, String>> loadedChats = [];

    for (var doc in availableVolunteersSnapshot.docs) {
      final volunteerUsername = doc['username'].toString();

      final messagesSnapshot = await userChatsCollection
          .doc(volunteerUsername)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        final messageData = messagesSnapshot.docs.first.data();

        loadedChats.add({
          "name": volunteerUsername,
          "lastMessage": messageData['content'] ?? '',
          "timestamp": (messageData['timestamp'] as Timestamp)
              .toDate()
              .toLocal()
              .toString()
              .substring(11, 16),
        });
      } else {
        // No messages yet with this volunteer
        loadedChats.add({
          "name": volunteerUsername,
          "lastMessage": "No messages yet",
          "timestamp": "--:--",
        });
      }
    }

    setState(() {
      recentChats = loadedChats;
      print("All available volunteers (with/without chat): $recentChats");
    });
  }

  void _initializeSpeechRecognition() async {
    bool available = await _speech.initialize();
    if (!available) {
      print("Speech recognition is not available.");
    }
  }

  Future _speak(String text) async {
    _isResponding = true;
    await _flutterTts.speak(text);
    _isResponding = false; // Remove delay
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

  void _processVoiceInput() async {
    if (_voiceInput.isEmpty) {
      _speak("No command detected. Try again.");
      return;
    }

    if (_voiceInput.contains("open chat with")) {
      String chatName = _voiceInput.replaceAll("open chat with", "").trim();

      // Query volunteers collection to find the UID for this username
      final querySnapshot = await FirebaseFirestore.instance
          .collection('volunteers')
          .where('username', isEqualTo: chatName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final volunteerDoc = querySnapshot.docs.first;
        final volunteerUid = volunteerDoc.id;

        _openChat(volunteerUid, chatName);
      } else {
        _speak("Volunteer named $chatName not found.");
      }
    } else {
      _speak("I didn't catch that. Please say 'open chat with [name]'.");
    }
  }

  Future<List<Map<String, String>>> _loadVolunteersWithLastMessages(
      String userId) async {
    final availableVolunteersSnapshot = await FirebaseFirestore.instance
        .collection('volunteers')
        .where('available', isEqualTo: true)
        .get();

    final userChatsCollection = FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('chats');

    List<Map<String, String>> loadedChats = [];

    for (var doc in availableVolunteersSnapshot.docs) {
      final volunteerUid = doc.id; // This is UID, the doc ID
      final volunteerUsername = doc['username'].toString();

      final messagesSnapshot = await userChatsCollection
          .doc(volunteerUid) // Use UID here, NOT username
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (messagesSnapshot.docs.isNotEmpty) {
        final messageData = messagesSnapshot.docs.first.data();
        loadedChats.add({
          "name": volunteerUsername,
          "lastMessage": messageData['content'] ?? '',
          "timestamp": (messageData['timestamp'] as Timestamp)
              .toDate()
              .toLocal()
              .toString()
              .substring(11, 16),
        });
      } else {
        loadedChats.add({
          "name": volunteerUsername,
          "lastMessage": "No messages yet",
          "timestamp": "--:--",
        });
      }
    }

    return loadedChats;
  }

  void _openChat(String volunteerUid, String volunteerUsername) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _speak("You must be logged in.");
      return;
    }

    final userChatsCollection = FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('chats');

    final chatDocRef = userChatsCollection.doc(volunteerUid); // Use UID here

    final chatDocSnapshot = await chatDocRef.get();

    if (!chatDocSnapshot.exists) {
      await chatDocRef.set({'createdAt': FieldValue.serverTimestamp()});
      await chatDocRef.collection('messages').add({
        'content': 'Chat started with $volunteerUsername.',
        'sender': user.uid,
        'receiver': volunteerUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    /// ✅ Only speak after chat + message creation is done
    _speak("Opening chat with $volunteerUsername");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverUid: volunteerUid,
          displayName: volunteerUsername,
          receiverRole: 'volunteers',
        ),
      ),
    );
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
        stream: FirebaseFirestore.instance
            .collection('Users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('chats')
            .snapshots(), // Listen for real-time chat updates
        builder: (context, chatSnapshot) {
          if (!chatSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final chatDocs = chatSnapshot.data!.docs;

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('volunteers')
                .where('available', isEqualTo: true)
                .get(),
            builder: (context, volunteerSnapshot) {
              if (!volunteerSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final volunteerDocs = volunteerSnapshot.data!.docs;

// Map usernames → full volunteer data (to use later)
              final Map<String, Map<String, dynamic>> usernameToVolunteer = {
                for (var doc in volunteerDocs)
                  doc['username']: doc.data() as Map<String, dynamic>
              };

              final Map<String, String> uidToUsername = {
                for (var doc in volunteerDocs) doc.id: doc['username'] as String
              };

              final filteredChats = chatDocs.where((doc) {
                return usernameToVolunteer.containsKey(doc.id);
              }).toList();

              return ListView.builder(
                itemCount: volunteerDocs.length,
                itemBuilder: (context, index) {
                  final volunteer = volunteerDocs[index];
                  final volunteerUid = volunteer.id; // Use UID as chat doc id
                  final volunteerUsername = volunteer['username'];

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('chats')
                        .doc(
                            volunteerUid) // <-- Use volunteerUid here, not username
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, messageSnapshot) {
                      String lastMessage = "No messages yet";
                      String timestamp = "--:--";

                      if (messageSnapshot.hasData &&
                          messageSnapshot.data!.docs.isNotEmpty) {
                        final messageData = messageSnapshot.data!.docs.first
                            .data() as Map<String, dynamic>;
                        lastMessage = messageData['content'] ?? '';
                        final timestampValue = messageData['timestamp'];
                        timestamp = (timestampValue != null &&
                                timestampValue is Timestamp)
                            ? timestampValue
                                .toDate()
                                .toLocal()
                                .toString()
                                .substring(11, 16)
                            : "--:--";
                      }

                      return Card(
                        margin:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        elevation: 5,
                        child: ListTile(
                          contentPadding: EdgeInsets.all(10),
                          leading: CircleAvatar(
                            backgroundColor: Color(0xff1370C2),
                            child: Text(volunteerUsername[0].toUpperCase()),
                          ),
                          title: Text(volunteerUsername),
                          subtitle: Text(lastMessage),
                          trailing: Text(
                            timestamp,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          onTap: () => _openChat(volunteerUid,
                              volunteerUsername), // Use UID here too
                        ),
                      );
                    },
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
