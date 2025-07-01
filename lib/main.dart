import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';

import 'package:test1/getstarted.dart';
// import 'package:vissionassist/getstarted.dart';
import 'package:test1/home.dart';
import 'package:test1/welcome.dart';
import 'package:firebase_core/firebase_core.dart';

// import 'package:test1/signup.dart'; // Important for binding initialization
// import 'package:gradproj/home.dart';
// import 'package:gradproj/login.dart';
// import 'package:gradproj/signup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures plugins are registered
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // title: 'AI Chat App',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => Startscreen(),
        // '/signup': (context) => SignUpPage(),
        // '/home': (context) => HomeScreen(),
      },
    );
  }
}
