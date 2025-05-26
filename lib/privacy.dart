import 'package:flutter/material.dart';
import 'package:test1/getstarted.dart';
import 'package:test1/terms.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  _PrivacyScreenState createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late FlutterTts flutterTts;
  late stt.SpeechToText speech;
  bool _isListening = false;

  bool _waitingForProceedConfirmation = false;
  bool _waitingForSkipConfirmation = false;

  final List<String> listItems = [
    "I will not use Vision Assist as a mobility device.",
    "Vision Assist can record, review, and share videos and images for safety, quality, and as further described in the Privacy Policy.",
    "The data, videos, images, and personal information I submit to Vision Assist may be stored and processed in our database.",
  ];

  void _goToSignUp() {
    flutterTts.stop();
    speech.stop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignUpScreen()),
    );
  }

  Future<void> speakAndWait(String text) async {
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.speak(text);
    bool speaking = true;
    flutterTts.setCompletionHandler(() {
      speaking = false;
    });
    while (speaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    speech = stt.SpeechToText();
    _startInteraction();
  }

  Future<void> _startInteraction() async {
    await speakAndWait(
      "Before signing up, please make sure to take note of our privacy policy. "
      "Please say read if you want me to read the list for you or skip if you want to skip.",
    );
    _startListening();
  }

  Future<void> _readListItems() async {
    for (var item in listItems) {
      await speakAndWait(item);
    }
    await speakAndWait(
        "That is all. By proceeding, you agree to the privacy terms recited. Please say proceed to proceed to sign up or read to reread the privacy terms");
    _waitingForProceedConfirmation = true;
    _startListening();
  }

  void _handleVoiceCommand(String command) async {
    setState(() => _isListening = false);

    if (_waitingForSkipConfirmation) {
      if (command.contains("yes")) {
        await speakAndWait(
            "Okay, skipping reading the privacy policy and moving to sign up.");
        _goToSignUp();
      } else if (command.contains("no")) {
        await speakAndWait(
            "Okay, please say read if you want me to read the list for you or skip if you want to skip.");
        _waitingForSkipConfirmation = false;
        _startListening();
      } else {
        await speakAndWait(
            "Sorry, I didn't catch that. Please say yes if you want to skip or no if you want me to read the privacy policy.");
        _startListening();
      }
      return;
    }

    if (_waitingForProceedConfirmation) {
      if (command.contains("proceed")) {
        await speakAndWait("Proceeding to sign up.");
        _goToSignUp();
      } else if (command.contains("read")) {
        await speakAndWait("Reading again now.");
        await _readListItems();
        // Optionally you could reset the flag or reprompt
      } else {
        await speakAndWait("Sorry, I didn't catch that. Please say yes or no.");
        _startListening();
      }
      return;
    }

    // Normal flow before reading
    if (command.contains("read") || command.contains("yes")) {
      await speakAndWait("Reading privacy policy now");
      await _readListItems();
    } else if (command.contains("skip")) {
      _waitingForSkipConfirmation = true;
      await speakAndWait(
          "Are you sure you want to skip reading the privacy policy?");
      _startListening();
    } else {
      await speakAndWait(
          "Sorry, I did not catch that. Please say read or skip.");
      _startListening();
    }
  }

  void _startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      speech.listen(
        onResult: (val) {
          if (val.finalResult) {
            _handleVoiceCommand(val.recognizedWords.toLowerCase());
          }
        },
        localeId: 'en_US',
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/definedlogo.png',
          width: 150,
          height: 80, // You might want to reduce height to fit nicely
          fit: BoxFit.contain,
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      "Privacy and Terms",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "To use Vision Assist, you agree to the following:",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 17),

                    // List item 1
                    _iconTextTile(
                      icon: Icons.accessibility_new_rounded,
                      text:
                          "I will not use Vision Assist as a mobility device.",
                    ),

                    const SizedBox(height: 16),

                    // List item 2
                    _iconTextTile(
                      icon: Icons.photo_camera,
                      text:
                          "Vision Assist can record, review, and share videos and images for safety, quality, and as further described in the Privacy Policy.",
                    ),

                    const SizedBox(height: 16),

                    // List item 3
                    _iconTextTile(
                      icon: Icons.lock,
                      text:
                          "The data, videos, images, and personal information I submit to Vision Assist may be stored and processed in our database.",
                    ),

                    const SizedBox(height: 25),

                    // Terms and Privacy buttons
                    _linkButton(
                      context,
                      "Terms of Service",
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const TermsOfServiceScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Footer and button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Text(
                      "By clicking 'I agree', I agree to everything above and accept the Terms of Service and Privacy Policy.",
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          _goToSignUp();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff1370C2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "I agree",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconTextTile({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey[200],
          child: Icon(icon, color: Colors.black87, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _linkButton(BuildContext context, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Color(0xff1370C2),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(Icons.open_in_new, color: Color(0xff1370C2)),
          ],
        ),
      ),
    );
  }
}
