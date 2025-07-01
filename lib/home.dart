// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:test1/chat_screen.dart'; // <-- add this

// class HomeScreen extends StatefulWidget {
//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   final List<String> contacts = ["Alice", "Bob", "Charlie", "Emma", "David"];
//   late stt.SpeechToText _speech;
//   bool _isListening = false;
//   bool _commandProcessed = false;
//   Timer? _listeningTimer;
//   String _spokenText = ""; // Stores the full spoken command
//   FlutterTts _flutterTts = FlutterTts();

//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _initializeTTS();
//   }

//   void _initializeTTS() async {
//     await _flutterTts.setLanguage("en-US");
//     await _flutterTts.setSpeechRate(0.5);
//     await _flutterTts.setVolume(1.0);
//     await _flutterTts.setPitch(1.0);
//   }

//   Future<bool> _checkMicPermission() async {
//     try {
//       var status = await Permission.microphone.status;
//       if (!status.isGranted) {
//         var result = await Permission.microphone.request();
//         return result.isGranted;
//       }
//       return true;
//     } catch (e) {
//       print("Permission error: $e");
//       _speak("Failed to check microphone permission.");
//       return false;
//     }
//   }

//   void startListening() async {
//     if (_isListening) {
//       print("Already listening");
//       return;
//     }

//     bool hasPermission = await _checkMicPermission();
//     if (!hasPermission) {
//       _speak("Microphone permission is required to start listening.");
//       return;
//     }

//     print("Initializing speech...");
//     bool available = await _speech.initialize(
//       onStatus: (val) => print('Speech status: $val'),
//       onError: (val) => print('Speech error: $val'),
//     );

//     print("Speech available: $available");

//     if (available) {
//       setState(() {
//         _isListening = true;
//         _commandProcessed = false;
//         _spokenText = "";
//       });

//       _listeningTimer = Timer(Duration(seconds: 5), () {
//         stopListening();
//         if (_spokenText.isEmpty) {
//           _speak("No command detected. Try again.");
//         } else {
//           processCommand(_spokenText);
//         }
//       });

//       _speech.listen(
//         onResult: (result) async {
//           if (_commandProcessed) return;
//           setState(() {
//             _spokenText = result.recognizedWords.toLowerCase().trim();
//           });
//           print("Detected command: $_spokenText");
//         },
//       );

//       print("Started listening");
//     } else {
//       _speak("Speech recognition is not available on this device.");
//     }
//   }

//   void stopListening() {
//     print("Stopping listening");
//     _speech.stop();
//     _listeningTimer?.cancel();
//     setState(() {
//       _isListening = false;
//     });
//     print("Stopped listening");
//   }

//   void processCommand(String spokenText) {
//     _commandProcessed = true;

//     if (spokenText.contains("open chat with")) {
//       String name = spokenText.replaceAll("open chat with", "").trim();
//       _openChat(name);
//       return;
//     }

//     _speak("Command not recognized. Try saying 'Open chat with Alice'.");
//   }

//   void _openChat(String name) {
//     name = name.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();

//     String? matchedContact = contacts.firstWhere(
//       (contact) => contact.toLowerCase() == name,
//       orElse: () => "",
//     );

//     if (matchedContact.isNotEmpty) {
//       _speak("Opening chat with $matchedContact.");
//      Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (context) => ChatScreen(
//       receiverUid: docId,
//       receiverRole: 'users', // or 'volunteers', depending on how you structured chats
//       displayName: docId, // or load display name from Firestore if needed
//     ),
//   ),
// );
//     } else {
//       _speak("Contact '$name' not found. Try again.");
//     }
//   }

//   void _speak(String text) async {
//     await _flutterTts.speak(text);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Home")),
//       body: ListView.builder(
//         itemCount: contacts.length,
//         itemBuilder: (context, index) {
//           return ListTile(
//             title: Text(contacts[index]),
//             leading: CircleAvatar(
//               child: Text(contacts[index][0]),
//             ),
//             onTap: () {
//               // Navigate to chat screen on tap if needed
//             },
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _isListening ? stopListening : startListening,
//         child: Icon(_isListening ? Icons.mic_off : Icons.mic),
//       ),
//     );
//   }
// }
