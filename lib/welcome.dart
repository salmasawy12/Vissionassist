// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, sort_child_properties_last

import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'privacy.dart';
import 'package:flutter/services.dart';

class Startscreen extends StatefulWidget {
  @override
  _StartscreenState createState() => _StartscreenState();
}

class _StartscreenState extends State<Startscreen> {
  static const volumeChannel = MethodChannel('com.example.volume_button');
  late FlutterTts flutterTts;
  late stt.SpeechToText speech;
  bool isTtsSpeaking = false;
  bool isListening = false;
  String lastWords = '';
  bool commandHandled = false;

  @override
  void initState() {
    super.initState();

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
  }

  Future _speakWelcome() async {
    commandHandled = false; // reset here
    await flutterTts.stop();
    await flutterTts.speak(
        "Hi, welcome to vision assist. Would you like to proceed to sign up? Please respond with proceed or cancel after opening the mic by pressing the volume up button.");
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

    if (recognized.contains('proceed')) {
      print('User said yes or proceed');
      commandHandled = true;
      await speech.stop();
      await flutterTts.stop();

      // Start TTS
      await flutterTts.speak(
          "Proceeding to sign up. Moving forward, please make sure to open the mic before speaking.");

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
          MaterialPageRoute(builder: (context) => PrivacyScreen()),
        );
      }
    } else if (recognized.contains('cancel')) {
      print('User said no');
      commandHandled = true;
      await speech.stop();
      await flutterTts.stop();
      await flutterTts.speak(
          "No problem, please take your time and switch the mic back on to say proceed when you are ready.");
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
    flutterTts.stop();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.only(bottom: 100),
        children: [
          SizedBox(height: 20),
          Image(
            image: AssetImage('assets/images/definedlogo.png'),
            width: 100,
            height: 100,
          ),
          SizedBox(height: 10),
          cs.CarouselSlider(
            items: [
              _imageContainer(
                  'assets/images/ChatGPT_Image_Apr_17__2025__07_21_14_PM-modified-removebg-preview.png'),
              _imageContainer(
                  'assets/images/PHOTO-2025-04-20-16-16-15-removebg-preview.png'),
              _imageContainer(
                  'assets/images/PHOTO-2025-04-20-16-39-39-removebg-preview.png'),
            ],
            options: cs.CarouselOptions(
              height: 250,
              enlargeCenterPage: true,
              autoPlay: true,
              aspectRatio: 16 / 9,
              autoPlayCurve: Curves.fastOutSlowIn,
              enableInfiniteScroll: true,
              autoPlayAnimationDuration: Duration(milliseconds: 800),
              viewportFraction: 0.8,
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Text(
                  "Guiding your way,",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xff0E2350)),
                ),
                Text(
                  "Every step of the day",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xff0E2350)),
                ),
              ],
            ),
          ),
          SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            child: SizedBox(
              height: 80,
              child: ElevatedButton(
                onPressed: () async {
                  await flutterTts.stop();
                  await speech.stop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PrivacyScreen()),
                  );
                },
                child: Text(
                  'I need visual assistance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff1370C2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _imageContainer(String assetPath) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 800,
      margin: EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        image: DecorationImage(
          image: AssetImage(assetPath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
