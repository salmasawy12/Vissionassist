import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations after initialization
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: const Color(0xFF1370C2)),
                  onPressed: () => Navigator.pop(context),
                ),
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
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1370C2).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF1370C2).withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1370C2)
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.description,
                                      color: const Color(0xFF1370C2),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Text(
                                      "Terms of Service",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Last updated: ${DateTime.now().year}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Terms Content
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSection(
                                "1. Acceptance of Terms",
                                "By accessing and using VisionAssist, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.",
                                Icons.check_circle,
                                Colors.green,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "2. Description of Service",
                                "VisionAssist is a mobile application designed to provide visual assistance to users with visual impairments through real-time video and audio communication with volunteers. The service includes video calling, image sharing, and text-to-speech functionality.",
                                Icons.visibility,
                                Colors.blue,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "3. User Eligibility",
                                "You must be at least 13 years old to use VisionAssist. If you are under 18, you must have parental or guardian consent. You must also have the legal capacity to enter into binding agreements.",
                                Icons.person,
                                Colors.orange,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "4. User Responsibilities",
                                "You agree to use VisionAssist only for lawful purposes and in accordance with these Terms. You are responsible for maintaining the confidentiality of your account and for all activities that occur under your account.",
                                Icons.security,
                                Colors.red,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "5. Privacy and Data Protection",
                                "Your privacy is important to us. We collect, use, and protect your personal information as described in our Privacy Policy. By using VisionAssist, you consent to our collection and use of your information.",
                                Icons.privacy_tip,
                                Colors.purple,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "6. Content and Intellectual Property",
                                "You retain ownership of content you submit to VisionAssist. However, you grant us a worldwide, non-exclusive license to use, reproduce, and distribute your content for the purpose of providing our services.",
                                Icons.copyright,
                                Colors.indigo,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "7. Prohibited Activities",
                                "You may not use VisionAssist to: (a) violate any laws or regulations; (b) harm, harass, or intimidate others; (c) share inappropriate or offensive content; (d) attempt to gain unauthorized access to our systems; (e) interfere with the service's operation.",
                                Icons.block,
                                Colors.red,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "8. Service Availability",
                                "We strive to provide reliable service but cannot guarantee uninterrupted access. We may modify, suspend, or discontinue the service at any time with reasonable notice to users.",
                                Icons.schedule,
                                Colors.teal,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "9. Limitation of Liability",
                                "VisionAssist is provided 'as is' without warranties. We shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the service.",
                                Icons.warning,
                                Colors.amber,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "10. Termination",
                                "We may terminate or suspend your account immediately, without prior notice, for conduct that we believe violates these Terms or is harmful to other users or the service.",
                                Icons.cancel,
                                Colors.grey,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "11. Changes to Terms",
                                "We reserve the right to modify these Terms at any time. We will notify users of significant changes via email or through the app. Continued use of VisionAssist after changes constitutes acceptance of the new Terms.",
                                Icons.edit,
                                Colors.cyan,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "12. Governing Law",
                                "These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which VisionAssist operates, without regard to conflict of law principles.",
                                Icons.gavel,
                                Colors.brown,
                              ),
                              const SizedBox(height: 24),
                              _buildSection(
                                "13. Contact Information",
                                "If you have any questions about these Terms of Service, please contact us at support@visionassist.com or through our in-app support system.",
                                Icons.contact_support,
                                Colors.green,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Footer
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: const Color(0xFF1370C2),
                                size: 24,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "By using VisionAssist, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
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

  Widget _buildSection(
      String title, String content, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
