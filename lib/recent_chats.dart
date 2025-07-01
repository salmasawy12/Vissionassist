import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:gradproj/chat_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:test1/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// Recent Chats screen for blind users.
/// Shows all available volunteers, last message, and allows starting/continuing chats.
class ChatDetailScreen extends StatefulWidget {
  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  // Accessibility and voice control
  final stt.SpeechToText _speech = stt.SpeechToText();
  static const platform = MethodChannel('com.example.volume_button');
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _voiceInput = "";
  bool _isResponding = false;
  bool _commandProcessed = false;
  Timer? _listeningTimer;

  @override
  void initState() {
    super.initState();
    _initializeSpeechRecognition();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
    // Listen for volume button to trigger voice input
    platform.setMethodCallHandler((call) async {
      if (call.method == "volumeUpPressed") {
        if (!_isListening && !_isResponding) {
          _startListening();
        }
      }
    });
  }

  /// Initialize speech recognition
  void _initializeSpeechRecognition() async {
    bool available = await _speech.initialize();
    if (!available) {
      print("Speech recognition is not available.");
    }
  }

  /// Speak a message using TTS
  Future _speak(String text) async {
    _isResponding = true;
    await _flutterTts.speak(text);
    _isResponding = false;
  }

  /// Show dialog to add a new contact (by volunteer username)
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
              onPressed: () => Navigator.pop(context),
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
                  // Find volunteer by username
                  final querySnapshot = await FirebaseFirestore.instance
                      .collection('volunteers')
                      .where('username', isEqualTo: newContactName)
                      .limit(1)
                      .get();
                  if (querySnapshot.docs.isEmpty) {
                    _speak("Volunteer not found.");
                    return;
                  }
                  final volunteerDoc = querySnapshot.docs.first;
                  final volunteerUid = volunteerDoc.id;
                  // Create chat doc if not exists
                  final chatRef = FirebaseFirestore.instance
                      .collection('Users')
                      .doc(user.uid)
                      .collection('chats')
                      .doc(volunteerUid);
                  if (!(await chatRef.get()).exists) {
                    await chatRef
                        .set({'createdAt': FieldValue.serverTimestamp()});
                    await chatRef.collection('messages').add({
                      'content': 'Chat started with $newContactName.',
                      'sender': user.uid,
                      'receiver': volunteerUid,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  }
                  Navigator.pop(context);
                  _speak("Contact $newContactName added.");
                  setState(() {}); // Refresh UI
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

  /// Start listening for a voice command
  void _startListening() async {
    if (_isListening || _isResponding) return;
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _commandProcessed = false;
        _voiceInput = "";
      });
      _listeningTimer = Timer(Duration(seconds: 5), () {
        _stopListening();
        if (_voiceInput.isEmpty) {
          _speak("No command detected. Try again.");
        } else {
          _processVoiceInput();
        }
      });
      _speech.listen(
        onResult: (result) async {
          if (_isResponding || _commandProcessed) return;
          _voiceInput = result.recognizedWords.toLowerCase().trim();
        },
      );
    }
  }

  /// Stop listening for voice
  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  /// Process the recognized voice command
  void _processVoiceInput() async {
    if (_voiceInput.isEmpty) {
      _speak("No command detected. Try again.");
      return;
    }
    if (_voiceInput.contains("open chat with")) {
      String chatName = _voiceInput.replaceAll("open chat with", "").trim();
      // Find volunteer by username
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

  /// Open a chat with the given volunteer UID
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
    final chatDocRef = userChatsCollection.doc(volunteerUid);
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
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('volunteers')
            .where('available', isEqualTo: true)
            .get(),
        builder: (context, volunteerSnapshot) {
          if (!volunteerSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final volunteerDocs = volunteerSnapshot.data!.docs;
          if (volunteerDocs.isEmpty) {
            return Center(child: Text('No available volunteers.'));
          }
          return ListView.builder(
            itemCount: volunteerDocs.length,
            itemBuilder: (context, index) {
              final volunteer = volunteerDocs[index];
              final volunteerUid = volunteer.id;
              final volunteerUsername = volunteer['username'] ?? 'Unknown';
              final isAvailable = volunteer['available'] == true;
              return StreamBuilder<QuerySnapshot>(
                stream: userChatsCollection
                    .doc(volunteerUid)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, messageSnapshot) {
                  String lastMessage = "No messages yet";
                  String timestamp = "--:--";
                  if (messageSnapshot.hasData &&
                      messageSnapshot.data!.docs.isNotEmpty) {
                    final messageData = messageSnapshot.data!.docs.first.data()
                        as Map<String, dynamic>;
                    lastMessage = messageData['content'] ?? '';
                    final timestampValue = messageData['timestamp'];
                    timestamp =
                        (timestampValue != null && timestampValue is Timestamp)
                            ? timestampValue
                                .toDate()
                                .toLocal()
                                .toString()
                                .substring(11, 16)
                            : "--:--";
                  }
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    elevation: 5,
                    child: ListTile(
                      contentPadding: EdgeInsets.all(10),
                      leading: CircleAvatar(
                        backgroundColor:
                            isAvailable ? Color(0xff1370C2) : Colors.grey,
                        child: Text(volunteerUsername[0].toUpperCase()),
                      ),
                      title: Row(
                        children: [
                          Text(volunteerUsername),
                          SizedBox(width: 8),
                          if (!isAvailable)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Unavailable',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.red.shade800),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(lastMessage),
                      trailing: Text(
                        timestamp,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () => _openChat(volunteerUid, volunteerUsername),
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
