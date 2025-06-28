import 'dart:async';
import 'package:MedoQRST/nurseprofile.dart';
import 'package:marquee/marquee.dart';

import 'profile.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'edit_page.dart' as edit;
import 'login.dart' as login;
import 'dart:convert';
import 'dart:developer';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  bool onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;

  runApp(MyApp(onboardingCompleted: onboardingCompleted));
}

class TimeUtils {
  static String formatTimeForDisplay(String isoDateTime) {
    if (isoDateTime.isEmpty) return 'N/A';

    try {
      DateTime dateTime = DateTime.parse(isoDateTime); // Convert to local time

      // Extract hour and minute
      int hour = dateTime.hour;
      int minute = dateTime.minute;

      // Convert to 12-hour format
      final period = (hour >= 12) ? 'PM' : 'AM';
      int hour12 = (hour % 12 == 0) ? 12 : (hour % 12);

      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return isoDateTime; // Return original on error
    }
  }

  // For saving current time to DB (local time)
  static String getCurrentTimeForDb() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}

class MyApp extends StatelessWidget {
  final bool onboardingCompleted;

  const MyApp({Key? key, required this.onboardingCompleted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: onboardingCompleted ? const MyHome() : const SplashScreen(),
      routes: {
        '/home': (context) => const MyHome(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textScaleAnimation;
  late Animation<Offset> _textSlideAnimation;

  String _displayText = "";
  int _textIndex = 0;
  final String _fullText = "MedoQRST";
  Timer? _typewriterTimer;

  String _displayTagline = "";
  int _taglineIndex = 0;
  final String _fullTagline = "Smart Ward Management System";
  Timer? _taglineTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutBack,
      ),
    );

    _logoRotateAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _textScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    _startTypewriterAnimation();

    Future.delayed(const Duration(seconds: 6), () async {
      final prefs = await SharedPreferences.getInstance();
      bool onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;

      if (onboardingCompleted) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    });
  }

  void _startTypewriterAnimation() {
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_textIndex < _fullText.length) {
        setState(() {
          _displayText += _fullText[_textIndex];
          _textIndex++;
        });
      } else {
        _typewriterTimer?.cancel();
        _startTaglineTypewriterAnimation();
      }
    });
  }

  void _startTaglineTypewriterAnimation() {
    _taglineTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_taglineIndex < _fullTagline.length) {
        setState(() {
          _displayTagline += _fullTagline[_taglineIndex];
          _taglineIndex++;
        });
      } else {
        _taglineTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _typewriterTimer?.cancel();
    _taglineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 13, 3, 70),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Transform.rotate(
                      angle: _logoRotateAnimation.value,
                      child: Opacity(
                        opacity: _logoFadeAnimation.value,
                        child: Image.asset(
                          'assets/logo.png',
                          width: 200,
                          height: 180,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),
              FadeTransition(
                opacity: _textFadeAnimation,
                child: SlideTransition(
                  position: _textSlideAnimation,
                  child: ScaleTransition(
                    scale: _textScaleAnimation,
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 240, 241, 241),
                            Color.fromARGB(255, 45, 174, 224),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: Text(
                        _displayText,
                        style: GoogleFonts.montserrat(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: const Color.fromARGB(255, 238, 236, 236)
                                  .withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(3, 3),
                            ),
                            Shadow(
                              color: const Color.fromARGB(255, 244, 246, 247)
                                  .withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 0),
                            ),
                            Shadow(
                              color: const Color.fromARGB(255, 244, 244, 245)
                                  .withOpacity(0.3),
                              blurRadius: 40,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _displayTagline,
                style: GoogleFonts.robotoMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  color: const Color.fromARGB(255, 255, 255, 255),
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CurvedHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height * 0.8,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class BreathingAnimation extends StatefulWidget {
  final Widget child;

  const BreathingAnimation({Key? key, required this.child}) : super(key: key);

  @override
  _BreathingAnimationState createState() => _BreathingAnimationState();
}

class _BreathingAnimationState extends State<BreathingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

class DischargeSheet extends StatefulWidget {
  final String admissionNo;
  final String name;
  final String date;

  const DischargeSheet({
    Key? key,
    required this.admissionNo,
    required this.name,
    required this.date,
  }) : super(key: key);

  @override
  _DischargeSheetState createState() => _DischargeSheetState();
}
class _DischargeSheetState extends State<DischargeSheet> {
  Map<String, dynamic>? dischargeDetails;
  Map<String, dynamic>? diagnosticReports;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDischargeData();
  }
Future<void> _fetchDischargeData() async {
  try {
    final dischargeResponse = await http.get(
      Uri.parse('http://10.57.148.47:1232/discharge-details/${widget.admissionNo}'),
      headers: {'Content-Type': 'application/json'},
    );

    if (dischargeResponse.statusCode == 200) {
      final dischargeData = jsonDecode(dischargeResponse.body);
      if (dischargeData is List && dischargeData.isNotEmpty) {
        setState(() {
          dischargeDetails = dischargeData[0];
        });
      } else {
        setState(() {
          _errorMessage = 'No discharge details found.';
        });
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Notice', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info, color: Colors.blue, size: 50),
                SizedBox(height: 10),
                Text(
                  'The discharge sheet will be available once the patient is discharged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(color: Colors.blue)),
              ),
            ],
          );
        },
      );
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Error: ${e.toString()}';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    final isNotDischarged = dischargeDetails == null;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : isNotDischarged
                  ? _buildNotDischargedView()
                  : _buildDischargeDetailsView(),
    );
  }

  Widget _buildNotDischargedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 60,
            color: Colors.blue[800],
          ),
          const SizedBox(height: 20),
          Text(
            'Patient Not Discharged Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'The discharge sheet will be available\nonce the patient is discharged.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDischargeDetailsView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF87CEFB), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Logo and Title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00008C), const Color(0xFF659CDF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                border: Border.all(
                  color: const Color(0xFF00008C),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: 60,
                      color: Colors.white,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Discharge Sheet',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Patient Information Section
            _buildSectionTitle('Patient Information'),
            _buildDetailCard(
              icon: Icons.person,
              iconColor: const Color(0xFF00008C),
              label: 'Name',
              value: widget.name,
            ),

            const SizedBox(height: 20),

            // Discharge Details Section
            _buildSectionTitle('Discharge Details'),
            if (dischargeDetails != null) ...[
              _buildDetailCard(
                icon: Icons.assignment,
                iconColor: const Color.fromARGB(255, 26, 223, 8),
                label: 'Examination Findings',
                value: dischargeDetails!['Examination_findings'],
              ),
              _buildDetailCard(
                icon: Icons.medication,
                iconColor: const Color.fromARGB(255, 238, 148, 63),
                label: 'Discharge Treatment',
                value: dischargeDetails!['Discharge_treatment'],
              ),
            ],

            const SizedBox(height: 20),

            // Diagnostic Reports Section
            _buildSectionTitle('Diagnostic Reports'),
            if (dischargeDetails!= null) ...[
              _buildDetailCard(
  icon: Icons.bed,
  iconColor: const Color.fromARGB(255, 245, 5, 5),
  label: 'MRI',
  value: dischargeDetails!['MRI'],
),
_buildDetailCard(
  icon: Icons.scanner,
  iconColor: const Color.fromARGB(255, 195, 236, 10),
  label: 'CT Scan',
  value: dischargeDetails!['CT_scan'],
),
_buildDetailCard(
  icon: Icons.biotech,
  iconColor: const Color.fromARGB(255, 5, 173, 240),
  label: 'Biopsy',
  value: dischargeDetails!['Biopsy'],
),
_buildDetailCard(
  icon: Icons.description,
  iconColor: const Color.fromARGB(255, 231, 6, 130),
  label: 'Other Reports',
  value: dischargeDetails!['Other_reports'],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF00008C),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required dynamic value,
  }) {
    if (value == null ||
        value.toString().trim().isEmpty ||
        value.toString().toLowerCase() == 'n/a' ||
        value.toString().toLowerCase() == 'unknown name') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: const Color(0xFF00008C),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 30,
              color: iconColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00008C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value?.toString() ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildDetailItem(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value?.toString() ?? 'N/A',
            softWrap: true,
          ),
        ),
      ],
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late VideoPlayerController _controller1;
  late VideoPlayerController _controller2;
  late VideoPlayerController _controller3;
  final PageController _pageController = PageController();

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    // Initialize video controllers
    _controller1 = _initializeVideo('assets/qrcode.mp4', playImmediately: true);
    _controller2 = _initializeVideo('assets/doctordoctor.mp4');
    _controller3 = _initializeVideo('assets/onlinechat.mp4');

    // Listen to page changes
    _pageController.addListener(() {
      int newPage = _pageController.page?.round() ?? 0;

      if (newPage == 0) {
        _playVideo(_controller1);
      } else {
        _controller1.pause();
      }

      if (newPage == 1) {
        _playVideo(_controller2);
      } else {
        _controller2.pause();
      }

      if (newPage == 2) {
        _playVideo(_controller3);
      } else {
        _controller3.pause();
      }
    });
  }

  VideoPlayerController _initializeVideo(String path,
      {bool playImmediately = false}) {
    var controller = VideoPlayerController.asset(path);

    controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        if (playImmediately) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _playVideo(controller);
          });
        }
      }
    }).catchError((error) => print("Error loading video: $error"));

    return controller;
  }

  void _playVideo(VideoPlayerController controller) {
    if (controller.value.isInitialized && !controller.value.isPlaying) {
      controller.setLooping(true);
      controller.play();
    }
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              _buildPage(
                title: 'Scan, Access & Manage Patient Data Instantly!',
                body:
                    'Empower healthcare professionals with instant access to patient records using secure QR code scanning.',
                controller: _controller1,
                useOriginalHeight: true,
              ),
              _buildPage(
                title: 'Share Medical Reports & Files with Experts in One Tap!',
                body:
                    'Send reports, and medical history as secure PDF files for expert consultation—no more paper hassles.',
                controller: _controller2,
                videoHeight: 180,
              ),
              _buildPage(
                title: 'Multiple Doctors, One Shared Ward Register!',
                body:
                    'Doctors can discuss & update the ward register in real time, ensuring seamless communication for better patient care.',
                controller: _controller3,
                videoHeight: 180,
                isLast: true,
              ),
            ],
          ),
          _buildSkipButton(context),
          _buildIndicator(),
        ],
      ),
    );
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true); // Save completion flag
    Navigator.pushReplacementNamed(context, '/home'); // Navigate to home
  }

  Widget _buildPage(
      {required String title,
      required String body,
      VideoPlayerController? controller,
      double videoHeight = 180,
      bool useOriginalHeight = false,
      bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Video Container
          if (controller != null && controller.value.isInitialized)
            useOriginalHeight
                ? AspectRatio(
                    aspectRatio: controller
                        .value.aspectRatio, // Maintain original aspect ratio
                    child: VideoPlayer(controller),
                  )
                : SizedBox(
                    height: videoHeight,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  )
          else
            Container(
              height: useOriginalHeight ? null : videoHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: CircularProgressIndicator(color: Colors.blue.shade900),
              ),
            ),
          const SizedBox(height: 30),

          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),

          Text(
            body,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.blueGrey.shade800,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Get Started Button (only on last page)
          if (isLast)
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboardingCompleted', true); // Save flag

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MyHome()),
                );
              },
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    return Positioned(
      top: 50,
      right: 20,
      child: _currentPage < 2
          ? TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboardingCompleted', true); // Save flag

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MyHome()),
                );
              },
              child: Text(
                'Skip',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildIndicator() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 12 : 8,
            height: _currentPage == index ? 12 : 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? Colors.blue.shade900
                  : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({Key? key}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/scan.mp4');
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      setState(() {});
    });

    _controller.setLooping(true);
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SizedBox(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  _MyHomeState createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isDoctor = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _isDoctor = prefs.getBool('isDoctor') ?? false;
      _userId = prefs.getString('doctorId');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If user is logged in and is a doctor, show doctor profile menu
    if (_isLoggedIn && _isDoctor && _userId != null) {
      return Scaffold(
        body: Column(
          children: [
            // existing MyHome content
            Expanded(
              flex: 2,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                    border: Border.all(
                      color: const Color.fromARGB(255, 254, 254, 255),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromARGB(66, 255, 255, 255),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: const VideoPlayerWidget(),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                    top: 0, bottom: 20, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(50),
                    topRight: Radius.circular(50),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Welcome to MedoQRST',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: Text(
                        'Quickly scan QR codes to access patient records securely.',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const QRViewExample()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          width: 3,
                          color: Colors.blue.shade900,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Allow camera access to scan QR codes.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // doctor profile menu to the app bar
        appBar: AppBar(
          title: const Text('MedoQRST'),
          actions: [
            DoctorProfileMenu(userId: _userId!),
          ],
        ),
      );
    }

    // Default view for non-logged in users or non-doctors
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white,
                  border: Border.all(
                    color: const Color.fromARGB(255, 254, 254, 255),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(66, 255, 255, 255),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: const VideoPlayerWidget(),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  top: 0, bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to MedoQRST',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      'Quickly scan QR codes to access patient records securely.',
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const QRViewExample()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        width: 3,
                        color: Colors.blue.shade900,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      'Scan QR Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Allow camera access to scan QR codes.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailPageWithoutEdit extends StatelessWidget {
  final String sheetName;
  final Map<String, dynamic> patientData;

  const DetailPageWithoutEdit({
    Key? key,
    required this.sheetName,
    required this.patientData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DetailPage(
        sheetName: sheetName,
        patientData: patientData,
        showEditButton: false,
        showAppBar: false,
      ),
    );
  }
}

class QRViewExample extends StatefulWidget {
  const QRViewExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample>
    with WidgetsBindingObserver {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _cameraPermissionGranted = false;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  Map<String, dynamic>? patientData;
  Timer? _timeoutTimer;
  Timer? _longTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    PermissionStatus status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    setState(() {
      _cameraPermissionGranted = status.isGranted;
    });
    if (_cameraPermissionGranted) {
      await _initializeCamera();
      controller?.resumeCamera(); // Resume camera if permission is granted
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When the app resumes, recheck camera permission
      _checkCameraPermission();
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isCameraInitialized = true;
    });
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "QR Scanner",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(color: Colors.blueGrey, blurRadius: 4),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_cameraPermissionGranted && _isCameraInitialized)
                        _buildQrView(context),
                      _buildScannerFrame(),
                      if (_isProcessing) _buildProcessingOverlay(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Align the QR code within the frame",
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 30),

                // Options Row (Flash, Refresh, Stop) with Better Layout
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildIconButton(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          () async {
                        await controller?.toggleFlash();
                        setState(() {
                          _isFlashOn = !_isFlashOn;
                        });
                      }),
                      _buildIconButton(Icons.refresh, () async {
                        await controller?.resumeCamera();
                      }),
                      _buildIconButton(Icons.stop, () async {
                        await controller?.pauseCamera();
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Processing Message
                if (_isProcessing)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    child: const Center(
                      child: Text(
                        "Processing...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),

            // Red Popup Overlay if Camera Permission is Not Granted
            if (!_cameraPermissionGranted)
              Container(
                color: Colors.white,
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Camera Permission Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please allow camera access to scan QR codes.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            await openAppSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text(
                            'Open Settings',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withOpacity(0.1),
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: Colors.blueAccent, size: 28),
      ),
    );
  }

  Widget _buildScannerFrame() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent, width: 4),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Future<void> _fetchPatientData(int wardNo, int bedNo) async {
    const apiUrl = 'http://10.57.148.47:1232/patient';
    try {
      // Make a GET request with both ward_no and bed_no as query parameters
      final response = await http.get(
        Uri.parse('$apiUrl?ward_no=$wardNo&bed_no=$bedNo'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // If the server returns a 200 OK response, parse the data
        final data = jsonDecode(response.body);
        print('Patient Data: $data');

        if (data is List<dynamic> && data.isNotEmpty) {
          // Extract patient data from the first entry
          final patient = data[0];

          // Collect progress notes
          List<Map<String, dynamic>> progressDetails = [];
          Set<String> uniqueProgressKeys = {};
          for (var item in data) {
            if (item.containsKey('Progress_Date') &&
                item.containsKey('Notes')) {
              final progressKey = '${item['Progress_Date']}-${item['Notes']}';
              if (!uniqueProgressKeys.contains(progressKey)) {
                uniqueProgressKeys.add(progressKey);
                progressDetails.add({
                  'Progress_Date': item['Progress_Date'],
                  'Notes': item['Notes'],
                });
              }
            }
          }

          // Sort progressDetails by Progress_Date in descending order (latest first)
          progressDetails.sort((a, b) {
            return DateTime.parse(b['Progress_Date'])
                .compareTo(DateTime.parse(a['Progress_Date']));
          });

          // Collect vital details
          List<Map<String, dynamic>> vitalDetails = [];
          Set<String> uniqueVitalKeys = {};

          for (var item in data) {
            print("Checking item: $item");

            // Check if all necessary fields are present
            if (item.containsKey('Bed_no') &&
                item.containsKey('Ward_no') &&
                item['Bed_no'] == bedNo &&
                item['Ward_no'] == patient['Ward_no']) {
              // Log condition check success
              print(
                  "Condition met for item with Admission number: ${item['Admission_number']}");

              // Ensure Recorded_at field is present and valid (as a string)
              if (item.containsKey('Recorded_at') &&
                  item['Recorded_at'] != null &&
                  item['Recorded_at'] != "") {
                try {
                  // Directly use Recorded_at as a string without conversion
                  String recordedAt = item['Recorded_at'];
                  print("Recorded_at used directly: $recordedAt");

                  // Check for Blood Pressure, if it exists
                  if (item.containsKey('Blood_pressure') &&
                      item['Blood_pressure'] != null &&
                      item['Blood_pressure'] != "") {
                    final vitalKey = '$recordedAt-${item['Blood_pressure']}';

                    if (!uniqueVitalKeys.contains(vitalKey)) {
                      uniqueVitalKeys.add(vitalKey);

                      // Add to vitalDetails list
                      vitalDetails.add({
                        'Recorded_at': recordedAt,
                        'Blood_pressure': item['Blood_pressure'] ?? 'N/A',
                        'Respiration_rate': item['Respiration_rate'] ?? 'N/A',
                        'Pulse_rate': item['Pulse_rate'] ?? 'N/A',
                        'Oxygen_saturation': item['Oxygen_saturation'] ?? 'N/A',
                        'Temperature': item['Temperature'] ?? 'N/A',
                        'Random_blood_sugar':
                            item['Random_blood_sugar'] ?? 'N/A',
                      });

                      print("Vital details added: ${vitalDetails.last}");
                    } else {
                      print("Duplicate vital key found: $vitalKey");
                    }
                  } else {
                    print("Missing or empty Blood_pressure in item: $item");
                  }
                } catch (e) {
                  print(
                      "Error processing Recorded_at: ${item['Recorded_at']} - $e");
                }
              } else {
                print("Missing or invalid Recorded_at for item: $item");
              }
            } else {
              print(
                  "Condition not met for item with Admission number: ${item['Admission_number']}");
            }
          }

          // Sort vitalDetails by Recorded_at in descending order (latest first)
          vitalDetails.sort((a, b) {
            return DateTime.parse(b['Recorded_at'])
                .compareTo(DateTime.parse(a['Recorded_at']));
          });

          // Final check on vitalDetails
          print("Final vitalDetails list: $vitalDetails");

          // Collect consultation details and remove duplicates based on unique fields
          List<Map<String, dynamic>> consultationDetails = [];
          Set<String> uniqueConsultationKeys = {};

          for (var item in data) {
            if (item.containsKey('Bed_no') &&
                item.containsKey('Ward_no') &&
                item['Bed_no'] == bedNo &&
                item['Ward_no'] == patient['Ward_no']) {
              final consultationKey =
                  '${item['ConsultationTime']}-${item['Requesting_Physician']}-${item['ConsultationDate']}';
              if (!uniqueConsultationKeys.contains(consultationKey)) {
                uniqueConsultationKeys.add(consultationKey);
                consultationDetails.add({
                  'Consulting_Department':
                      item['ConsultingPhysicianDepartment'] ??
                          'Unknown Department',
                  "consultingName": item["ConsultingDoctorName"],
                  "Status": item["Status"],
                  'Requesting_Department':
                      item['RequestingPhysicianDepartment'] ??
                          'Unknown Department',
                  'Requesting_Doctor_ID':
                      item['Requesting_Physician'] ?? 'Unknown ID',
                  'Requesting_Doctor_Name':
                      item['RequestingPhysicianName'] ?? 'Unknown Name',
                  'ConsultationDate': item['ConsultationDate'] ?? 'N/A',
                  'ConsultationTime': item['ConsultationTime'] ?? 'N/A',
                  'Reason': item['Reason'] ?? 'No reason provided',
                  'Additional_Description': item['Additional_Description'] ??
                      'No description available',
                  'Type_of_Comments':
                      item['Type_of_Comments'] ?? 'No comments available',
                });
              }
            }
          }

          // Sort consultationDetails by ConsultationDate and ConsultationTime in descending order
          consultationDetails.sort((a, b) {
            final dateComparison = DateTime.parse(b['ConsultationDate'])
                .compareTo(DateTime.parse(a['ConsultationDate']));
            if (dateComparison != 0) return dateComparison;
            return DateTime.parse(b['ConsultationTime'])
                .compareTo(DateTime.parse(a['ConsultationTime']));
          });

          // Collect drug details
          List<Map<String, dynamic>> drugDetails = [];
          Set<String> uniqueDrugKeys = {};
          for (var item in data) {
            if (item.containsKey('DrugCommercialName') &&
                item.containsKey('MedicationDate')) {
              final drugKey =
                  '${item['DrugCommercialName']}-${item['MedicationDate']}-${item['MedicationTime']}';
              if (!uniqueDrugKeys.contains(drugKey)) {
                uniqueDrugKeys.add(drugKey);
                drugDetails.add({
                  'Drug_Commercial_Name':
                      item['DrugCommercialName'] ?? 'Unknown Drug',
                  'Drug_Generic_Name':
                      item['DrugGenericName'] ?? 'Unknown Generic Name',
                  'Strength': item['DrugStrength'] ?? 'Unknown Strength',
                  'Dosage': item['Dosage'] ?? 'Unknown Dosage',
                  'Medication_Date': item['MedicationDate'] ?? 'N/A',
                  'Medication_Time': item['MedicationTime'] ?? 'N/A',
                  'Monitored_By': item['Monitored_By'] ?? 'Unknown Monitor',
                  'Shift': item['Shift'] ?? 'Unknown Shift',
                });
              }
            }
          }

          // Sort drugDetails by Medication_Date and Medication_Time in descending order
          drugDetails.sort((a, b) {
            final dateComparison = DateTime.parse(b['Medication_Date'])
                .compareTo(DateTime.parse(a['Medication_Date']));
            if (dateComparison != 0) return dateComparison;
            return DateTime.parse(b['Medication_Time'])
                .compareTo(DateTime.parse(a['Medication_Time']));
          });

          // Construct the filtered patient data
          Map<String, dynamic> filteredPatientData = {
            "PatientName": patient["PatientName"],
            "Admission_no": patient["Admission_no"],
            "Age": patient["Age"],
            "Gender": patient["Gender"],
            "Contact_number": patient["Contact_number"],
            "Alternate_contact_number": patient["Alternate_contact_number"],
            "UserAddress": patient["UserAddress"],
            "Admission_date": patient["Admission_date"],
            "Admission_time": patient["Admission_time"],
            "Mode_of_admission": patient["Mode_of_admission"],
            "AdmittedunderthecareofDr": patient["AdmittedunderthecareofDr"],
            "Receiving_note": patient["Receiving_note"],
            "Ward_no": patient["Ward_no"],
            "Bed_no": patient["Bed_no"],
            "Primary_diagnosis": patient["Primary_diagnosis"],
            "Associate_diagnosis": patient["Associate_diagnosis"],
            "Procedure": patient["Procedure"],
            "Summary": patient["Summary"],
            "Disposal_status": patient["Disposal_status"],
            "Discharge_date": patient["Discharge_date"],
            "Discharge_time": patient["Discharge_time"],
            "NextOfKinName": patient["NextOfKinName"],
            "NextOfKinAddress": patient["NextOfKinAddress"],
            "NextOfKinContact": patient["NextOfKinContact"],
            "Relationship": patient["Relationship"],
            "ProgressDetails": progressDetails,
            "ConsultationDetails": consultationDetails,
            "DrugDetails": drugDetails,
            "vitalDetails": vitalDetails
          };

          setState(() {
            patientData = filteredPatientData;
          });
          Future<Map<String, dynamic>> getLoginInfo() async {
            final prefs = await SharedPreferences.getInstance();
            return {
              'isLoggedIn': prefs.getBool('isLoggedIn') ?? false,
              'userId': prefs.getString('userId'),
              'isDoctor': prefs.getBool('isDoctor') ?? false,
            };
          }

// In your QR scanner or wherever you navigate to OptionsPage:
          final loginInfo = await getLoginInfo();

          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => OptionsPage(
              patientData: patientData!,
            ),
          ));
        } else {
          log('No patient data found.');
        }
      } else {
        log('Error: Server returned status ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching patient data: $e');
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });

    controller.scannedDataStream.listen((scanData) async {
      setState(() {
        result = scanData;
        _isProcessing = true;
      });

      await controller.pauseCamera();

      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (_isProcessing) {
          setState(() => _isProcessing = false);
          _showDelayMessage(
              "Our servers are taking longer than usual to respond. "
              "Please be patient while we process your request.\n\n"
              "This might be due to high traffic or network conditions.");
        }
      });

      _longTimeoutTimer = Timer(const Duration(minutes: 1), () {
        if (_isProcessing) {
          setState(() => _isProcessing = false);
          _showErrorDialog(
              "We couldn't complete your request within the expected time.\n\n"
              "Possible causes:\n"
              "• Poor network connection\n"
              "• Server maintenance\n"
              "• High system load\n\n"
              "Please try again later or contact support if the issue persists.");
        }
      });

      try {
        if (result != null && result!.code != null) {
          String qrData = result!.code!.trim();
          List<String> data = qrData.split(' ');

          // Handle case when QR contains only ward number (1 value)
          if (data.length == 1) {
            String wardNo = data[0].trim();
            if (wardNo.isNotEmpty && RegExp(r'^\d+$').hasMatch(wardNo)) {
              print('Parsed Ward No: $wardNo');
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (context) => edit.SessionChecker(
                  wardNo: wardNo,
                  bedNo: '',
                  admissionNo: '',
                  sheetName: '',
                ),
              ));
            } else {
              _showErrorDialog("Invalid QR code format. Please try again.");
            }
          }
          // Handle case when QR contains both ward and bed numbers (2 values)
          else if (data.length == 2) {
            int wardNo = int.tryParse(data[0]) ?? -1;
            int bedNo = int.tryParse(data[1]) ?? -1;

            if (wardNo != -1 && bedNo != -1) {
              final response = await http.get(
                Uri.parse(
                    'http://10.57.148.47:1232/patient?ward_no=$wardNo&bed_no=$bedNo'),
                headers: {'Content-Type': 'application/json'},
              ).timeout(const Duration(seconds: 20));

              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data is List && data.isNotEmpty) {
                  await _fetchPatientData(wardNo, bedNo);
                } else {
                  _showBedStatusDialog(
                      "Bed Availability",
                      "🏥 Ward $wardNo, Bed $bedNo is currently available.\n\n"
                          "This bed is not assigned to any patient at the moment.\n"
                          "You may proceed with new patient admission if needed.");
                }
              } else {
                _showErrorDialog(
                    "We encountered an issue verifying bed status.\n\n"
                    "Status Code: ${response.statusCode}\n"
                    "Please ensure:\n"
                    "• You're connected to the network\n"
                    "• The bed/ward numbers are correct\n"
                    "• The system is operational");
              }
            } else {
              _showErrorDialog("Invalid QR Code Format\n\n"
                  "The scanned code doesn't contain valid ward/bed numbers.\n"
                  "Expected format: '[WardNumber] [BedNumber]' (e.g., '002 3')");
            }
          } else {
            _showErrorDialog("Invalid QR Code Format\n\n"
                "The scanned code doesn't match the expected format.\n"
                "Please scan a valid ward/bed QR code.");
          }
        }
      } on TimeoutException {
        _showErrorDialog("Request Timeout\n\n"
            "The operation timed out while communicating with the server.\n"
            "This is usually temporary - please try again.");
      } on http.ClientException catch (e) {
        _showErrorDialog("Network Error\n\n"
            "Couldn't connect to the server:\n"
            "${e.message}\n\n"
            "Please check your network connection.");
      } catch (e) {
        _showErrorDialog("Unexpected Error\n\n"
            "We encountered an unexpected problem:\n"
            "${e.toString()}\n\n"
            "Please report this issue to technical support.");
      } finally {
        _timeoutTimer?.cancel();
        _longTimeoutTimer?.cancel();
        setState(() => _isProcessing = false);
      }
    });
  }

  void _showDelayMessage(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CustomAlertDialog(
          type: AlertType.delay,
          title: "Processing Delay",
          message: message,
          primaryAction: () {
            Navigator.of(context).pop();
            controller?.resumeCamera();
          },
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CustomAlertDialog(
          type: AlertType.error,
          title: "Operation Failed",
          message: message,
          primaryAction: () {
            Navigator.of(context).pop();
            controller?.resumeCamera();
          },
          secondaryAction: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _showBedStatusDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CustomAlertDialog(
          type: AlertType.info,
          title: title,
          message: message,
          primaryAction: () {
            Navigator.of(context).pop();
            controller?.resumeCamera();
          },
        );
      },
    );
  }

  Widget _buildQrView(BuildContext context) {
    final scanArea = MediaQuery.of(context).size.width * 0.7;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.blueAccent,
        borderRadius: 10,
        borderLength: 40,
        borderWidth: 8,
        cutOutSize: scanArea,
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinKitFadingCircle(
              color: Colors.white,
              size: 50.0,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _longTimeoutTimer?.cancel();
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Remove observer
    super.dispose();
  }
}

enum AlertType { success, error, warning, info, delay }

class CustomAlertDialog extends StatelessWidget {
  final AlertType type;
  final String title;
  final String message;
  final VoidCallback primaryAction;
  final VoidCallback? secondaryAction;
  final String? primaryText;
  final String? secondaryText;

  const CustomAlertDialog({
    Key? key,
    required this.type,
    required this.title,
    required this.message,
    required this.primaryAction,
    this.secondaryAction,
    this.primaryText,
    this.secondaryText,
  }) : super(key: key);

  Color get _primaryColor {
    switch (type) {
      case AlertType.success:
        return Colors.green.shade600;
      case AlertType.error:
        return Colors.red.shade600;
      case AlertType.warning:
        return Colors.orange.shade600;
      case AlertType.info:
        return Colors.blue.shade600;
      case AlertType.delay:
        return Colors.purple.shade600;
    }
  }

  IconData get _icon {
    switch (type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning;
      case AlertType.info:
        return Icons.info;
      case AlertType.delay:
        return Icons.timer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              offset: Offset(0.0, 10.0),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 40,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (secondaryAction != null)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: _primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: secondaryAction,
                      child: Text(
                        secondaryText ?? "Cancel",
                        style: TextStyle(color: _primaryColor),
                      ),
                    ),
                  ),
                if (secondaryAction != null) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: primaryAction,
                    child: Text(
                      primaryText ?? "OK",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OptionsPage2 extends StatelessWidget {
  final Map<String, dynamic> patientData;
  final bool isLoggedIn;
  final String? userId;
  final bool isDoctor;

  const OptionsPage2({
    Key? key,
    required this.patientData,
    this.isLoggedIn = false,
    this.userId,
    this.isDoctor = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Options',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          if (isLoggedIn && userId != null)
            isDoctor
                ? DoctorProfileMenu(userId: userId!)
                : NurseProfileMenu(userId: userId!),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFE3F2FD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Patient Data Found! Select an option:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildOptionButton(context, 'Registration Sheet'),
                  _buildOptionButton(context, 'Receiving Notes'),
                  _buildOptionButton(context, 'Drug Sheet'),
                  _buildOptionButton(context, 'Progress Report'),
                  _buildOptionButton(context, 'Consultation Sheet'),
                  _buildOptionButton(context, 'Discharged Sheet'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 4,
        ),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => DetailPageWithoutEdit(
                sheetName: title, patientData: patientData),
          ));
        },
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class OptionsPage extends StatefulWidget {
  final Map<String, dynamic> patientData;
  final bool fromEditPage;

  const OptionsPage({
    Key? key,
    required this.patientData,
    this.fromEditPage = false,
  }) : super(key: key);

  @override
  _OptionsPageState createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage>
    with RouteAware, WidgetsBindingObserver {
  final AppRouteObserver _routeObserver = AppRouteObserver();

  late Map<String, dynamic> _currentPatientData = {};

  bool _isLoggedIn = false;
  bool _isDoctor = false;
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadUserData().then((_) => _fetchInitialPatientData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app resumes, check if we should navigate back to scanner
      _onWillPop();
    }
  }

  Future<bool> _onWillPop() async {
    return true; // Allow normal back navigation for non-doctors
  }

  Future<void> _fetchInitialPatientData() async {
    try {
      // Extract ward and bed from route parameters or other source if needed
      // Or could add them as separate required parameters
      final wardNo =
          int.tryParse(widget.patientData['Ward_no']?.toString() ?? '');
      final bedNo =
          int.tryParse(widget.patientData['Bed_no']?.toString() ?? '');

      if (wardNo != null && bedNo != null) {
        final data = await fetchPatientData(wardNo, bedNo);
        if (mounted) {
          setState(() {
            _currentPatientData = data;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Invalid ward or bed number');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load patient data: $e')),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Called when returning to this page
    _refreshData();
  }

  Future<void> _refreshData() async {
    try {
      final wardNo = int.tryParse(_currentPatientData['Ward_no'].toString());
      final bedNo = int.tryParse(_currentPatientData['Bed_no'].toString());

      if (wardNo != null && bedNo != null) {
        final updatedData = await fetchPatientData(wardNo, bedNo);
        if (mounted) {
          setState(() {
            _currentPatientData = updatedData;
          });
        }
      } else {
        throw Exception("Invalid ward or bed number");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh data: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> fetchPatientData(int wardNo, int bedNo) async {
    const apiUrl = 'http://10.57.148.47:1232/patient';
    try {
      final response = await http.get(
        Uri.parse('$apiUrl?ward_no=$wardNo&bed_no=$bedNo'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final patient = data[0];

          // Collect progress notes
          List<Map<String, dynamic>> progressDetails = [];
          Set<String> uniqueProgressKeys = {};
          for (var item in data) {
            if (item.containsKey('Progress_Date') &&
                item.containsKey('Notes')) {
              final progressKey = '${item['Progress_Date']}-${item['Notes']}';
              if (!uniqueProgressKeys.contains(progressKey)) {
                uniqueProgressKeys.add(progressKey);
                progressDetails.add({
                  'Progress_Date': item['Progress_Date'],
                  'Notes': item['Notes'],
                });
              }
            }
          }

          // Sort progressDetails by date (newest first)
          progressDetails.sort((a, b) {
            return DateTime.parse(b['Progress_Date'])
                .compareTo(DateTime.parse(a['Progress_Date']));
          });

          // Collect vital details
          List<Map<String, dynamic>> vitalDetails = [];
          Set<String> uniqueVitalKeys = {};
          for (var item in data) {
            if (item.containsKey('Recorded_at') &&
                item['Recorded_at'] != null) {
              final vitalKey =
                  '${item['Recorded_at']}-${item['Blood_pressure']}';
              if (!uniqueVitalKeys.contains(vitalKey)) {
                uniqueVitalKeys.add(vitalKey);
                vitalDetails.add({
                  'Recorded_at': item['Recorded_at'],
                  'Blood_pressure': item['Blood_pressure'] ?? 'N/A',
                  'Respiration_rate': item['Respiration_rate'] ?? 'N/A',
                  'Pulse_rate': item['Pulse_rate'] ?? 'N/A',
                  'Oxygen_saturation': item['Oxygen_saturation'] ?? 'N/A',
                  'Temperature': item['Temperature'] ?? 'N/A',
                  'Random_blood_sugar': item['Random_blood_sugar'] ?? 'N/A',
                });
              }
            }
          }

          // Sort vitalDetails by date (newest first)
          vitalDetails.sort((a, b) {
            return DateTime.parse(b['Recorded_at'])
                .compareTo(DateTime.parse(a['Recorded_at']));
          });

          // Collect consultation details
          List<Map<String, dynamic>> consultationDetails = [];
          Set<String> uniqueConsultationKeys = {};
          for (var item in data) {
            if (item.containsKey('ConsultationDate') &&
                item.containsKey('ConsultationTime')) {
              final consultationKey =
                  '${item['ConsultationDate']}-${item['ConsultationTime']}';
              if (!uniqueConsultationKeys.contains(consultationKey)) {
                uniqueConsultationKeys.add(consultationKey);
                consultationDetails.add({
                  'Consulting_Department':
                      item['ConsultingPhysicianDepartment'] ??
                          'Unknown Department',
                  'consultingName': item['ConsultingDoctorName'] ?? 'Unknown',
                  'Status': item['Status'] ?? 'N/A',
                  'Requesting_Department':
                      item['RequestingPhysicianDepartment'] ??
                          'Unknown Department',
                  'Requesting_Doctor_ID':
                      item['Requesting_Physician'] ?? 'Unknown ID',
                  'Requesting_Doctor_Name':
                      item['RequestingPhysicianName'] ?? 'Unknown Name',
                  'ConsultationDate': item['ConsultationDate'] ?? 'N/A',
                  'ConsultationTime': item['ConsultationTime'] ?? 'N/A',
                  'Reason': item['Reason'] ?? 'No reason provided',
                  'Additional_Description': item['Additional_Description'] ??
                      'No description available',
                  'Type_of_Comments':
                      item['Type_of_Comments'] ?? 'No comments available',
                });
              }
            }
          }

          // Sort consultationDetails by date (newest first)
          consultationDetails.sort((a, b) {
            final dateComparison = DateTime.parse(b['ConsultationDate'])
                .compareTo(DateTime.parse(a['ConsultationDate']));
            if (dateComparison != 0) return dateComparison;
            return DateTime.parse(b['ConsultationTime'])
                .compareTo(DateTime.parse(a['ConsultationTime']));
          });

          // Collect drug details
          List<Map<String, dynamic>> drugDetails = [];
          Set<String> uniqueDrugKeys = {};
          for (var item in data) {
            if (item.containsKey('DrugCommercialName') &&
                item.containsKey('MedicationDate')) {
              final drugKey =
                  '${item['DrugCommercialName']}-${item['MedicationDate']}-${item['MedicationTime']}';
              if (!uniqueDrugKeys.contains(drugKey)) {
                uniqueDrugKeys.add(drugKey);
                drugDetails.add({
                  'Drug_Commercial_Name':
                      item['DrugCommercialName'] ?? 'Unknown Drug',
                  'Drug_Generic_Name':
                      item['DrugGenericName'] ?? 'Unknown Generic Name',
                  'Strength': item['DrugStrength'] ?? 'Unknown Strength',
                  'Dosage': item['Dosage'] ?? 'Unknown Dosage',
                  'Medication_Date': item['MedicationDate'] ?? 'N/A',
                  'Medication_Time': item['MedicationTime'] ?? 'N/A',
                  'Monitored_By': item['Monitored_By'] ?? 'Unknown Monitor',
                  'Shift': item['Shift'] ?? 'Unknown Shift',
                });
              }
            }
          }

          // Sort drugDetails by date (newest first)
          drugDetails.sort((a, b) {
            final dateComparison = DateTime.parse(b['Medication_Date'])
                .compareTo(DateTime.parse(a['Medication_Date']));
            if (dateComparison != 0) return dateComparison;
            return DateTime.parse(b['Medication_Time'])
                .compareTo(DateTime.parse(a['Medication_Time']));
          });

          // Construct the final patient data structure
          return {
            "PatientName": patient["PatientName"],
            "Admission_no": patient["Admission_no"],
            "Age": patient["Age"],
            "Gender": patient["Gender"],
            "Contact_number": patient["Contact_number"],
            "Alternate_contact_number": patient["Alternate_contact_number"],
            "UserAddress": patient["UserAddress"],
            "Admission_date": patient["Admission_date"],
            "Admission_time": patient["Admission_time"],
            "Mode_of_admission": patient["Mode_of_admission"],
            "AdmittedunderthecareofDr": patient["AdmittedunderthecareofDr"],
            "Receiving_note": patient["Receiving_note"],
            "Ward_no": patient["Ward_no"],
            "Bed_no": patient["Bed_no"],
            "Primary_diagnosis": patient["Primary_diagnosis"],
            "Associate_diagnosis": patient["Associate_diagnosis"],
            "Procedure": patient["Procedure"],
            "Summary": patient["Summary"],
            "Disposal_status": patient["Disposal_status"],
            "Discharge_date": patient["Discharge_date"],
            "Discharge_time": patient["Discharge_time"],
            "NextOfKinName": patient["NextOfKinName"],
            "NextOfKinAddress": patient["NextOfKinAddress"],
            "NextOfKinContact": patient["NextOfKinContact"],
            "Relationship": patient["Relationship"],
            "ProgressDetails": progressDetails,
            "ConsultationDetails": consultationDetails,
            "DrugDetails": drugDetails,
            "vitalDetails": vitalDetails,
          };
        } else {
          throw Exception('No patient data found for Ward $wardNo, Bed $bedNo');
        }
      } else {
        throw Exception('Failed to fetch patient data: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching patient data: $e');
      rethrow; // Re-throw to handle in the calling function
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        _isDoctor = prefs.getBool('isDoctor') ?? false;
        _userId = prefs.getString('userId') ?? prefs.getString('doctorId');
      });
    }
  }

  Widget _buildOptionButton(
      BuildContext context, String title, IconData icon, Color iconColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(
            builder: (context) => DetailPage(
              sheetName: title,
              patientData: _currentPatientData,
            ),
          ))
              .then((_) {
            // This callback runs when you return from the DetailPage
            _refreshData();
          });
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(
              color: Colors.blue,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          // Always go to QR scanner, but handle differently if coming from edit
          if (widget.fromEditPage) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const QRViewExample()),
              (route) => false,
            );
          } else {
            Navigator.of(context).popUntil((route) => route.isFirst);
            if (!Navigator.of(context).canPop()) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const QRViewExample()),
              );
            }
          }
          return false;
        },
        child: Scaffold(
          body: Column(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.local_hospital,
                                          size: 18,
                                          color: Color.fromARGB(
                                              255, 135, 206, 251)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ward: ${_currentPatientData["Ward_no"]}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.hotel,
                                          size: 18,
                                          color: Color.fromARGB(
                                              255, 135, 206, 251)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Bed: ${_currentPatientData["Bed_no"]}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color.fromARGB(
                                              255, 135, 206, 251),
                                          width: 1),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.visibility,
                                            size: 16,
                                            color:
                                                Color.fromARGB(255, 0, 0, 140)),
                                        SizedBox(width: 9),
                                        Text(
                                          'View Mode',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Color.fromARGB(
                                                  255, 0, 0, 140),
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isLoggedIn && _userId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: _isDoctor
                                          ? DoctorProfileMenu(userId: _userId!)
                                          : NurseProfileMenu(userId: _userId!),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const BreathingAnimation(
                          child: Icon(Icons.medical_services,
                              size: 60, color: Color(0xFF00008C)),
                        ),
                        const SizedBox(height: 0),
                        const Text(
                          'Patient Records Overview',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 0, 0, 140)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Select a document to view detailed information:',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 0, 140)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildOptionButton(context, 'Registration Sheet',
                              Icons.assignment, Colors.orange),
                          _buildOptionButton(context, 'Receiving Notes',
                              Icons.note_add, Colors.purple),
                          _buildOptionButton(context, 'Drug Sheet',
                              Icons.medication, Colors.indigo),
                          _buildOptionButton(context, 'Progress Report',
                              Icons.timeline, Colors.green),
                          _buildOptionButton(context, 'Consultation Sheet',
                              Icons.people, Colors.blue),
                          _buildOptionButton(
                              context,
                              'Discharged Sheet',
                              Icons.copy,
                              const Color.fromARGB(255, 214, 19, 156)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}

class AppRouteObserver extends RouteObserver<PageRoute> {}

class AnimatedText extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final Duration duration;
  final bool loop;

  const AnimatedText({
    required this.text,
    required this.textStyle,
    required this.duration,
    this.loop = false,
    Key? key,
  }) : super(key: key);

  @override
  _AnimatedTextState createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = IntTween(
      begin: 0,
      end: widget.text.length,
    ).animate(_controller);

    _controller.forward();

    if (widget.loop) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(seconds: 1), () {
            _controller.reverse();
          });
        } else if (status == AnimationStatus.dismissed) {
          Future.delayed(const Duration(seconds: 1), () {
            _controller.forward();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final displayedText = widget.text.substring(0, _animation.value);
        return Text(
          displayedText,
          style: widget.textStyle,
        );
      },
    );
  }
}

class DetailPage extends StatefulWidget {
  final bool showAppBar;
  final String sheetName;
  final Map<String, dynamic> patientData;
  final bool showEditButton;

  const DetailPage({
    Key? key,
    this.showAppBar = true,
    required this.sheetName,
    required this.patientData,
    this.showEditButton = true,
  }) : super(key: key);

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool isEditMode = false;
  Map<String, String> doctorNames = {};
  bool isDoctorDataLoaded = false;
  bool _isLoggedIn = false;
  bool _isDoctor = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadDoctorNames();
    _fetchPrescriptionData();
    _checkLoginStatus();
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showHint = false); // Hide hint after 3 seconds
      }
    });
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _isDoctor = prefs.getBool('isDoctor') ?? false;
      _userId = prefs.getString('doctorId');
    });
  }

  Future<void> _loadDoctorNames() async {
    try {
      doctorNames = await fetchDoctorNames();
      setState(() {
        isDoctorDataLoaded = true;
      });
    } catch (e) {
      print('Error loading doctor names: $e');
    }
  }

  bool _showHint = true; // Track if we should show the hint

  @override
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          // Navigate back to OptionsPage instead of scanner
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => OptionsPage(
                patientData: widget.patientData,
              ),
            ),
          );
          return false; // Prevent default back behavior
        },
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: isEditMode ? _buildEditMode() : _buildViewMode(),
                      ),
                    ],
                  ),
                ),
                if (widget.showEditButton &&
                    widget.sheetName != 'Registration Sheet')
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20, right: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showHint) // Show text hint briefly
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue[800],
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black26, blurRadius: 5)
                                ],
                              ),
                              child: Text(
                                "Edit Details",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
                          Tooltip(
                            message: "Edit Details",
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => edit.SessionChecker(
                                      sheetName: widget.sheetName,
                                      admissionNo:
                                          widget.patientData['Admission_no'] ??
                                              'N/A',
                                      bedNo: widget.patientData['Bed_no']
                                              ?.toString() ??
                                          'N/A',
                                      wardNo: widget.patientData['Ward_no']
                                              ?.toString() ??
                                          'N/A',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(50),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.blue[800],
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ));
  }

  Widget _buildViewMode() {
    switch (widget.sheetName) {
      case 'Progress Report':
        return _buildProgressReport();
      case 'Consultation Sheet':
        return _buildConsultationSheet();
      case 'Drug Sheet':
        return _buildDrugSheet();
      case 'Receiving Notes':
        return _buildReceivingNotes();
      case 'Registration Sheet':
        return _buildDefaultDetails();
      case 'Discharged Sheet':
        return DischargeSheet(
          admissionNo: widget.patientData['Admission_no'] ?? 'N/A',
          name: widget.patientData['PatientName'] ?? 'N/A',
          date: widget.patientData['Admission_date'] ?? 'N/A',
        );
      default:
        return _buildDefaultDetails();
    }
  }

  Widget _buildEditMode() {
    return Center(
      child: Text(
        'Edit mode for "${widget.sheetName}" is not implemented yet.',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDefaultDetails() {
    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.25,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00008C), const Color(0xFF659CDF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(60),
              bottomRight: Radius.circular(60),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Breathing Animation for Icon
                const BreathingAnimation(
                  child: Icon(
                    Icons.assignment,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                // Breathing Animation for Heading
                const BreathingAnimation(
                  child: Text(
                    'Registration Sheet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ),
        // Bottom Portion with White Background
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Name
                  _buildDetailCardWithIcon(
                    'Patient Name',
                    widget.patientData['PatientName'],
                    Icons.person,
                    Colors.blue,
                  ),

                  // Admission Number
                  _buildDetailCardWithIcon(
                    'Admission Number',
                    widget.patientData['Admission_no'],
                    Icons.confirmation_number,
                    Colors.orange,
                  ),

                  // Age and Gender in one row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCardWithIcon(
                          'Age',
                          widget.patientData['Age'],
                          Icons.cake,
                          Colors.pink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailCardWithIcon(
                          'Gender',
                          widget.patientData['Gender'] == 'M'
                              ? 'Male'
                              : 'Female',
                          widget.patientData['Gender'] == 'M'
                              ? Icons.male
                              : Icons.female,
                          widget.patientData['Gender'] == 'M'
                              ? Colors.blue
                              : Colors.pink,
                        ),
                      ),
                    ],
                  ),

                  // Contact Information
                  _buildDetailCardWithIcon(
                    'Contact Number',
                    widget.patientData['Contact_number'],
                    Icons.phone,
                    Colors.green,
                  ),

                  _buildDetailCardWithIcon(
                    'Alternate Contact',
                    widget.patientData['Alternate_contact_number'],
                    Icons.phone_android,
                    Colors.lightGreen,
                  ),

                  // Address
                  _buildDetailCardWithIcon(
                    'Address',
                    widget.patientData['UserAddress'],
                    Icons.home,
                    Colors.brown,
                  ),

                  // Admission Date and Time in one row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCardWithIcon(
                          'Admission Date',
                          _formatDate(widget.patientData['Admission_date']),
                          Icons.calendar_today,
                          Colors.purple,
                          needsMarquee: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailCardWithIcon(
                          'Admission Time',
                          _formatTime(widget.patientData['Admission_time']),
                          Icons.access_time,
                          Colors.deepPurple,
                          needsMarquee: true,
                        ),
                      ),
                    ],
                  ),

                  // Mode of Admission
                  _buildDetailCardWithIcon(
                    'Mode of Admission',
                    widget.patientData['Mode_of_admission'],
                    Icons.directions_walk,
                    Colors.teal,
                  ),

                  // Doctor in Charge
                  _buildDetailCardWithIcon(
                    'Admitted Under Care of Dr',
                    widget.patientData['AdmittedunderthecareofDr'],
                    Icons.medical_services,
                    Colors.red,
                  ),

                  // Bed and Ward in one row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCardWithIcon(
                          'Ward Number',
                          widget.patientData['Ward_no'],
                          Icons.king_bed,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailCardWithIcon(
                          'Bed Number',
                          widget.patientData['Bed_no'],
                          Icons.bed,
                          Colors.indigo,
                        ),
                      ),
                    ],
                  ),

                  // Diagnosis Information
                  _buildDetailCardWithIcon(
                    'Primary Diagnosis',
                    widget.patientData['Primary_diagnosis'],
                    Icons.healing,
                    Colors.redAccent,
                  ),

                  _buildDetailCardWithIcon(
                    'Associate Diagnosis',
                    widget.patientData['Associate_diagnosis'],
                    Icons.health_and_safety,
                    Colors.orangeAccent,
                  ),

                  // Procedure and Summary
                  _buildDetailCardWithIcon(
                    'Procedure',
                    widget.patientData['Procedure'],
                    Icons.medical_services,
                    Colors.blueGrey,
                  ),

                  _buildDetailCardWithIcon(
                    'Summary',
                    widget.patientData['Summary'],
                    Icons.summarize,
                    Colors.grey,
                  ),

                  // Discharge Information
                  _buildDetailCardWithIcon(
                    'Disposal Status',
                    widget.patientData['Disposal_status'],
                    Icons.exit_to_app,
                    Colors.amber,
                  ),

                  // Discharge Date and Time in one row (with marquee effect)
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCardWithIcon(
                          'Discharge Date',
                          _formatDate(widget.patientData['Discharge_date']),
                          Icons.calendar_today,
                          Colors.purpleAccent,
                          needsMarquee: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailCardWithIcon(
                          'Discharge Time',
                          _formatTime(widget.patientData['Discharge_time']),
                          Icons.access_time,
                          Colors.deepPurpleAccent,
                          needsMarquee: true,
                        ),
                      ),
                    ],
                  ),

                  // Next of Kin Information
                  _buildDetailCardWithIcon(
                    'Next of Kin Name',
                    widget.patientData['NextOfKinName'],
                    Icons.family_restroom,
                    Colors.cyan,
                  ),

                  _buildDetailCardWithIcon(
                    'Next of Kin Address',
                    widget.patientData['NextOfKinAddress'],
                    Icons.location_city,
                    Colors.blueGrey,
                  ),

                  _buildDetailCardWithIcon(
                    'Next of Kin Contact',
                    widget.patientData['NextOfKinContact'],
                    Icons.contact_phone,
                    Colors.lightBlue,
                  ),

                  _buildDetailCardWithIcon(
                    'Relationship',
                    widget.patientData['Relationship'],
                    Icons.people,
                    Colors.indigoAccent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCardWithIcon(
      String label, dynamic value, IconData icon, Color iconColor,
      {bool needsMarquee = false}) {
    if (value == null ||
        value.toString().isEmpty ||
        value.toString() == 'N/A') {
      return const SizedBox();
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0xFF659CDF),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF87CEFB),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 20,
                    child: needsMarquee
                        ? Marquee(
                            text: label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                            blankSpace: 20,
                            velocity: 30,
                            pauseAfterRound: Duration(seconds: 0),
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, dynamic value) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(
          color: Color(0xFF00008C),
          width: 2.0,
        ),
      ),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        subtitle: Text(
          value?.toString() ?? "N/A",
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildDrugSheet() {
    final patientName =
        widget.patientData['PatientName']?.toString() ?? 'Unknown';
    final admissionNo = widget.patientData['Admission_no']?.toString() ?? 'N/A';
    final drugDetails =
        widget.patientData['DrugDetails'] as List<Map<String, dynamic>>? ?? [];
    final bedNo = widget.patientData['Bed_no']?.toString() ?? 'N/A';
    final wardNo = widget.patientData['Ward_no']?.toString() ?? 'N/A';
    final admissionDate =
        _formatDate(widget.patientData['Admission_date']?.toString()) ?? 'N/A';

    bool isDrugSheetEmpty = drugDetails.isEmpty ||
        drugDetails.every((drug) =>
            drug['Monitored_By'] == null ||
            drug['Monitored_By'] == 'Unknown Monitor' ||
            drug['Monitored_By'].toString().isEmpty);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF00008C), const Color(0xFF659CDF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(60),
                    bottomRight: Radius.circular(60),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      const BreathingAnimation(
                        child: Icon(
                          Icons.medication,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const BreathingAnimation(
                        child: Text(
                          'Medication Records',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TabBar(
                          tabs: [
                            Tab(
                                text: 'Drug Sheet',
                                icon: Icon(Icons.medication)),
                            Tab(
                                text: 'Prescription',
                                icon: Icon(Icons.note_add)),
                          ],
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withOpacity(0.7),
                          indicatorColor: Colors.white,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.3),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      height: constraints.maxHeight,
                      child: TabBarView(
                        children: [
                          // Drug Sheet Tab with SingleChildScrollView
                          SingleChildScrollView(
                            padding: EdgeInsets.only(
                              bottom:
                                  MediaQuery.of(context).padding.bottom + 16,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPatientInfoCard(patientName,
                                        admissionDate, wardNo, bedNo),
                                    const SizedBox(height: 16),
                                    if (isDrugSheetEmpty)
                                      _buildNoDataMessage(
                                        icon: Icons.medication_outlined,
                                        message:
                                            'No drug details available yet',
                                      )
                                    else ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          'Prescribed Drugs',
                                          style: TextStyle(
                                            fontSize: 20, // Reduced from 22
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF00008C),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        children:
                                            drugDetails.map<Widget>((drug) {
                                          final monitoredBy = isDoctorDataLoaded
                                              ? doctorNames[
                                                      drug['Monitored_By']] ??
                                                  'Unknown Doctor'
                                              : 'Loading...';
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            child: _buildDrugCard(
                                                drug, monitoredBy),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Prescription Sheet Tab
                          _buildPrescriptionSheetContent(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrescriptionSheetContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Patient Details Section
          _buildSectionBox(
            title: "Patient Details",
            children: [
              _buildInfoRowWithIcon(
                label: "Patient Name",
                value:
                    widget.patientData['PatientName']?.toString() ?? 'Unknown',
                icon: Icons.person,
                iconColor: Colors.blue,
              ),
              _buildInfoRowWithIcon(
                label: "Date of Admission",
                value: _formatDate(
                    widget.patientData['Admission_date']?.toString()),
                icon: Icons.calendar_today,
                iconColor: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Current Prescription Plan Section
          _buildSectionBox(
            title: "Current Prescription Plan",
            children: [
              if (_prescriptionDetails.isEmpty)
                _buildNoDataMessage(
                  icon: Icons.medication_outlined,
                  message: 'No active prescriptions',
                )
              else
                ..._prescriptionDetails
                    .map((prescription) =>
                        _buildPrescriptionItem(prescription, isCurrent: true))
                    .toList(),
            ],
          ),
          const SizedBox(height: 20),

          // Previous Prescription History Section
          _buildSectionBox(
            title: "Previous Prescription History",
            children: [
              if (_pastPrescriptions.isEmpty)
                _buildNoDataMessage(
                  icon: Icons.history,
                  message: 'No previous prescriptions',
                )
              else
                ..._pastPrescriptions
                    .map((prescription) =>
                        _buildPrescriptionItem(prescription, isCurrent: false))
                    .toList(),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPrescriptionItem(Map<String, dynamic> prescription,
      {required bool isCurrent}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color:
          isCurrent ? Colors.white : const Color.fromARGB(255, 225, 229, 248),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    prescription['Commercial_name']?.toString() ??
                        'Unknown Drug',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF103683),
                    ),
                  ),
                ),
                if (!isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Past",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPrescriptionDetailRow(
                    label: "Generic Name",
                    value: prescription['Generic_name']?.toString() ?? 'N/A',
                  ),
                  _buildPrescriptionDetailRow(
                    label: "Strength",
                    value: prescription['Strength']?.toString() ?? 'N/A',
                  ),
                  _buildPrescriptionDetailRow(
                    label: "Dosage",
                    value: prescription['Dosage']?.toString() ?? 'N/A',
                  ),
                ],
              ),
            ),
            Text(
              "Prescribed by: ${prescription['PrescribedByName']?.toString() ?? prescription['Prescribed_by']?.toString() ?? 'Unknown'}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _prescriptionDetails = [];
  Future<void> _fetchPrescriptionData() async {
    try {
      final admissionNo = widget.patientData['Admission_no']?.toString() ?? '';
      if (admissionNo.isEmpty) return;

      final response = await http.get(
        Uri.parse('http://10.57.148.47:1232/prescriptions/$admissionNo'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _prescriptionDetails = List<Map<String, dynamic>>.from(
                data['currentPrescriptions'] ?? []);
            _pastPrescriptions = List<Map<String, dynamic>>.from(
                data['pastPrescriptions'] ?? []);
          });
        }
      } else {
        print('Failed to fetch prescription data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching prescription data: $e');
    }
  }

  List<Map<String, dynamic>> _pastPrescriptions = [];
  Widget _buildPatientInfoCard(
      String patientName, String admissionDate, String wardNo, String bedNo) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF00008C),
          width: 2,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 248, 248, 250),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('👤 Patient Name', patientName),
            _buildInfoRow('📅 Admission Date', admissionDate),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithIcon({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildPrescriptionDetailRow(
      {required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBox({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF00008C), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF87CEFB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00008C),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugCard(Map<String, dynamic> drug, String monitoredBy) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: const Color(0xFF00008C),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, const Color(0xFF87CEFB).withOpacity(0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRowWithIcon(
                  '💊', 'Commercial Name', drug['Drug_Commercial_Name']),
              _buildDetailRowWithIcon(
                  '🧪', 'Generic Name', drug['Drug_Generic_Name']),
              _buildDetailRowWithIcon('📏', 'Strength', drug['Strength']),
              _buildDetailRowWithIcon('🔢', 'Dosage', drug['Dosage']),
              _buildDetailRowWithIcon('📅', 'Medication Date',
                  _formatDate(drug['Medication_Date'])),
              _buildDetailRowWithIcon(
                  '⏰', 'Medication Time', _formatTime(drug['Medication_Time'])),
              _buildDetailRowWithIcon('👨‍⚕️', 'Monitored By', monitoredBy),
            ],
          ),
        ),
      ),
    );
  }

// Helper method to build a detail row with an icon
  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> fetchStaffData() async {
    final response =
        await http.get(Uri.parse('http://10.57.148.47:1232/finddoctor'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load staff data');
    }
  }

  // Helper function to parse and format date
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final dateTime = DateTime.parse(dateString).toLocal();
      return DateFormat('dd-MM-yyyy').format(dateTime);
    } catch (e) {
      return "N/A";
    }
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return "N/A";
    try {
      final dateTime = DateTime.parse(timeString).toLocal();
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return "N/A";
    }
  }

  Future<Map<String, String>> fetchDoctorNames() async {
    final response = await http
        .get(Uri.parse('http://10.57.148.47:1232/departmentsWithDoctors'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      Map<String, String> doctorNames = {};
      for (var dept in data) {
        for (var doctor in dept['Doctors']) {
          doctorNames[doctor['DoctorID'].toString()] = doctor['DoctorName'];
        }
      }
      return doctorNames;
    } else {
      throw Exception('Failed to load doctor data');
    }
  }

  Widget _buildDetailText(String label, dynamic value) {
    String displayValue;
    if (label.contains('Date')) {
      displayValue = _formatDate(value?.toString());
    } else if (label.contains('Time')) {
      displayValue = _formatTime(value?.toString());
    } else {
      displayValue = value?.toString() ?? "N/A";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.blue[800],
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressReport() {
    final patientName =
        widget.patientData['PatientName']?.toString() ?? 'Unknown';
    final admissionNo = widget.patientData['Admission_no']?.toString() ?? 'N/A';
    final admissionDate =
        _formatDate(widget.patientData['Admission_date']?.toString());
    final progressDetails = widget.patientData['ProgressDetails'] ?? [];

    // Check if all progress notes are empty or have default values
    bool isProgressEmpty = progressDetails.isEmpty ||
        progressDetails.every((progress) =>
            progress['Notes'] == null ||
            progress['Notes'] == 'No notes available' ||
            progress['Notes'].toString().isEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00008C), const Color(0xFF659CDF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(60),
                bottomRight: Radius.circular(60),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Breathing Animation for Icon
                  const BreathingAnimation(
                    child: Icon(
                      Icons.timeline,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Breathing Animation for Heading
                  const BreathingAnimation(
                    child: Text(
                      'Progress Report',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient info card with outline
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: const Color(0xFF00008C),
                        width: 2.5,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('👤 Patient Name', patientName),
                          _buildInfoRow('📅 Admission Date', admissionDate),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (isProgressEmpty)
                    _buildNoDataMessage(
                      icon: Icons.note_outlined,
                      message: 'No progress notes available yet',
                    )
                  else ...[
                    _buildSectionHeader('Progress Notes'),
                    Column(
                      children: progressDetails.map<Widget>((progress) {
                        final date =
                            _formatDate(progress['Progress_Date']?.toString());
                        final notes = progress['Notes']?.toString() ??
                            'No notes available';

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: const Color(0xFF00008C),
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  const Color(0xFF87CEFB).withOpacity(0.2)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        '📅',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Date: $date',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF00008C),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '📝',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Notes: $notes',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivingNotes() {
    // Extract all data points
    final patientName =
        widget.patientData['PatientName']?.toString() ?? 'Unknown';
    final age = widget.patientData['Age']?.toString() ?? 'N/A';
    final gender = widget.patientData['Gender']?.toString() ?? 'N/A';
    final admissionDate =
        _formatDate(widget.patientData['Admission_date']?.toString());
    final admissionTime =
        _formatTime(widget.patientData['Admission_time']?.toString());
    final admittedUnder =
        widget.patientData['AdmittedunderthecareofDr']?.toString() ?? 'N/A';
    final receivingNote =
        widget.patientData['Receiving_note']?.toString() ?? 'N/A';
    final bedNo = widget.patientData['Bed_no']?.toString() ?? 'N/A';
    final wardNo = widget.patientData['Ward_no']?.toString() ?? 'N/A';
    final primaryDiagnosis =
        widget.patientData['Primary_diagnosis']?.toString();
    final associatedDiagnosis =
        widget.patientData['Associate_diagnosis']?.toString();
    final procedure = widget.patientData['Procedure']?.toString();
    final vitalsDetails = widget.patientData['vitalDetails'] ?? [];

    // Format gender for display
    final formattedGender = gender == 'M'
        ? 'male'
        : gender == 'F'
            ? 'female'
            : gender.toLowerCase();
    final genderEmoji = gender == 'M'
        ? '👨'
        : gender == 'F'
            ? '👩'
            : '🧑';

    // Create the narrative paragraph
    String patientNarrative =
        '$patientName, a $age year old $formattedGender, was admitted on $admissionDate at $admissionTime '
        'under the care of Dr. $admittedUnder in Ward $wardNo (Bed $bedNo). '
        'Initial assessment notes: $receivingNote';

    // Check if vitals data is invalid
    bool hasInvalidVitals = vitalsDetails.isEmpty ||
        vitalsDetails.every((vital) =>
            vital['Recorded_at'] == null ||
            vital['Recorded_at'].toString().isEmpty ||
            vital['Temperature'] == "N/A" ||
            vital['Temperature'].toString().isEmpty);

    // Check if all relevant fields are empty
    bool isReceivingNotesEmpty = (primaryDiagnosis == null ||
            primaryDiagnosis == 'N/A' ||
            primaryDiagnosis.isEmpty) &&
        (associatedDiagnosis == null ||
            associatedDiagnosis == 'N/A' ||
            associatedDiagnosis.isEmpty) &&
        (procedure == null || procedure == 'N/A' || procedure.isEmpty) &&
        hasInvalidVitals;

    // Create scroll controller for animated references
    final scrollController = ScrollController();

    // Start auto-scrolling animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      const duration = Duration(seconds: 15);
      const distance = 1000.0;

      void animateScroll() {
        scrollController
            .animateTo(
          distance,
          duration: duration,
          curve: Curves.linear,
        )
            .then((_) {
          scrollController.jumpTo(0);
          animateScroll(); // Restart animation
        });
      }

      animateScroll();
    });
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 253, 253),
      body: Column(
        children: [
          ClipPath(
            clipper: CurvedHeaderClipper(),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00008C), const Color(0xFF659CDF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF00008C),
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Receiving Notes",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Patient information card
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00008C),
                        width: 2.5,
                      ),
                    ),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      margin: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 248, 248, 248),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              )
                            ]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientNarrative,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 100,
                      itemBuilder: (context, index) {
                        final items = [
                          _buildQuickReferenceItem('👤', patientName),
                          _buildQuickReferenceItem(genderEmoji, '$age yrs'),
                          _buildQuickReferenceItem('📅', admissionDate),
                          _buildQuickReferenceItem('🛏️', 'Bed $bedNo'),
                          _buildQuickReferenceItem('🏥', 'Ward $wardNo'),
                        ];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: items[index % items.length],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (isReceivingNotesEmpty)
                    _buildNoDataMessage(
                      icon: Icons.note_outlined,
                      message: 'No additional receiving notes available yet',
                    )
                  else ...[
                    if (primaryDiagnosis != null &&
                            primaryDiagnosis.isNotEmpty ||
                        associatedDiagnosis != null &&
                            associatedDiagnosis.isNotEmpty) ...[
                      _buildSectionHeader('Diagnoses'),
                      if (primaryDiagnosis != null &&
                          primaryDiagnosis.isNotEmpty)
                        _buildDetailCard('Primary Diagnosis', primaryDiagnosis),
                      if (associatedDiagnosis != null &&
                          associatedDiagnosis != 'None' &&
                          associatedDiagnosis.isNotEmpty)
                        _buildDetailCard(
                            'Associated Diagnosis', associatedDiagnosis),
                      const SizedBox(height: 20),
                    ],
                    if (procedure != null && procedure.isNotEmpty) ...[
                      _buildSectionHeader('Procedure'),
                      Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: const Color(0xFF00008C),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            procedure!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (!hasInvalidVitals && vitalsDetails.isNotEmpty) ...[
                      _buildSectionHeader('Vitals Details'),
                      Column(
                        children: vitalsDetails
                            .where((vital) =>
                                vital['Recorded_at'] != null &&
                                vital['Recorded_at'].toString().isNotEmpty &&
                                vital['Temperature'] != null &&
                                vital['Temperature'].toString().isNotEmpty)
                            .map<Widget>((vital) {
                          final dateTime = DateTime.parse(vital['Recorded_at']);
                          final date = _formatDate(vital['Recorded_at']);
                          final time = DateFormat('hh:mm a').format(dateTime);

                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(
                                // Added outline
                                color: const Color(0xFF00008C),
                                width: 1.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📅 $date at $time',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF00008C),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      '🌡️ Temperature: ${vital['Temperature']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16)),
                                  Text(
                                      '🩸 Blood Pressure: ${vital['Blood_pressure']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16)),
                                  Text(
                                      '💓 Pulse: ${vital['Pulse_rate']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16)),
                                  Text(
                                      '🌬️ Respiration Rate: ${vital['Respiration_rate']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16)),
                                  Text(
                                      '💧 Oxygen Saturation: ${vital['Oxygen_saturation']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16)),
                                  Text(
                                      '🍬 Random Blood Sugar: ${vital['Random_blood_sugar']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ] else if (vitalsDetails.isNotEmpty) ...[
                      _buildNoDataMessage(
                        icon: Icons.warning,
                        message:
                            'Vitals data incomplete (missing time or temperature)',
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReferenceItem(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[900]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF00008C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithIcon(String emoji, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

// Custom Clipper for Curvy look

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  Widget _buildVitalCard({
    required String date,
    required String temperature,
    required String bloodPressure,
    required String pulse,
    required String respirationRate,
    required String oxy,
    required String randomBloodSugar,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📅 Date: $date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            Text('🌡️ Temperature: $temperature',
                style: const TextStyle(fontSize: 16)),
            Text('🩸 Blood Pressure: $bloodPressure',
                style: const TextStyle(fontSize: 16)),
            Text('💓 Pulse: $pulse', style: const TextStyle(fontSize: 16)),
            Text('🌬️ Respiration Rate: $respirationRate',
                style: const TextStyle(fontSize: 16)),
            Text('💧 Oxygen Saturation: $oxy',
                style: const TextStyle(fontSize: 16)),
            Text('🍬 Random Blood Sugar: $randomBloodSugar',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationSheet() {
    final patientName =
        widget.patientData['PatientName']?.toString() ?? 'Unknown';
    final admissionNo = widget.patientData['Admission_no']?.toString() ?? 'N/A';
    final bedNo = widget.patientData['Bed_no']?.toString() ?? 'N/A';
    final wardNo = widget.patientData['Ward_no']?.toString() ?? 'N/A';
    final consultationDetails = widget.patientData['ConsultationDetails'] ?? [];
    final admissionDate =
        _formatDate(widget.patientData['Admission_date']?.toString());

    // Check if all consultation entries are empty or have default values
    bool isConsultationEmpty = consultationDetails.isEmpty ||
        consultationDetails.every((detail) =>
            (detail['Type_of_Comments'] == "No comments available" ||
                detail['Type_of_Comments'] == 'N/A' ||
                detail['Type_of_Comments'].toString().isEmpty) &&
            (detail['Reason'] == "No reason provided" ||
                detail['Reason'] == 'N/A' ||
                detail['Reason'].toString().isEmpty));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00008C), const Color(0xFF659CDF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(60),
                bottomRight: Radius.circular(60),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Breathing Animation for Icon
                  const BreathingAnimation(
                    child: Icon(
                      Icons.people,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Breathing Animation for Heading
                  const BreathingAnimation(
                    child: Text(
                      'Consultation Sheet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient info card with outline
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: const Color(0xFF00008C),
                        width: 2.5,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('👤 Patient Name', patientName),
                          _buildInfoRow('📅 Admission Date', admissionDate),
                          _buildInfoRow(
                              '🏥 Ward/Bed', 'Ward $wardNo, Bed $bedNo'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Consultation Details Section
                  if (isConsultationEmpty)
                    _buildNoDataMessage(
                      icon: Icons.people_outline,
                      message: 'No consultation details available yet',
                    )
                  else ...[
                    Text(
                      'Consultation Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00008C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: consultationDetails.map<Widget>((detail) {
                        final status = detail['Status']?.toString() ?? 'N/A';
                        final consultname =
                            detail['consultingName']?.toString() ?? 'N/A';
                        final consultingDept =
                            detail['Consulting_Department']?.toString() ??
                                'N/A';
                        final requestingDept =
                            detail['Requesting_Department']?.toString() ??
                                'N/A';
                        final consultationDate =
                            _formatDate(detail['ConsultationDate']?.toString());
                        final consultationTime = TimeUtils.formatTimeForDisplay(
                            detail['ConsultationTime']);
                        final reason = detail['Reason']?.toString() ?? 'N/A';
                        final additionalDescription =
                            detail['Additional_Description']?.toString() ??
                                'N/A';
                        final typeOfComment =
                            detail['Type_of_Comments']?.toString() ?? 'N/A';
                        final reqid =
                            detail['Requesting_Doctor_ID']?.toString() ?? 'N/A';
                        final reqname =
                            detail['Requesting_Doctor_Name']?.toString() ??
                                'N/A';

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: const Color(0xFF00008C),
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  const Color(0xFF87CEFB).withOpacity(0.2)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF103683)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF00008C),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      reason,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF00008C),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    '📅 Timings:',
                                    '$consultationDate at $consultationTime',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDetailRow(
                                    '🏥 Consulting Department',
                                    consultingDept,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    '📥 Requesting Department',
                                    requestingDept,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    '📄 Clinical Notes',
                                    additionalDescription,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    '💬 Type of Comment',
                                    typeOfComment,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '👨‍⚕️',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'Requesting Doctor: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF00008C),
                                                ),
                                              ),
                                              TextSpan(
                                                text: reqname,
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '👨‍⚕️',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'Consulting Doctor: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF00008C),
                                                ),
                                              ),
                                              TextSpan(
                                                text: consultname,
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    '📊 Request Status',
                                    status,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage(
      {required IconData? icon, required String? message}) {
    if (message == null || message == "N/A")
      return const SizedBox(); // Hide widget if message is null or "N/A"

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) // Hide icon if it's null
              Icon(
                icon,
                size: 60,
                color: Colors.grey[400],
              ),
            if (icon != null) const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
