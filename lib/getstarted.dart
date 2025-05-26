import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _auth = FirebaseAuth.instance;
  final FlutterTts _tts = FlutterTts();
  late stt.SpeechToText _speech;
  bool _isListening = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _message = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _signInAnonymously();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          // Removed _startListening() here to prevent immediate reopening
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
      },
    );
    if (available) {
      // Do NOT start listening here yet. We wait for TTS welcome message.
    }
  }

  void _startListening() {
    if (!_isListening) {
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            final recognized = result.recognizedWords.toLowerCase();
            if (recognized.contains('sign up later')) {
              _onSignUpLater();
            } else if (recognized.contains('sign up now')) {
              speakAndWait(
                "Please fill in the required fields to sign up, then press the link account button.",
              );
            }
          }
        },
        localeId: 'en_US',
      );
      setState(() {
        _isListening = true;
      });
    }
  }

  Future<void> speakAndWait(String text) async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);

    final completer = Completer<void>();

    _tts.setCompletionHandler(() {
      completer.complete();
    });

    await _tts.speak(text);

    return completer.future;
  }

  Future<void> _signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final uid = userCredential.user?.uid;
      // setState(() {
      //   _message = "Signed in anonymously with UID: $uid";
      // });
      await speakAndWait(
        "Welcome. You are signed in anonymously. If you uninstall the app, your data will be lost. To keep your data, please sign up and link your account. If you wish to continue now and sign up later, please say sign up later. If not, please say sign up now ",
      );
      _startListening(); // Start listening only after TTS finishes
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = "Error: ${e.message}";
      });
      await speakAndWait("There was an error. ${e.message}");
    } catch (e) {
      setState(() {
        _message = "Unknown error: $e";
      });
      await speakAndWait("An unknown error occurred.");
    }
  }

  Future<void> signUpAndLink() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      await speakAndWait(
          "Please enter both email and password to link your account.");
      return;
    }

    final user = _auth.currentUser;

    if (user != null && user.isAnonymous) {
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      try {
        await user.linkWithCredential(credential);
        setState(() {
          _message = "Account linked with email: ${user.email}";
        });
        await speakAndWait("Account linked successfully");
      } on FirebaseAuthException catch (e) {
        String errorMsg;
        if (e.code == 'credential-already-in-use') {
          errorMsg = "This email is already in use.";
        } else {
          errorMsg = "Error linking account: ${e.message}";
        }
        setState(() {
          _message = errorMsg;
        });
        await speakAndWait(errorMsg);
      }
    } else {
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        setState(() {
          _message = "Signed up successfully: ${userCredential.user?.email}";
        });
        await speakAndWait(
            "Sign up successful. Welcome ${userCredential.user?.email}");
      } on FirebaseAuthException catch (e) {
        setState(() {
          _message = "Error: ${e.message}";
        });
        await speakAndWait("There was an error. ${e.message}");
      }
    }
  }

  void _onSignUpLater() async {
    await speakAndWait(
        "You chose to sign up later. You can link your account anytime.");
    // Navigate or do whatever "sign up later" means in your app flow
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    _emailController.dispose();
    _passwordController.dispose();
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are signed in anonymously.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: signUpAndLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff1370C2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Link Account',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onSignUpLater,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Sign Up Later',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Text(_message, style: const TextStyle(color: Colors.red)),
            // if (_isListening)
            //   const Padding(
            //     padding: EdgeInsets.only(top: 20),
            //     child: Text(
            //       'Listening for "sign up later"...',
            //       style: TextStyle(fontStyle: FontStyle.italic),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}
