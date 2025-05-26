import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:gradproj/chat_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:test1/chat_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _voiceInput = "";

  bool _waitingForMessage = false;
  bool _isResponding = false;
  bool _commandProcessed = false;
  Timer? _listeningTimer;

  // Mock list of recent chats with timestamp
  List<Map<String, String>> recentChats = [
    {
      "name": "Alice",
      "lastMessage": "Hey, how are you?",
      "timestamp": "10:30 AM"
    },
    {
      "name": "Bob",
      "lastMessage": "Are we still meeting later?",
      "timestamp": "9:45 AM"
    },
    {
      "name": "Charlie",
      "lastMessage": "I sent the files.",
      "timestamp": "8:50 AM"
    },
    {
      "name": "David",
      "lastMessage": "Let's grab lunch tomorrow.",
      "timestamp": "7:15 AM"
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeSpeechRecognition();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
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

  void _openChat(String chatName) {
    // Check if chat name exists in the recent chats
    bool chatFound = false;
    for (var chat in recentChats) {
      if (chat['name']!.toLowerCase() == chatName.toLowerCase()) {
        // Speak that we are opening the chat
        _speak("Opening chat with $chatName");

        // Stop listening after 5 seconds
        Timer(Duration(seconds: 5), () {
          _stopListening();
        });

        // Navigate to the ChatScreen for the selected chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(username: chat['name']!),
          ),
        );
        chatFound = true;
        break;
      }
    }

    // If chat was not found, provide feedback
    if (!chatFound) {
      _speak("Chat with $chatName not found.");
      _stopListening(); // Stop listening if no chat found
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recent Chats')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: recentChats.length,
              itemBuilder: (context, index) {
                var chat = recentChats[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  elevation: 5,
                  child: ListTile(
                    contentPadding: EdgeInsets.all(10),
                    leading: CircleAvatar(
                      backgroundColor: Color(0xff1370C2),
                      child: Text(chat['name']![0]),
                    ),
                    title: Text(chat['name']!),
                    subtitle: Text(chat['lastMessage']!),
                    trailing: Text(
                      chat['timestamp']!,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () => _openChat(chat['name']!),
                  ),
                );
              },
            ),
          ),
          if (_voiceInput.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Detected command: $_voiceInput",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? _stopListening : _startListening,
        backgroundColor: _isListening ? Colors.red : Color(0xff1370C2),
        child: Icon(_isListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }
}
