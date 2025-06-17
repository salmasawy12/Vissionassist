import 'package:flutter/material.dart';
import 'package:test1/getstarted.dart';
import 'package:test1/terms.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  _PrivacyScreenState createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  static const volumeChannel = MethodChannel('com.example.volume_button');
  late FlutterTts flutterTts;
  late stt.SpeechToText speech;
  bool isTtsSpeaking = false;
  bool isListening = false;
  String lastWords = '';
  bool commandHandled = false;

  // Track if we're waiting for initial "read" or "skip"
  bool waitingForReadOrSkip = true;

  // Track if we asked "Are you sure you want to skip?" and wait confirmation
  bool waitingForSkipConfirmation = false;

  @override
  void initState() {
    super.initState();

    flutterTts = FlutterTts();
    speech = stt.SpeechToText();
    flutterTts.awaitSpeakCompletion(true);

    flutterTts.setStartHandler(() {
      setState(() {
        isTtsSpeaking = true;
      });
      print("TTS started");
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        isTtsSpeaking = false;
      });
      print("TTS completed");
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        isTtsSpeaking = false;
      });
      print("TTS canceled");
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        isTtsSpeaking = false;
      });
      print("TTS error: $msg");
    });

    volumeChannel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUpPressed') {
        print('Volume up button pressed');
        if (isTtsSpeaking) {
          print('TTS is speaking; mic will not start.');
          return;
        }

// Always reset commandHandled so new command can be processed
        commandHandled = false;

        if (!speech.isListening) {
          print("Mic is not listening. Attempting to start...");
          await speech.stop();

          Future.delayed(Duration(milliseconds: 500), () {
            if (!isTtsSpeaking) _startListening();
          });
        } else {
          print("Mic is already listening");
        }
      }
    });

    _speakPrivacyIntro();
  }

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
      MaterialPageRoute(builder: (context) => const SignUpPage()),
    );
  }

  Future _speakPrivacyIntro() async {
    commandHandled = false;
    waitingForReadOrSkip = true;
    waitingForSkipConfirmation = false;
    await flutterTts.stop();
    await flutterTts.speak(
      "Before signing up, please make sure to take note of our privacy policy. "
      "Please say read if you want me to read the list for you or skip if you want to skip.",
    );
  }

  void _startListening() async {
    print('Starting to listen...');

    bool available = await speech.initialize(
      onError: (val) {
        print('Speech error: $val');
        setState(() => isListening = false);
      },
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'listening') {
          setState(() => isListening = true);
        } else if (status == 'notListening') {
          setState(() => isListening = false);
        }
      },
    );

    if (available) {
      speech.listen(
        onResult: (val) async {
          if (val.finalResult && !commandHandled) {
            setState(() {
              lastWords = val.recognizedWords.toLowerCase();
              isListening = false;
            });
            await _processResult(lastWords);
          }
        },
        listenMode: stt.ListenMode.confirmation,
        pauseFor: Duration(seconds: 3),
        partialResults: false,
      );
    } else {
      print('Speech recognition unavailable');
    }
  }

  Future<void> _processResult(String recognized) async {
    print('Processing recognized: $recognized');
    setState(() {
      isListening = false;
    });

    if (commandHandled) {
      print('Command already handled, ignoring.');
      return;
    }

    if (waitingForReadOrSkip) {
      // Waiting for "read" or "skip"
      if (recognized.contains('read')) {
        commandHandled = true;
        waitingForReadOrSkip = false;
        await flutterTts.speak("Reading privacy policy now.");
        await _waitForTtsComplete();
        await Future.delayed(Duration(milliseconds: 300));

        for (var item in listItems) {
          print("Speaking item: $item");
          await flutterTts.speak(item);
          await _waitForTtsComplete();
          await Future.delayed(Duration(milliseconds: 300));
        }

        // Prompt user to agree/disagree
        await flutterTts.speak(
            "Please say agree if you accept or cancel if you wish to cancel.");
        waitingForReadOrSkip = false;
        waitingForSkipConfirmation = false;
        commandHandled = false;
        return;
      } else if (recognized.contains('skip')) {
        commandHandled = true;
        waitingForReadOrSkip = false;
        waitingForSkipConfirmation = true;
        await speech.stop();
        await flutterTts.stop();

        await flutterTts.speak(
            "By skipping, you automatically agree to our privacy terms. Are you sure you want to skip?");
        commandHandled = false; // wait for yes/no after skip prompt
        return;
      } else {
        // unrecognized, prompt retry
        await speech.stop();
        await flutterTts.stop();
        await flutterTts.speak(
            "Sorry, please say read if you want me to read the list or skip if you want to skip.");
        commandHandled = false;
        return;
      }
    } else if (waitingForSkipConfirmation) {
      // After "Are you sure you want to skip?" question, expect yes or no
      if (recognized.contains('yes') || recognized.contains('agree')) {
        commandHandled = true;
        waitingForSkipConfirmation = false;
        await speech.stop();
        await flutterTts.stop();
        await flutterTts.speak("Okay. Proceeding to sign up.");
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          _goToSignUp();
        }
      } else if (recognized.contains('no') || recognized.contains('disagree')) {
        commandHandled = true;
        waitingForSkipConfirmation = false;
        waitingForReadOrSkip = true;
        await speech.stop();
        await flutterTts.stop();
        await flutterTts.speak(
            "No problem, please say read if you want me to read the list or skip if you want to skip.");
        commandHandled = false;
      } else {
        // unrecognized after skip confirmation
        await speech.stop();
        await flutterTts.stop();
        await flutterTts.speak(
            "Sorry, please say yes if you want to skip or no if you want me to read the list.");
        commandHandled = false;
      }
    } else {
      // After reading list, waiting for agree/disagree
      if (recognized.contains('agree') || recognized.contains('yes')) {
        print('User agreed');
        commandHandled = true;
        await speech.stop();
        await flutterTts.stop();
        await flutterTts.speak("Thank you for agreeing. Proceeding.");
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          _goToSignUp();
        }
      } else if (recognized.contains('disagree') || recognized.contains('no')) {
        print('User disagreed');
        commandHandled = true;
        await speech.stop();
        await flutterTts.stop();
        await flutterTts
            .speak("You disagreed. Returning to the previous screen.");
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context); // go back
        }
      } else {
        print('Unrecognized command: retry prompt');
        commandHandled = false;
        await speech.stop();
        await flutterTts.stop();

        await flutterTts.speak(
            "Sorry, I didn't catch that. Please press the volume up button again to try.");

        setState(() {
          isListening = false;
        });
      }
    }
  }

  // Helper function to await until TTS finishes speaking
  Future<void> _waitForTtsComplete() async {
    while (isTtsSpeaking) {
      await Future.delayed(Duration(milliseconds: 100));
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
