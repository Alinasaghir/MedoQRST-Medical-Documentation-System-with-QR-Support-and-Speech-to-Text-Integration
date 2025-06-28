import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'view.dart';
import 'manageaccount.dart';

class DoctorProfileMenu extends StatefulWidget {
  final String userId;

  const DoctorProfileMenu({Key? key, required this.userId}) : super(key: key);

  @override
  _DoctorProfileMenuState createState() => _DoctorProfileMenuState();
}

class _DoctorProfileMenuState extends State<DoctorProfileMenu> {
  Map<String, dynamic>? _doctorDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDoctorDetails();
  }

  Future<void> _fetchDoctorDetails() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.57.148.47:1232/doctor/${widget.userId}'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _doctorDetails = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to fetch doctor details");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MyHome()),
      (Route<dynamic> route) => false,
    );
  }

  void _manageAccount() {
    if (_doctorDetails != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManageAccountPage(
            doctorDetails: _doctorDetails!,
            userId: widget.userId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Doctor details not available")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: CircleAvatar(
        backgroundColor: const Color(0xFF87CEFB),
        child: const Icon(Icons.person, color: Color(0xFF103683)),
      ),
      onPressed: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel:
              MaterialLocalizations.of(context).modalBarrierDismissLabel,
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) {
            return SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    height: MediaQuery.of(context).size.height,
                    color: Colors.white,
                    child: Column(
                      children: [
                        Container(
                          height: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF103683),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/logo.png',
                                height: 40,
                                width: 40,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Doctor Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),

                        // Scrollable content area
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight:
                                    MediaQuery.of(context).size.height - 80,
                              ),
                              child: IntrinsicHeight(
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator())
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF659CDF),
                                                width: 3,
                                              ),
                                              image: const DecorationImage(
                                                image: AssetImage(
                                                    'assets/doctor_profile.jpg'),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Name and ID
                                          Text(
                                            _doctorDetails?['Name'] ??
                                                'Unknown',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00008C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'ID: ${widget.userId}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 24),

                                          // Department Info
                                          Column(
                                            children: [
                                              Icon(
                                                Icons.medical_services,
                                                size: 28,
                                                color: const Color(0xFF659CDF),
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Department',
                                                style: TextStyle(
                                                  color: Color(0xFF00008C),
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _doctorDetails?[
                                                        'Department_name'] ??
                                                    'Unknown',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 32),
                                          Divider(
                                              height: 1,
                                              color: Colors.grey[300]),
                                          const SizedBox(height: 24),

                                          // Manage Account
                                          _buildMenuOption(
                                            icon: Icons.settings,
                                            iconColor: const Color(0xFF659CDF),
                                            title: 'Manage Account',
                                            onTap: _manageAccount,
                                          ),

                                          const SizedBox(height: 16),

                                          // Logout
                                          _buildMenuOption(
                                            icon: Icons.logout,
                                            iconColor: Colors.red[400]!,
                                            title: 'Logout',
                                            onTap: _logout,
                                          ),

                                          const SizedBox(height: 24),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: iconColor == Colors.red[400]
                    ? Colors.red[600]
                    : const Color(0xFF00008C),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
