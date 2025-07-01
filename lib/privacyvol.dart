import 'package:flutter/material.dart';
import 'package:test1/getstarted.dart';
import 'package:test1/signupvol.dart';
import 'package:test1/terms.dart';

class PrivacyScreenvol extends StatefulWidget {
  const PrivacyScreenvol({super.key});

  @override
  _PrivacyScreenState createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreenvol> {
  final List<String> listItems = [
    "I will not use Vision Assist as a mobility device.",
    "Vision Assist can record, review, and share videos and images for safety, quality, and as further described in the Privacy Policy.",
    "The data, videos, images, and personal information I submit to Vision Assist may be stored and processed in our database.",
  ];

  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignUpPagevol()),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
                      text: listItems[0],
                    ),

                    const SizedBox(height: 16),

                    // List item 2
                    _iconTextTile(
                      icon: Icons.photo_camera,
                      text: listItems[1],
                    ),

                    const SizedBox(height: 16),

                    // List item 3
                    _iconTextTile(
                      icon: Icons.lock,
                      text: listItems[2],
                    ),

                    const SizedBox(height: 25),

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
                        onPressed: _goToSignUp,
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
