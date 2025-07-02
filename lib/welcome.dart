// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, sort_child_properties_last

import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:test1/privacyvol.dart';
import 'privacy.dart';
import 'package:flutter/services.dart';

class Startscreen extends StatefulWidget {
  @override
  _StartscreenState createState() => _StartscreenState();
}

class _StartscreenState extends State<Startscreen>
    with TickerProviderStateMixin {
  static const volumeChannel = MethodChannel('com.example.volume_button');
  late FlutterTts flutterTts;
  late stt.SpeechToText speech;
  bool isTtsSpeaking = false;
  bool isListening = false;
  String lastWords = '';
  bool commandHandled = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    flutterTts = FlutterTts();
    speech = stt.SpeechToText();

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

        if (!isListening) {
          print("Mic is not listening. Attempting to start...");
          await speech.stop();

          // ✅ Extra safety delay after TTS finishes
          Future.delayed(Duration(milliseconds: 500), () {
            if (!isTtsSpeaking) _startListening();
          });
        } else {
          print("Mic is already listening");
        }
      }
    });

    _speakWelcome();

    // Start animations after initialization
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  Future _speakWelcome() async {
    commandHandled = false; // reset here
    await flutterTts.stop();
    await flutterTts.speak(
        "Hi, welcome to Vision Assist! To get started, please press the volume up button to open the microphone. Then say 'volunteer' if you'd like to offer help, or 'visual support' if you need support.");
  }

  void _startListening() async {
    print('Starting to listen...');
    commandHandled = false; // reset

    bool available = await speech.initialize(
      onError: (val) {
        print('Speech error: $val');
        setState(() => isListening = false);
      },
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'notListening') {
          // mic stopped due to timeout or silence
          setState(() => isListening = false);
        }
      },
    );

    if (available) {
      setState(() => isListening = true);
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
        listenMode:
            stt.ListenMode.confirmation, // or dictation depending on needs
        pauseFor: Duration(seconds: 3), // how long silence before stop
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

    if (recognized.contains('volunteer')) {
      print('user said volunteer');
      commandHandled = true;
      await speech.stop();
      await flutterTts.stop();

      // Start TTS
      await flutterTts.speak("You have chosen to be a volunteer.");

      // 🟡 Wait until TTS actually starts (isTtsSpeaking = true)
      while (!isTtsSpeaking) {
        await Future.delayed(Duration(milliseconds: 100));
      }

      // 🟢 Now wait for it to finish
      while (isTtsSpeaking) {
        await Future.delayed(Duration(milliseconds: 100));
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PrivacyScreenvol()),
        );
      }
    } else if (recognized.contains('visual support')) {
      print('User said visual assistance');
      commandHandled = true;
      await speech.stop();
      await flutterTts.stop();
      await flutterTts.speak(
          "You have selected that you need visual assistance. Moving forward, please make sure to open the mic before speaking.");
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PrivacyScreen()),
        );
      }
    } else {
      print('Unrecognized command: retry prompt');
      commandHandled = false; // allow reprocessing
      await speech.stop(); // stop mic if it's running
      await flutterTts.stop();

      await flutterTts.speak(
          "Sorry, I didn't catch that. Please press the volume up button again to try.");

      // Important: Reset listening flag so mic can be restarted on button press
      setState(() {
        isListening = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    flutterTts.stop();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverAppBar(
                expandedHeight: 80,
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Image.asset(
                            'assets/images/definedlogo.png',
                            width: 120,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Image Carousel
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: cs.CarouselSlider(
                              items: [
                                _imageContainer(
                                    'assets/images/ChatGPT_Image_Apr_17__2025__07_21_14_PM-modified-removebg-preview.png'),
                                _imageContainer(
                                    'assets/images/PHOTO-2025-04-20-16-16-15-removebg-preview.png'),
                                _imageContainer(
                                    'assets/images/PHOTO-2025-04-20-16-39-39-removebg-preview.png'),
                              ],
                              options: cs.CarouselOptions(
                                height: 280,
                                enlargeCenterPage: true,
                                autoPlay: true,
                                aspectRatio: 16 / 9,
                                autoPlayCurve: Curves.fastOutSlowIn,
                                enableInfiniteScroll: true,
                                autoPlayAnimationDuration:
                                    Duration(milliseconds: 800),
                                viewportFraction: 0.8,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Tagline
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1370C2).withOpacity(0.1),
                                const Color(0xFF1370C2).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF1370C2).withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF1370C2).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.visibility,
                                  color: const Color(0xFF1370C2),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Guiding your way,",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1370C2),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const Text(
                                      "Every step of the day",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Color(0xFF1370C2),
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Action Buttons
                        Column(
                          children: [
                            // Volunteer Button
                            Container(
                              width: double.infinity,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1370C2)
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await flutterTts.stop();
                                  await speech.stop();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            PrivacyScreenvol()),
                                  );
                                },
                                icon: const Icon(
                                  Icons.volunteer_activism,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                label: const Text(
                                  'Be a Volunteer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1370C2),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Visual Assistance Button
                            Container(
                              width: double.infinity,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1370C2)
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await flutterTts.stop();
                                  await speech.stop();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => PrivacyScreen()),
                                  );
                                },
                                icon: const Icon(
                                  Icons.visibility,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                label: const Text(
                                  'I Need Visual Assistance',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1370C2),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Voice Command Help
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF1370C2).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mic,
                                  color: const Color(0xFF1370C2),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Voice Commands Available",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Press volume up button and say 'volunteer' or 'visual support'",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageContainer(String assetPath) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 280,
      margin: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        image: DecorationImage(
          image: AssetImage(assetPath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
