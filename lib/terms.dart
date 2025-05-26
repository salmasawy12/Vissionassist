import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            'Welcome to our app!\n\n'
            'By using our service, you agree to the following terms:\n\n'
            '1. You must be at least 13 years old to use this app.\n'
            '2. You agree not to use the app for illegal purposes.\n'
            '3. We reserve the right to terminate accounts for any reason.\n'
            '4. Content submitted remains your property but grants us a license to use it.\n\n'
            'These terms may be updated at any time without notice.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
