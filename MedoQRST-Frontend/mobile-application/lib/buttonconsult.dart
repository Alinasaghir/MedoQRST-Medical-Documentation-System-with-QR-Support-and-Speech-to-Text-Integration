import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'doctor_page.dart';

class ButtonConsultPage extends StatefulWidget {
  final String consultationId;

  const ButtonConsultPage({super.key, required this.consultationId});

  @override
  _ButtonConsultPageState createState() => _ButtonConsultPageState();
}

class _ButtonConsultPageState extends State<ButtonConsultPage> {
  Map<String, dynamic> consultationDetails = {};
  List<Map<String, dynamic>> doctors = [];
  bool isLoading = true;
  String errorMessage = '';
  String? selectedDoctorId;

  @override
  void initState() {
    super.initState();
    fetchConsultationDetails();
  }

  Future<void> fetchConsultationDetails() async {
    try {
      final response = await http.get(Uri.parse(
          'http://10.57.148.47:1232/consultations/${widget.consultationId}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          consultationDetails = data;
          fetchDoctorsByDepartment(data['Consulting_Department_ID']);
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load consultation details: ${response.statusCode}';
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

  Future<void> fetchDoctorsByDepartment(int? departmentId) async {
    if (departmentId == null) return;

    try {
      final response = await http
          .get(Uri.parse('http://10.57.148.47:1232/departmentsWithDoctors'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final department = data.firstWhere(
          (dept) => dept['DepartmentID'] == departmentId,
          orElse: () => null,
        );

        if (department != null) {
          // Filter doctors to include only those who are available
          final availableDoctors = department['Doctors']
              .where((doctor) => doctor['Status'] == "Available")
              .map((doctor) => {
                    'DoctorID': doctor['DoctorID'],
                    'DoctorName': doctor['DoctorName'],
                    'Specialization': doctor['Specialization'],
                  })
              .toList();

          setState(() {
            doctors = List<Map<String, dynamic>>.from(availableDoctors);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'No doctors found in this department';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load doctors: ${response.statusCode}';
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

  Future<void> updateConsultation() async {
    if (selectedDoctorId == null) {
      setState(() {
        errorMessage = 'Please select a doctor';
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('http://10.57.148.47:1232/msg-update-consultation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'consultationId': widget.consultationId,
          'consultingPhysician': selectedDoctorId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        bool generatePdf = await showGeneratePdfDialog();
        if (generatePdf) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfPreviewScreen(
                wardNo: consultationDetails['Ward_no'].toString(),
                bedNo: consultationDetails['Bed_no'].toString(),
                admissionNo: consultationDetails['Admission_no'].toString(),
                doctorContactNumber: responseData['contact_number'],
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          errorMessage =
              'Failed to update consultation: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
      });
    }
  }

  Future<bool> showGeneratePdfDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Generate PDF"),
            content: const Text("Do you want to generate and preview the PDF?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("No"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Yes"),
              ),
            ],
          ),
        ) ??
        false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assign New Consultant',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00008C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        height: 150,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00008C),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment,
                                size: 50,
                                color: Colors.white,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'ASSIGN NEW CONSULTANT',
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
                      // Consultation Details Card
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Consultation Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00008C),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  label: 'Reason',
                                  value: consultationDetails['Reason'],
                                  icon: Icons.note,
                                  iconColor: Colors.blue,
                                ),
                                _buildDetailRow(
                                  label: 'Date',
                                  value: consultationDetails['Date'] != null
                                      ? _parsePureDate(
                                          consultationDetails['Date'])
                                      : 'N/A',
                                  icon: Icons.calendar_today,
                                  iconColor: Colors.purple,
                                ),
                                _buildDetailRow(
                                  label: 'Time',
                                  value: consultationDetails['Time'] != null
                                      ? parsePureTime(
                                          consultationDetails['Time'])
                                      : 'N/A',
                                  icon: Icons.access_time,
                                  iconColor: Colors.orange,
                                ),
                                _buildDetailRow(
                                  label: 'Status',
                                  value: consultationDetails['Status'],
                                  icon: Icons.info,
                                  iconColor:
                                      consultationDetails['Status'] == 'Denied'
                                          ? Colors.red
                                          : Colors.green,
                                ),
                                _buildDetailRow(
                                  label: 'Denial Reason',
                                  value: consultationDetails['Denial_Reason'] ??
                                      'N/A',
                                  icon: Icons.cancel,
                                  iconColor: Colors.red,
                                ),
                                _buildDetailRow(
                                  label: 'Department',
                                  value: consultationDetails[
                                      'Consulting_Department_Name'],
                                  icon: Icons.business,
                                  iconColor: Colors.teal,
                                ),
                                _buildDetailRow(
                                  label: 'Specialization',
                                  value: consultationDetails[
                                      'Consulting_Specialization'],
                                  icon: Icons.medical_services,
                                  iconColor: Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Select Doctor Section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select a Doctor',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00008C),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: selectedDoctorId,
                                  items: doctors.map((doctor) {
                                    return DropdownMenuItem<String>(
                                      value: doctor['DoctorID'].toString(),
                                      child: Text(
                                        '${doctor['DoctorName']} - ${doctor['Specialization']}',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedDoctorId = value;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Select Doctor',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                if (errorMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      errorMessage,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                Center(
                                  child: ElevatedButton(
                                    onPressed: updateConsultation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00008C),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Update Consultation'),
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

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
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
