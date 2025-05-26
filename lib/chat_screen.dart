import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart'; // For formatting timestamps
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatScreen extends StatefulWidget {
  final String username;
  ChatScreen({required this.username});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController messageController = TextEditingController();
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
    _speech = stt.SpeechToText();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
  }

  void sendMessage(String text) {
    if (text.isNotEmpty) {
      setState(() {
        messages.add({
          'type': 'text',
          'content': text,
          'isUser': true,
          'timestamp': DateTime.now(),
        });
      });
      _speak("Message sent.");
    }
    messageController.clear();
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
    // if (spokenText.contains("send picture")) {
    //   _speak("Please take a picture.");
    //   _takeAndSendPicture();
    //   return;
    // }

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

  void _speak(String text) async {
    _isResponding = true;
    await _flutterTts.speak(text);
    await Future.delayed(Duration(seconds: 2));
    _isResponding = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with ${widget.username}")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isUser = message['isUser'];
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
                                ? kIsWeb
                                    ? Image.network(
                                        message[
                                            'content'], // This is the base64 string for web
                                        width: 150,
                                        height: 150,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        message[
                                            'content'], // This works for mobile
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
                            child: Text(
                              DateFormat('h:mm a').format(
                                  message['timestamp'] ?? DateTime.now()),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[700]),
                            ),
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
                    onPressed: () => sendMessage(messageController.text),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? stopListening : startListening,
        backgroundColor: _isListening ? Colors.red : Color(0xff1370C2),
        child: Icon(_isListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }

  // void _takeAndSendPicture() async {
  //   if (kIsWeb) {
  //     // If we're on the web, call the updated function
  //     takeAndSendPictureWeb(
  //       (imageUrl) {
  //         setState(() {
  //           messages.add({
  //             'type': 'image',
  //             'content': imageUrl, // Send the image as base64 string
  //             'isUser': true,
  //             'timestamp': DateTime.now(),
  //           });
  //         });
  //       },
  //       (text) {
  //         _speak(text); // Provide feedback to the user
  //       },
  //     );
  //   } else {
  //     _speak("Taking pictures is only supported on the web for now.");
  //   }
  // }

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
