import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'options.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:math';

class WaveClipper extends CustomClipper<Path> {
  final double waveHeight;
  final double wavePhase;

  WaveClipper({required this.waveHeight, required this.wavePhase});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - waveHeight);

    for (double i = 0; i < size.width; i += 10) {
      path.quadraticBezierTo(
        i + 5,
        size.height - waveHeight + (waveHeight * (i + wavePhase) % 20),
        i + 10,
        size.height - waveHeight,
      );
    }

    path.lineTo(size.width, size.height - waveHeight);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class EditPage extends StatefulWidget {
  final String wardNo; // Received from QR Scanner

  const EditPage({Key? key, required this.wardNo}) : super(key: key);

  @override
  _EditPageState createState() => _EditPageState();
}

class _EditPageState extends State<EditPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool rememberMe = false;
  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimationUpper;
  late Animation<double> _fadeAnimationLower;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _lockAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadRememberMe();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimationUpper = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _fadeAnimationLower = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _lockAnimation = Tween<double>(begin: 0.9, end: 1.5).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String userId = prefs.getString('userId') ?? '';
      bool isDoctor = prefs.getBool('isDoctor') ?? false;
      if (userId.isNotEmpty) {
        idController.text = userId;
      }
    });
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    bool? storedRememberMe = prefs.getBool('keep me logged in');
    if (storedRememberMe != null) {
      setState(() {
        rememberMe = storedRememberMe;
      });
    }
  }

  Future<void> handleLogin() async {
    final id = idController.text.trim();
    final password = passwordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter ID and Password')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final requestBody = jsonEncode({
        'userId': id,
        'password': password,
      });

      print('Sending login request with body: $requestBody');

      final response = await http.post(
        Uri.parse('http://10.57.148.47:1232/loginDoctor'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      print('Received response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (responseData is List) {
            bool isValid = responseData.any(
                (user) => user['UserID'] == id && user['Password'] == password);

            if (isValid) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', true);
              await prefs.setString('userId', id);
              await prefs.setBool('isDoctor', true);
              await prefs.setString('logged_in_doctor_id', id);
              if (rememberMe) {
                await prefs.setBool('keep me logged in', true);
              }

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(wardNo: widget.wardNo),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid ID or Password')),
              );
            }
          } else if (responseData is Map) {
            if (responseData['success'] == true) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', true);
              await prefs.setString('userId', id);
              await prefs.setBool('isDoctor', true);
              await prefs.setString('logged_in_doctor_id', id);
              if (rememberMe) {
                await prefs.setBool('keep me logged in', true);
              }

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(wardNo: widget.wardNo),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(responseData['message'] ?? 'Login failed')),
              );
            }
          } else {
            throw Exception('Unexpected response format');
          }
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        String errorMessage = 'Login failed with status ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (_) {}

        throw Exception(errorMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: ClipPath(
              clipper: CurveClipper(),
              child: Container(
                color: Colors.blue,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Lock Icon
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _lockAnimation.value,
                            child: FadeTransition(
                              opacity: _fadeAnimationUpper,
                              child: const Icon(
                                Icons.lock_outline,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // Animated Heading
                      FadeTransition(
                        opacity: _fadeAnimationUpper,
                        child: const Text(
                          'Sign-In',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Animated Subheading
                      FadeTransition(
                        opacity: _fadeAnimationUpper,
                        child: const Text(
                          'Kindly Enter Your Credentials!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Lower Portion
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated ID Input Field
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimationLower,
                        child: TextField(
                          controller: idController,
                          decoration: InputDecoration(
                            labelText: 'ID',
                            labelStyle: const TextStyle(color: Colors.blue),
                            prefixIcon:
                                const Icon(Icons.person, color: Colors.blue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Animated Password Input Field
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimationLower,
                        child: TextField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.blue),
                            prefixIcon:
                                const Icon(Icons.lock, color: Colors.blue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          obscureText: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    const SizedBox(height: 10),
                    // Ward Number Display
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimationLower,
                        child: Text(
                          'Ward Number: ${widget.wardNo}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Animated Login Button
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimationLower,
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 30, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Animated Forgot Password Button
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimationLower,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordPage()),
                            );
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.blue),
                          ),
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
    );
  }
}

class CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);

    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 50,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController userIdController = TextEditingController();
  bool isLoading = false;
  String? generatedOTP;
  String? userEmail;
  String? userId;
  int otpAttempts = 0;
  DateTime? lastOtpAttemptTime;
  bool canRequestOTP = true;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadOtpAttempts();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  Future<void> _loadOtpAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      otpAttempts = prefs.getInt('otpAttempts_${userIdController.text}') ?? 0;
      final lastAttemptTimestamp =
          prefs.getInt('lastOtpAttemptTime_${userIdController.text}');
      lastOtpAttemptTime = lastAttemptTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(lastAttemptTimestamp)
          : null;

      canRequestOTP = !(otpAttempts >= 3 &&
          lastOtpAttemptTime != null &&
          DateTime.now().difference(lastOtpAttemptTime!).inHours < 1);
    });
  }

  Future<void> _saveOtpAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('otpAttempts_${userIdController.text}', otpAttempts);
    await prefs.setInt('lastOtpAttemptTime_${userIdController.text}',
        DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> resetPassword() async {
    final userId = userIdController.text.trim();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your User ID')),
      );
      return;
    }

    if (!canRequestOTP) {
      if (lastOtpAttemptTime != null) {
        final timeSinceLastAttempt =
            DateTime.now().difference(lastOtpAttemptTime!);
        final timeLeft = 60 - timeSinceLastAttempt.inMinutes;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Maximum OTP attempts reached. Please try again after $timeLeft minutes.')),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.57.148.47:1232/getUserEmail'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        userEmail = userData['Email'];

        if (userEmail != null) {
          setState(() {
            otpAttempts++;
          });
          await _saveOtpAttempts();

          generatedOTP = generateOTP();
          await sendOTP(userEmail!, generatedOTP!);
          this.userId = userId;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                userEmail: userEmail!,
                generatedOTP: generatedOTP!,
                userId: userId,
                sendOTPFunction: sendOTP,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        }
      } else {
        final errorMessage =
            jsonDecode(response.body)['error'] ?? 'Failed to fetch user email';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> sendOTP(String recipientEmail, String otp) async {
    String username = 'your gmail account';
    String password = 'app password';

    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 587,
      username: username,
      password: password,
      ignoreBadCertificate: false,
    );

    final message = Message()
      ..from = Address(username, 'Alina Saghir')
      ..recipients.add(recipientEmail)
      ..subject = '🔐 Your One-Time Password (OTP)'
      ..html = """
      <html>
        <head>
          <style>
            body {
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              margin: 0;
              padding: 0;
              background-color: #f7f7f7;
              color: #333;
            }
            .email-container {
              max-width: 600px;
              margin: 20px auto;
              background: #ffffff;
              border-radius: 10px;
              overflow: hidden;
              box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
            }
            .header {
              background: linear-gradient(135deg, #4CAF50, #45a049);
              color: #ffffff;
              padding: 20px;
              text-align: center;
            }
            .header h1 {
              margin: 0;
              font-size: 24px;
              font-weight: bold;
            }
            .content {
              padding: 30px;
              text-align: center;
            }
            .content h2 {
              font-size: 22px;
              color: #4CAF50;
              margin-bottom: 20px;
            }
            .otp-code {
              font-size: 28px;
              font-weight: bold;
              color: #D32F2F;
              background: #f0f0f0;
              padding: 15px;
              border-radius: 8px;
              margin: 20px 0;
              display: inline-block;
            }
            .footer {
              background: #f1f1f1;
              padding: 15px;
              text-align: center;
              font-size: 12px;
              color: #777;
            }
            .footer a {
              color: #4CAF50;
              text-decoration: none;
            }
          </style>
        </head>
        <body>
          <div class="email-container">
            <div class="header">
              <h1>🔐 OTP Verification</h1>
            </div>
            <div class="content">
              <h2>Hello,</h2>
              <p>You requested a One-Time Password (OTP) to reset your password.</p>
              <div class="otp-code">$otp</div>
              <p>This OTP is valid for <strong>5 minutes</strong>. Please do not share it with anyone.</p>
              <p>If you did not request this, please ignore this email.</p>
            </div>
            <div class="footer">
              <p>Thank you,<br><strong>From MEDOQRST Team</strong></p>
            </div>
          </div>
        </body>
      </html>
    """;

    try {
      await send(message, smtpServer);
      print('OTP sent: $otp');
    } catch (e) {
      print('Failed to send OTP: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: ClipPath(
              clipper: TopCurveClipper(),
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Key Icon
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: const Icon(
                          Icons.vpn_key,
                          size: 60,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Main Heading
                      const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Subheading
                      const Text(
                        'Enter your User ID to reset your password',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: ClipPath(
              clipper: BottomCurveClipper(),
              child: Container(
                color: Colors.blue,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // User ID Input Field
                    TextField(
                      controller: userIdController,
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        labelStyle: TextStyle(color: Colors.white),
                        prefixIcon: Icon(Icons.person, color: Colors.white),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    // new otp duration prompt
                    if (!canRequestOTP && lastOtpAttemptTime != null)
                      Text(
                        'You can request a new OTP in ${60 - DateTime.now().difference(lastOtpAttemptTime!).inMinutes} minutes',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(height: 10),
                    // Reset Password Button
                    isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: canRequestOTP ? resetPassword : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 15),
                            ),
                            child: const Text(
                              'Reset Password',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.blue),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);

    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 50,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 50);

    path.quadraticBezierTo(
      size.width / 2,
      0,
      size.width,
      50,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class OTPVerificationPage extends StatefulWidget {
  final String userEmail;
  final String generatedOTP;
  final String userId;
  final Future<void> Function(String email, String otp) sendOTPFunction;

  const OTPVerificationPage({
    super.key,
    required this.userEmail,
    required this.generatedOTP,
    required this.userId,
    required this.sendOTPFunction,
  });

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  int resendAttempts = 0;
  DateTime? lastResendTime;
  bool canResendOTP = true;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  String get maskedEmail {
    if (widget.userEmail.isEmpty) return "";
    final parts = widget.userEmail.split('@');
    if (parts.length != 2) return widget.userEmail;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) {
      return '${username[0]}***@$domain';
    }

    return '${username.substring(0, 2)}***@$domain';
  }

  @override
  void initState() {
    super.initState();
    _loadResendAttempts();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      });

    _animationController.forward();
  }

  Future<void> _loadResendAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      resendAttempts = prefs.getInt('resendAttempts_${widget.userId}') ?? 0;
      final lastResendTimestamp =
          prefs.getInt('lastResendTime_${widget.userId}');
      lastResendTime = lastResendTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(lastResendTimestamp)
          : null;

      canResendOTP = !(resendAttempts >= 3 &&
          lastResendTime != null &&
          DateTime.now().difference(lastResendTime!).inHours < 1);
    });
  }

  Future<void> _saveResendAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('resendAttempts_${widget.userId}', resendAttempts);
    await prefs.setInt('lastResendTime_${widget.userId}',
        DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> resendOTP() async {
    if (!canResendOTP) {
      if (lastResendTime != null) {
        final timeSinceLastResend = DateTime.now().difference(lastResendTime!);
        final timeLeft = 60 - timeSinceLastResend.inMinutes;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Maximum resend attempts reached. Please try again after $timeLeft minutes.')),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      setState(() {
        resendAttempts++;
      });
      await _saveResendAttempts();

      final newOTP = generateOTP();
      await widget.sendOTPFunction(widget.userEmail, newOTP);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New OTP has been sent!')),
      );

      if (resendAttempts >= 3) {
        setState(() {
          canResendOTP = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend OTP: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void verifyOTP() {
    final enteredOTP = otpController.text.trim();

    if (enteredOTP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP')),
      );
      return;
    }

    if (enteredOTP == widget.generatedOTP) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP Verified Successfully! 🎉')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PasswordResetPage(userId: widget.userId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP! ❌')),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Icon
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: const Icon(
                          Icons.verified_user,
                          size: 60,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Heading
                      const Text(
                        'OTP Verification',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Description with masked email
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'We have sent a One-Time Password (OTP) to ',
                              ),
                              TextSpan(
                                text: maskedEmail,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const TextSpan(
                                text: '. Please enter the 6-digit OTP below.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Lower Blue Portion
          Expanded(
            flex: 1,
            child: ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(
                color: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // OTP Input Field
                    TextField(
                      controller: otpController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Enter OTP',
                        labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 119, 120, 121)),
                        prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: verifyOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              )
                            : const Text(
                                'VERIFY OTP',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Resend Button
                    OutlinedButton(
                      onPressed: canResendOTP ? resendOTP : null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        canResendOTP ? 'RESEND OTP' : 'RESEND LIMIT REACHED',
                        style: TextStyle(
                          color: canResendOTP ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!canResendOTP && lastResendTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Try again in ${60 - DateTime.now().difference(lastResendTime!).inMinutes} minutes',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
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
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);

    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 30,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 60,
      size.width,
      size.height - 40,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 40);

    path.quadraticBezierTo(
      size.width * 0.25,
      0,
      size.width * 0.5,
      30,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      60,
      size.width,
      40,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class PasswordResetPage extends StatefulWidget {
  final String userId;

  const PasswordResetPage({super.key, required this.userId});

  @override
  _PasswordResetPageState createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    final newPassword = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a new password')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.57.148.47:1232/resetPassword'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': widget.userId, 'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successful! 🎉')),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('otpAttempts_${widget.userId}');
        await prefs.remove('lastOtpAttemptTime_${widget.userId}');
        await prefs.remove('resendAttempts_${widget.userId}');
        await prefs.remove('lastResendTime_${widget.userId}');

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => const EditPage(
                    wardNo: '',
                  )),
          (Route<dynamic> route) => false,
        );
      } else {
        final errorMessage =
            jsonDecode(response.body)['error'] ?? 'Failed to reset password';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMessage')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: ClipPath(
              clipper: CurveClipper(),
              child: Container(
                color: Colors.blue,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Icon
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: const Icon(
                          Icons.lock_reset,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Heading
                      const Text(
                        'Reset Your Password!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Description
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Create a new password for your account to keep it secure.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // New Password Input Field
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(color: Colors.blue),
                      prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  // Confirm Password Input Field
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: Colors.blue),
                      prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  // Reset Password Button
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          child: const Text(
                            'Reset Password',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
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
