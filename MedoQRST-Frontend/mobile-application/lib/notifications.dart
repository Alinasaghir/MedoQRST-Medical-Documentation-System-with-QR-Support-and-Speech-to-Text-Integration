import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'buttonconsult.dart';

class Notifications extends StatefulWidget {
  final String doctorid;
  final String admissionNo;

  const Notifications({
    super.key,
    required this.doctorid,
    required this.admissionNo,
  });

  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  String _parsePureDate(String recordedAt) {
    final dateTime = DateTime.tryParse(recordedAt);
    if (dateTime != null) {
      return DateFormat('yyyy-MM-dd').format(dateTime);
    }
    return 'N/A';
  }

  String parsePureTime(String timeString) {
    if (timeString.isEmpty) return 'N/A';

    try {
      final dateTime = DateTime.parse(timeString);
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12
          ? hour - 12
          : hour == 0
              ? 12
              : hour;
      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return timeString;
    }
  }

  Future<Map<String, dynamic>> fetchDoctorDetails(String doctorId) async {
    try {
      final response = await http
          .get(Uri.parse('http://10.57.148.47:1232/doctor/$doctorId'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        return {
          "Name": "Unknown",
          "Contact_number": "N/A",
          "Alternate_contact_number": "N/A"
        };
      } else {
        throw Exception(
            'Failed to load doctor details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await http.get(Uri.parse(
          'http://10.57.148.47:1232/doctorMessages/${widget.doctorid}/${widget.admissionNo}'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Map<String, dynamic>> updatedNotifications = [];

        for (var item in data) {
          final doctorDetails =
              await fetchDoctorDetails(item["ConsultingPhysician"]);

          updatedNotifications.add({
            "department": item["ConsultingPhysicianDepartmentName"],
            "reason": item["Reason"],
            "doctorid": item["ConsultingPhysician"],
            "doctorName": doctorDetails["Name"] ?? "Unknown",
            "status": item["Status"],
            "denialReason": item["DenialReason"],
            "unavailableUntil": item["UnavailableUntil"],
            "date": item["Date"],
            "time": item["Time"],
            "typeOfComments": item["TypeOfComments"],
            "consultationId": item["ConsultationID"],
          });
        }

        setState(() {
          notifications = updatedNotifications;
          sortNotificationsByDate(); // Sort by date after fetching
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load notifications: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  // Sort notifications by date (latest first)
  void sortNotificationsByDate() {
    notifications.sort((a, b) {
      final dateComparison = b["date"].compareTo(a["date"]);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return b["time"].compareTo(a["time"]);
    });
  }

  // Sort notifications by doctor ID
  void sortNotificationsByDoctorId() {
    notifications.sort((a, b) => a["doctorid"].compareTo(b["doctorid"]));
  }

  void sortNotificationsByTypeOfComments() {
    notifications.sort((a, b) {
      bool aIsUrgent =
          a["typeOfComments"].toString().toLowerCase().contains("urgent");
      bool bIsUrgent =
          b["typeOfComments"].toString().toLowerCase().contains("urgent");

      if (aIsUrgent && !bIsUrgent) {
        return -1;
      } else if (!aIsUrgent && bIsUrgent) {
        return 1;
      }
      return a["typeOfComments"]
          .compareTo(b["typeOfComments"]); // Default sorting
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF103683),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Sorting button
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'date') {
                  sortNotificationsByDate();
                } else if (value == 'doctorId') {
                  sortNotificationsByDoctorId();
                } else if (value == 'typeOfComments') {
                  sortNotificationsByTypeOfComments();
                }
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'date',
                child: Text('Sort by Date'),
              ),
              const PopupMenuItem<String>(
                value: 'doctorId',
                child: Text('Sort by Doctor ID'),
              ),
              const PopupMenuItem<String>(
                value: 'typeOfComments',
                child: Text('Sort by Type of Comments'),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : notifications.isEmpty
                  ? const Center(child: Text('No notifications found.'))
                  : Column(
                      children: [
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: Color(0xFF103683),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications,
                                  size: 50,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'NOTIFICATIONS',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Notifications List
                        Expanded(
                          child: ListView.builder(
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              return Card(
                                margin: const EdgeInsets.all(8.0),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Reason
                                      Text(
                                        notification["reason"],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF103683),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      _buildNotificationDetail(
                                        label: "Department",
                                        value:
                                            notification["department"] ?? 'N/A',
                                        icon: Icons.person,
                                        iconColor: Colors.blue,
                                      ),
                                      _buildNotificationDetail(
                                        label: "Doctor Name",
                                        value:
                                            notification["doctorName"] ?? 'N/A',
                                        icon: Icons.person,
                                        iconColor: Colors.blue,
                                      ),
                                      _buildNotificationDetail(
                                        label: "Status",
                                        value: notification["status"],
                                        icon: Icons.info,
                                        iconColor:
                                            notification["status"] == "Denied"
                                                ? Colors.red
                                                : notification["status"] ==
                                                        "Pending"
                                                    ? Colors.orange
                                                    : Colors.green,
                                      ),
                                      // Date and Time
                                      _buildNotificationDetail(
                                        label: "Date",
                                        value: notification["date"] != null
                                            ? _parsePureDate(
                                                notification["date"])
                                            : 'N/A',
                                        icon: Icons.calendar_today,
                                        iconColor: Colors.purple,
                                      ),
                                      _buildNotificationDetail(
                                        label: "Time",
                                        value: notification["date"] != null
                                            ? parsePureTime(
                                                notification["time"])
                                            : 'N/A',
                                        icon: Icons.access_time,
                                        iconColor: Colors.orange,
                                      ),
                                      // Type of Comments
                                      _buildNotificationDetail(
                                        label: "Type of Comments",
                                        value: notification["typeOfComments"] ??
                                            'N/A',
                                        icon: Icons.comment,
                                        iconColor: Color(0xFF103683),
                                      ),
                                      // Denial Reason and Unavailability
                                      if (notification["status"] ==
                                          "Denied") ...[
                                        _buildNotificationDetail(
                                          label: "Denial Reason",
                                          value: notification["denialReason"] ??
                                              'N/A',
                                          icon: Icons.cancel,
                                          iconColor: Colors.red,
                                        ),
                                        _buildNotificationDetail(
                                          label: "Unavailable Until",
                                          value: notification[
                                                  "unavailableUntil"] ??
                                              'N/A',
                                          icon: Icons.block,
                                          iconColor: Colors.red,
                                        ),
                                      ],
                                      // Unavailability for Pending status
                                      if (notification["status"] == "Pending" &&
                                          notification["unavailableUntil"] !=
                                              null) ...[
                                        _buildNotificationDetail(
                                          label: "Unavailable Until",
                                          value:
                                              notification["unavailableUntil"],
                                          icon: Icons.block,
                                          iconColor: Colors.orange,
                                        ),
                                      ],
                                      // "Need other consultant?" button
                                      if (notification["status"] == "Denied" ||
                                          notification["status"] ==
                                              "Pending") ...[
                                        const SizedBox(height: 16),
                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              // Navigate to the new page with consultationId
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ButtonConsultPage(
                                                    consultationId:
                                                        notification[
                                                            "consultationId"],
                                                  ),
                                                ),
                                              ).then((success) {
                                                if (success == true) {
                                                  // Refresh the notifications if the consultation was updated
                                                  fetchNotifications();
                                                }
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Color(0xFF103683),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                                'Need other consultant?'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildNotificationDetail({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
