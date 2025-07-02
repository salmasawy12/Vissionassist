import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:test1/recent_chats.dart';
import 'package:test1/vChatscreen.dart';
import 'package:test1/vrecentchats.dart';

class SignUpPagevol extends StatefulWidget {
  const SignUpPagevol({super.key});

  @override
  State<SignUpPagevol> createState() => _SignUpPagevolState();
}

class _SignUpPagevolState extends State<SignUpPagevol>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isEmailEmpty = false;
  bool isPasswordEmpty = false;
  bool isUsernameEmpty = false;
  bool isUsernameTaken = false;
  final GlobalKey<FormState> _signUpFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameOrEmailController = TextEditingController();

  final loginPasswordController = TextEditingController();
  final usernameController = TextEditingController(); // For Sign Up

  bool passwordVisible = false;
  bool loginPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    emailController.dispose();
    passwordController.dispose();
    usernameOrEmailController.dispose();
    loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> createInitialChatsForVolunteer(
      String volunteerUid, String volunteerUsername) async {
    final blindUsersSnapshot =
        await FirebaseFirestore.instance.collection('Users').get();

    for (var userDoc in blindUsersSnapshot.docs) {
      final blindUserUid = userDoc.id;

      // ✅ Volunteer stores a chat doc for each user
      final chatRef = FirebaseFirestore.instance
          .collection('volunteers')
          .doc(volunteerUid)
          .collection('chats')
          .doc(blindUserUid); // chat doc ID = blind user ID

      await chatRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'blindUserId': blindUserUid,
      });

      await chatRef.collection('messages').add({
        'content': 'Chat initialized with blind user $blindUserUid.',
        'sender': volunteerUid,
        'receiver': blindUserUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Stack(
            children: [
              // Header Background
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(32, 12, 32, 32),
                child: Container(
                  width: double.infinity,
                  height: 230,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: AlignmentDirectional.center,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 72),
                    child: Image.asset(
                      'assets/images/definedlogo.png',
                      width: 120, // adjust size as needed
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Form Container with TabBar & TabBarView
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 155),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      height:
                          MediaQuery.of(context).size.width >= 768 ? 530 : 630,
                      constraints: const BoxConstraints(maxWidth: 570),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFF1F4F8), width: 2),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 4,
                            color: Color(0x33000000),
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          TabBar(
                            controller: _tabController,
                            labelColor: const Color(0xFF101213),
                            unselectedLabelColor: const Color(0xFF57636C),
                            indicatorColor: Color(0xff1370C2),
                            indicatorWeight: 3,
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 18,
                            ),
                            tabs: const [
                              Tab(text: 'Sign Up'),
                              Tab(text: 'Log In'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildFormSection(
                                  title: 'Create Account',
                                  subtitle:
                                      'Let\'s get started by filling out the form below.',
                                  emailController: emailController,
                                  passwordController: passwordController,
                                  usernameController: usernameController,
                                  passwordVisible: passwordVisible,
                                  onPasswordToggle: () => setState(
                                      () => passwordVisible = !passwordVisible),
                                  onSubmit: () async {
                                    if (_signUpFormKey.currentState!
                                        .validate()) {
                                      final existing = await FirebaseFirestore
                                          .instance
                                          .collection('volunteers')
                                          .where('username',
                                              isEqualTo: usernameController.text
                                                  .trim())
                                          .get();

                                      if (existing.docs.isNotEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Username already taken')),
                                        );
                                        return;
                                      }

                                      try {
                                        final userCredential =
                                            await FirebaseAuth.instance
                                                .createUserWithEmailAndPassword(
                                          email: emailController.text.trim(),
                                          password:
                                              passwordController.text.trim(),
                                        );

                                        await FirebaseFirestore.instance
                                            .collection('volunteers')
                                            .doc(userCredential.user!.uid)
                                            .set({
                                          'uid': userCredential
                                              .user!.uid, // <-- add this field
                                          'email': emailController.text.trim(),
                                          'username':
                                              usernameController.text.trim(),
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                          'available': true,
                                        });
                                        await createInitialChatsForVolunteer(
                                          userCredential.user!.uid,
                                          usernameController.text.trim(),
                                        );

                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  VolunteerRecentChatsScreen()),
                                        );
                                      } on FirebaseAuthException catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(e.message ??
                                                  'Sign up failed')),
                                        );
                                      }
                                    }
                                  },
                                  buttonText: 'Get Started',
                                  formKey: _signUpFormKey,
                                ),
                                _buildFormSection(
                                  title: 'Log In',
                                  subtitle:
                                      'Welcome back! Please enter your credentials.',
                                  emailController: usernameOrEmailController,
                                  passwordController: loginPasswordController,
                                  passwordVisible: loginPasswordVisible,
                                  onPasswordToggle: () => setState(() {
                                    loginPasswordVisible =
                                        !loginPasswordVisible;
                                  }),
                                  onSubmit: () async {
                                    if (_loginFormKey.currentState!
                                        .validate()) {
                                      try {
                                        String input = usernameOrEmailController
                                            .text
                                            .trim();
                                        String emailToUse = input;

                                        // If it's not an email, assume it's a username and resolve to email
                                        if (!input.contains('@')) {
                                          final querySnapshot =
                                              await FirebaseFirestore.instance
                                                  .collection('volunteers')
                                                  .where('username',
                                                      isEqualTo: input)
                                                  .limit(1)
                                                  .get();

                                          if (querySnapshot.docs.isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Username not found')),
                                            );
                                            return;
                                          }

                                          emailToUse =
                                              querySnapshot.docs.first['email'];
                                        }

                                        await FirebaseAuth.instance
                                            .signInWithEmailAndPassword(
                                          email: emailToUse,
                                          password: loginPasswordController.text
                                              .trim(),
                                        );
                                        // After successful login
                                        await FirebaseFirestore.instance
                                            .collection('volunteers')
                                            .doc(FirebaseAuth
                                                .instance.currentUser!.uid)
                                            .update({'available': true});

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Logged in successfully!')),
                                        );

                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  VolunteerRecentChatsScreen()),
                                        );
                                      } on FirebaseAuthException catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  e.message ?? 'Login failed')),
                                        );
                                      }
                                    }
                                  },
                                  buttonText: 'Log In',
                                  formKey: _loginFormKey,
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildFormSection({
    required String title,
    required String subtitle,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required bool passwordVisible,
    required VoidCallback onPasswordToggle,
    TextEditingController? usernameController,
    required VoidCallback onSubmit,
    required String buttonText,
    required GlobalKey<FormState> formKey,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            if (usernameController != null) ...[
              TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide:
                        const BorderSide(color: Color(0xFFE0E3E7), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide:
                        const BorderSide(color: Color(0xFFE0E3E7), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide:
                        const BorderSide(color: Color(0xff1370C2), width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText:
                    usernameController == null ? 'Username or Email' : 'Email',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E3E7), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E3E7), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide:
                      const BorderSide(color: Color(0xff1370C2), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              obscureText: !passwordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E3E7), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide:
                      const BorderSide(color: Color(0xFFE0E3E7), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide:
                      const BorderSide(color: Color(0xff1370C2), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 230,
                height: 52,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1370C2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40)),
                  ),
                  child: Text(buttonText,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
