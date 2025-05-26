// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, sort_child_properties_last

import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'privacy.dart';

class Startscreen extends StatefulWidget {
  @override
  _StartscreenState createState() => _StartscreenState();
}

class _StartscreenState extends State<Startscreen> {
  late FlutterTts flutterTts;
  late stt.SpeechToText speech;
  bool isListening = false;
  String lastWords = '';
  bool commandHandled = false;

  @override
  void initState() {
    super.initState();

    flutterTts = FlutterTts();
    speech = stt.SpeechToText();

    flutterTts.setCompletionHandler(() {
      print("TTS completed");
      if (!commandHandled) {
        _startListening();
      }
    });

    _speakWelcome();
  }

  Future _speakWelcome() async {
    commandHandled = false; // reset here
    await flutterTts.stop();
    await flutterTts.speak(
        "Hi, welcome to vision assist. Would you like to proceed to sign up? Please respond with yes or no.");
  }

  void _startListening() async {
    print('Starting to listen...');
    commandHandled = false; // <--- reset here as well before listening
    bool available = await speech.initialize(
      onError: (val) {
        print('Speech error: $val');
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

    if (recognized.contains('yes') || recognized.contains('proceed')) {
      print('User said yes or proceed');
      commandHandled = true;
      await speech.stop(); // stop listening before navigation
      await flutterTts.stop();
      await flutterTts.speak("Proceeding to sign up.");
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PrivacyScreen()),
        );
      }
    } else if (recognized.contains('no')) {
      print('User said no');
      commandHandled = true;
      await speech.stop();
      await flutterTts.stop();
      await flutterTts.speak("Okay, please take your time.");
      await Future.delayed(Duration(seconds: 10));
      await _speakWelcome();
    } else {
      print('Unrecognized command: retry prompt');
      await flutterTts.stop();
      commandHandled = false; // reset so retry works
      await flutterTts
          .speak("Sorry, I didn't catch that. Please say yes or no.");
      // After speech completes, TTS completion handler will call _startListening()
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0),
            child: Text(
              'Detected command: $lastWords',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
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
