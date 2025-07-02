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
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with TickerProviderStateMixin {
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
  bool _isLoading = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    platform.setMethodCallHandler(_handleNativeCalls);

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _fadeController.forward();
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
    setState(() {
      _isLoading = true;
      _fingerprintVerified = false;
      _fingerprintFailed = false;
    });

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
            _isLoading = false;
          });

          // Start pulse animation for success
          _pulseController.repeat(reverse: true);

          await speakAndWait("Fingerprint recognized. Welcome back.");
          print(
              'DEBUG: Fingerprint recognized, about to call signInWithFingerprint');
          bool success = await signInWithFingerprint(fingerprintId);
          if (success) {
            print('DEBUG: signInWithFingerprint succeeded, navigating to chat');
            _navigateToChat();
          } else {
            print('DEBUG: signInWithFingerprint failed');
            await speakAndWait('Login failed. Please try again.');
          }
          return success;
        } else {
          await speakAndWait("Fingerprint ID not available.");
          setState(() {
            _isLoading = false;
          });
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
          _isLoading = false;
        });
        await speakAndWait(
            "Fingerprint not recognized. Say try again to authenticate.");
        return false;
      }
    } catch (e) {
      setState(() {
        _fingerprintVerified = false;
        _fingerprintFailed = true;
        _isLoading = false;
      });
      await speakAndWait(
          "Authentication failed. Please make sure you have a fingerprint registered on your device. Would you like to try again?");
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
            if (recognized.contains('try again') ||
                recognized.contains('yes')) {
              await _speech.stop();
              setState(() => _isListening = false);
              await speakAndWait("Place your finger on the fingerprint sensor");
              await _authenticateFingerprint(_auth.currentUser!.uid);
            } else if (recognized.contains('no')) {
              await _speech.stop();
              setState(() => _isListening = false);
              await speakAndWait(
                  "Authentication cancelled. You can try again later.");
            } else {
              await _handleUnknownCommand(
                  "Please say 'yes' or 'try again' to retry, or 'no' to cancel.");
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

  void _navigateToChat() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RecentChatsScreen()),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Welcome Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 32,
                              color: const Color(0xFF1370C2),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                "Welcome to VisionAssist",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Fingerprint Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Animated Fingerprint Icon
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _fingerprintVerified
                                      ? _pulseAnimation.value
                                      : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: _getFingerprintIconColor()
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getFingerprintIcon(),
                                      size: 64,
                                      color: _getFingerprintIconColor(),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // Status Text
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _getStatusTextColor(),
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 12),

                            Text(
                              _getInstructionText(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            if (_isLoading) ...[
                              const SizedBox(height: 20),
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1370C2)),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Column(
                        children: [
                          // Verify Fingerprint Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _authenticateFingerprint(
                                      _auth.currentUser!.uid),
                              icon: Icon(
                                _fingerprintVerified
                                    ? Icons.check_circle
                                    : Icons.fingerprint,
                                color: Colors.white,
                                size: 24,
                              ),
                              label: Text(
                                _fingerprintVerified
                                    ? "Fingerprint Verified"
                                    : "Verify Fingerprint",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getFingerprintButtonColor(),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: _getFingerprintButtonColor()
                                    .withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Help Text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1370C2).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF1370C2).withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: const Color(0xFF1370C2),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Press volume up button to use voice commands",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF1370C2),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for UI state
  Color _getFingerprintIconColor() {
    if (_fingerprintVerified) return Colors.green;
    if (_fingerprintFailed) return Colors.red;
    return const Color(0xFF1370C2);
  }

  IconData _getFingerprintIcon() {
    if (_fingerprintVerified) return Icons.check_circle;
    if (_fingerprintFailed) return Icons.error;
    return Icons.fingerprint;
  }

  String _getStatusText() {
    if (_fingerprintVerified) return "Fingerprint Verified!";
    if (_fingerprintFailed) return "Authentication Failed";
    return "Ready to Authenticate";
  }

  Color _getStatusTextColor() {
    if (_fingerprintVerified) return Colors.green;
    if (_fingerprintFailed) return Colors.red;
    return const Color(0xFF1F2937);
  }

  String _getInstructionText() {
    if (_fingerprintVerified)
      return "You can now proceed to chat with volunteers";
    if (_fingerprintFailed)
      return "Make sure you have a fingerprint registered on your device";
    return "Place your thumb on the fingerprint sensor to identify yourself";
  }

  Color _getFingerprintButtonColor() {
    if (_fingerprintVerified) return Colors.green;
    if (_fingerprintFailed) return Colors.red;
    return const Color(0xFF1370C2);
  }
}

// Call this after fingerprint is recognized and you have fingerprintId
Future<bool> signInWithFingerprint(String fingerprintId) async {
  try {
    print(
        'DEBUG: Attempting fingerprint login with fingerprintId: $fingerprintId');
    final response = await http.post(
      Uri.parse(
          'http://172.20.10.3:4000/getCustomToken'), // Use your Mac's correct local IP
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fingerprintId': fingerprintId}),
    );
    print('DEBUG: Backend response status: ${response.statusCode}');
    print('DEBUG: Backend response body: ${response.body}');
    if (response.statusCode == 200) {
      final token = jsonDecode(response.body)['token'];
      await FirebaseAuth.instance.signInWithCustomToken(token);
      print(
          'DEBUG: Firebase currentUser UID: \x1B[32m${FirebaseAuth.instance.currentUser?.uid}\x1B[0m');
      return true;
    } else {
      print('Login error: \x1B[31m${response.body}\x1B[0m');
      return false;
    }
  } catch (e) {
    print('Error during fingerprint login: $e');
    return false;
  }
}
