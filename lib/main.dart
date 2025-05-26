import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:test1/home.dart';
import 'package:test1/welcome.dart';
import 'package:test1/signup.dart'; // Important for binding initialization
// import 'package:gradproj/home.dart';
// import 'package:gradproj/login.dart';
// import 'package:gradproj/signup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures plugins are registered
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
        '/signup': (context) => SignUpScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
