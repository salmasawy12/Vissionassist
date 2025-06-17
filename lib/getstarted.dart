import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';
import 'package:test1/chat_screen.dart';
import 'package:test1/recent_chats.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  static const platform = MethodChannel('com.example.volume_button');
  final MethodChannel _fingerprintChannel =
      MethodChannel('com.example.fingerprint');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterTts _tts = FlutterTts();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late stt.SpeechToText _speech;

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _fingerprintVerified = false;
  bool _fingerprintFailed = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    platform.setMethodCallHandler(_handleNativeCalls);
    _initializeAll();
  }

  Future<void> _handleNativeCalls(MethodCall call) async {
    if (call.method == 'volumeUpPressed') {
      if (!_isListening) {
        await _startListening();
      } else {
        await _speech.stop();
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _initializeAll() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) => setState(() => _isListening = false),
    );

    final fingerprintId = await _getFingerprintId();
    if (fingerprintId != null) {
      try {
        final doc = await _firestore
            .collection('fingerprints')
            .doc(fingerprintId)
            .get();
        final storedUid = doc.data()?['uid'];

        if (storedUid != null) {
          await speakAndWait("Welcome back. Please authenticate to continue.");
          final success = await _authenticateFingerprint(storedUid);

// If fingerprint failed, don't continue
          if (!success)
            return;
          else {
            await speakAndWait("Signed in as a new user.");
          }

          _navigateToChat();
          return;
        }
      } catch (e) {
        print("Error during fingerprint UID check: $e");
      }
    }

    await _signInAnonymously();
  }

  Future<String?> _getFingerprintId() async {
    try {
      return await _fingerprintChannel.invokeMethod('getFingerprintId');
    } catch (e) {
      print("Failed to get fingerprint ID: $e");
      return null;
    }
  }

  Future<void> _signInWithUid(String uid) async {
    final userCredential = await _auth.signInAnonymously();
    if (userCredential.user?.uid != uid) {
      await speakAndWait("Authentication mismatch.");
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      final userCred = await _auth.signInAnonymously();
      await speakAndWait(
          "Welcome. You are signed in anonymously. Place your thumb on the fingerprint sensor to identify yourself.");
      await _authenticateFingerprint(userCred.user!.uid);
    } catch (e) {
      print("Sign-in error: ${e.toString()}");
    }
  }

  Future<bool> _authenticateFingerprint(String uid) async {
    try {
      final authenticated =
          await _fingerprintChannel.invokeMethod('authenticateOnce');

      if (authenticated) {
        final fingerprintId = await _getFingerprintId();

        if (fingerprintId != null) {
          final docRef =
              _firestore.collection('fingerprints').doc(fingerprintId);
          final doc = await docRef.get();

          if (!doc.exists) {
            await docRef.set({'uid': uid});
          }

          setState(() {
            _fingerprintVerified = true;
            _fingerprintFailed = false;
          });

          await speakAndWait("Fingerprint recognized. Welcome back.");
          _navigateToChat();
          return true;
        } else {
          await speakAndWait("Fingerprint ID not available.");
          return false;
        }
      } else {
        try {
          await _fingerprintChannel.invokeMethod('cancelPrompt');
        } catch (e) {
          print("Failed to cancel fingerprint prompt: $e");
        }

        setState(() {
          _fingerprintVerified = false;
          _fingerprintFailed = true;
        });
        await speakAndWait(
            "Fingerprint not recognized. Say try again or sign up later.");
        return false;
      }
    } catch (e) {
      setState(() {
        _fingerprintVerified = false;
        _fingerprintFailed = true;
      });
      await speakAndWait("Authentication failed: ${e.toString()}");
      return false;
    }
  }

  Future<void> _startListening() async {
    if (_isSpeaking) return;

    if (!_isListening && await _speech.initialize()) {
      _speech.listen(
        onResult: (result) async {
          if (result.finalResult) {
            final recognized = result.recognizedWords.toLowerCase().trim();
            if (recognized.contains('sign up later')) {
              await _speech.stop();
              setState(() => _isListening = false);
              await _onSignUpLater();
            } else if (recognized.contains('try again')) {
              await _speech.stop();
              setState(() => _isListening = false);
              await _authenticateFingerprint(_auth.currentUser!.uid);
            } else {
              await _handleUnknownCommand(
                  "Sorry, I didn't understand that command.");
            }
          }
        },
        localeId: 'en_US',
      );
      setState(() => _isListening = true);
    }
  }

  Future<void> _handleUnknownCommand(String message) async {
    await _speech.stop();
    setState(() => _isListening = false);
    await speakAndWait(message);
  }

  Future<void> speakAndWait(String text) async {
    final completer = Completer<void>();
    _isSpeaking = true;

    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      completer.complete();
    });
    _tts.setErrorHandler((message) {
      _isSpeaking = false;
      completer.completeError(message ?? "TTS error");
    });

    await _tts.speak(text);
    return completer.future;
  }

  Future<void> _onSignUpLater() async {
    await speakAndWait(
        "You chose to sign up later. You can link your account from settings.");
    _navigateToChat();
  }

  void _navigateToChat() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailScreen()),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
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
          height: 80,
          fit: BoxFit.contain,
        ),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text("You are signed in anonymously."),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: const [
                  Icon(Icons.fingerprint, size: 80, color: Color(0xff1370C2)),
                  SizedBox(height: 8),
                  Text(
                    "Place your thumb on the fingerprint sensor to authenticate",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _onSignUpLater,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1370C2),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text("Sign Up Later",
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _authenticateFingerprint(_auth.currentUser!.uid),
              icon: Icon(
                _fingerprintVerified ? Icons.check_circle : Icons.fingerprint,
                color: Colors.white,
              ),
              label: Text(
                _fingerprintVerified
                    ? "Fingerprint Verified"
                    : "Verify Fingerprint",
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _fingerprintVerified
                    ? Colors.green
                    : (_fingerprintFailed
                        ? Colors.red
                        : const Color(0xff1370C2)),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
