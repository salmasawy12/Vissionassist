import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:test1/recent_chats.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late FlutterTts flutterTts;
  late stt.SpeechToText speech;
  bool commandHandled = false;
  String lastWords = '';

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    speech = stt.SpeechToText();

    flutterTts.setCompletionHandler(() {
      if (!commandHandled) _startListening();
    });

    _speakWelcome();
  }

  Future<void> _speakWelcome() async {
    commandHandled = false;
    await flutterTts.stop();
    await flutterTts.speak(
      "Welcome to sign up. If you're new to our community, say sign up. If you're a member, say log in.",
    );
  }

  Future<void> _startListening() async {
    bool available = await speech.initialize(
      onError: (err) => print('Speech error: $err'),
    );

    if (available) {
      speech.listen(
        onResult: (val) async {
          if (val.finalResult && !commandHandled) {
            lastWords = val.recognizedWords.toLowerCase();
            setState(() => commandHandled = true);
            await _processCommand(lastWords);
          }
        },
      );
    }
  }

  Future<void> _processCommand(String command) async {
    await flutterTts.stop();
    await speech.stop();

    if (command.contains('sign up')) {
      await flutterTts.speak("Signing you up");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatDetailScreen()),
      );
    } else if (command.contains('login')) {
      await flutterTts.speak("Logging you in");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatDetailScreen()),
      );
    } else {
      commandHandled = false;
      await flutterTts.speak(
        "Sorry, I didn't understand. Please say sign up or log in.",
      );
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/definedlogo.png',
          width: 150,
          height: 80,
          fit: BoxFit.contain,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            const Text(
              'Get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 23),
            const Text(
              'New to our community? Join now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Login Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ChatDetailScreen(), // Navigate to ChatScreen
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff1370C2),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: const Text(
                'Sign up',
                style: TextStyle(fontSize: 22, color: Colors.white),
              ),
            ),
            SizedBox(
              height: 40,
            ),
            const Text(
              'Already a member?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Login Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ChatDetailScreen(), // Navigate to ChatScreen
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 214, 218, 222),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: const Text(
                'Log in',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
