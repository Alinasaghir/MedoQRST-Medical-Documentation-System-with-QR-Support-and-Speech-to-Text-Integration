import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:convert';
import 'nurse_paged.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notifications.dart';
import 'package:intl/intl.dart';
import 'profile.dart';
import 'view.dart';

class PdfService {
  final String wardNo;
  final String bedNo;
  final String admissionNo;

  PdfService({
    required this.wardNo,
    required this.bedNo,
    required this.admissionNo,
  });

  // Fetch patient data from the API
  Future<Map<String, dynamic>?> _fetchPatientData() async {
    const apiUrl = 'http://10.57.148.47:1232/patient';
    try {
      final response = await http.get(
        Uri.parse('$apiUrl?ward_no=$wardNo&bed_no=$bedNo'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List<dynamic> && data.isNotEmpty) {
          final patient = data[0];

          // Process progress details
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

          // Process vital details
          List<Map<String, dynamic>> vitalDetails = [];
          Set<String> uniqueVitalKeys = {};
          for (var item in data) {
            if (item.containsKey('Blood_pressure') &&
                item['Blood_pressure'] != null) {
              final vitalKey =
                  '${item['Recorded_at']}-${item['Blood_pressure']}';
              if (!uniqueVitalKeys.contains(vitalKey)) {
                uniqueVitalKeys.add(vitalKey);
                vitalDetails.add({
                  'Recorded_at': item['Recorded_at'],
                  'Blood_pressure': item['Blood_pressure'],
                  'Respiration_rate': item['Respiration_rate'],
                  'Pulse_rate': item['Pulse_rate'],
                  'Oxygen_saturation': item['Oxygen_saturation'],
                  'Temperature': item['Temperature'],
                  'Random_blood_sugar': item['Random_blood_sugar'],
                });
              }
            }
          }

          // Sort vitalDetails by Recorded_at in descending order (latest first)
          vitalDetails.sort((a, b) {
            return DateTime.parse(b['Recorded_at'])
                .compareTo(DateTime.parse(a['Recorded_at']));
          });

          // Process consultation details
          List<Map<String, dynamic>> consultationDetails = [];
          Set<String> uniqueConsultationKeys = {};
          for (var item in data) {
            final consultationKey =
                '${item['ConsultingPhysicianDepartment']}-${item['ConsultationDate']}-${item['ConsultationTime']}';

            if (!uniqueConsultationKeys.contains(consultationKey)) {
              uniqueConsultationKeys.add(consultationKey);
              consultationDetails.add({
                "consultingName": item["ConsultingDoctorName"],
                "Status": item["Status"],
                'Requesting_Department':
                    item['RequestingPhysicianDepartment'] ??
                        'Unknown Department',
                'Consulting_Department': item['ConsultingPhysicianDepartment'],
                'Requesting_Doctor_Name': item['RequestingPhysicianName'],
                'ConsultationDate': item['ConsultationDate'],
                'Reason': item['Reason'],
                'Additional Description': item['Additional_Description'],
                'ConsultationTime': item['ConsultationTime'],
                'TypeofComments': item['Type_of_Comments'],
              });
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

          // Process drug details
          List<Map<String, dynamic>> drugDetails = [];
          Set<String> uniqueDrugKeys = {};
          for (var item in data) {
            final drugKey =
                '${item['DrugCommercialName']}-${item['MedicationDate']}-${item['MedicationTime']}';
            if (!uniqueDrugKeys.contains(drugKey)) {
              uniqueDrugKeys.add(drugKey);
              drugDetails.add({
                'Drug_Commercial_Name': item['DrugCommercialName'],
                'Medication_Date': item['MedicationDate'],
                'Dosage': item['Dosage'],
                'Shift': item['Shift'],
                'DrugStrength': item['DrugStrength'],
                'Medicationtime': item['MedicationTime'],
                'Monitored_By': item['Monitored_By'],
                'DrugGenericName': item['DrugGenericName'],
              });
            }
          }

          // Sort drugDetails by Medication_Date and Medication_Time in descending order
          drugDetails.sort((a, b) {
            final dateComparison = DateTime.parse(b['Medication_Date'])
                .compareTo(DateTime.parse(a['Medication_Date']));
            if (dateComparison != 0) return dateComparison;
            return DateTime.parse(b['Medicationtime'])
                .compareTo(DateTime.parse(a['Medicationtime']));
          });

          return {
            "PatientName": patient["PatientName"],
            "Admission_time": patient["Admission_time"],
            "Admission_no": patient["Admission_no"],
            "Admission_date": patient["Admission_date"] ?? 'N/A',
            "Bed_no": patient["Bed_no"],
            "Ward_no": patient["Ward_no"],
            "Primary_diagnosis": patient["Primary_diagnosis"] ?? 'N/A',
            "Associate_diagnosis": patient["Associate_diagnosis"] ?? 'N/A',
            "Procedure": patient["Procedure"] ?? 'N/A',
            "ProgressDetails": progressDetails,
            "VitalDetails": vitalDetails,
            "ConsultationDetails": consultationDetails,
            "DrugDetails": drugDetails,
            "AdmittedunderthecareofDr": patient["AdmittedunderthecareofDr"],
            "Receiving note": patient["Receiving_note"],
          };
        } else {
          print('No patient data found.');
          return null;
        }
      } else {
        print('Error: Server returned status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching patient data: $e');
      return null;
    }
  }

  Future<String?> _fetchLatestConsultationId(String admissionNo) async {
    const apiUrl = 'http://10.57.148.47:1232/latestConsultationId';
    try {
      final response = await http.get(
        Uri.parse('$apiUrl?admission_no=$admissionNo'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ConsultationID'] as String?;
      } else {
        print('Error: Server returned status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching latest consultation ID: $e');
      return null;
    }
  }

  String parsePureDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return dateString;
    }
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

  String parseCombinedDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12
          ? hour - 12
          : hour == 0
              ? 12
              : hour;
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return dateTimeString;
    }
  }

  Future<String> generatePDF() async {
    List<pw.Widget> currentPageContent = [];
    try {
      final openSansRegular = await PdfGoogleFonts.openSansRegular();
      final openSansBold = await PdfGoogleFonts.openSansBold();

      final patientData = await _fetchPatientData();
      if (patientData == null) {
        throw Exception("Patient data unavailable at this time.");
      }

      final consultationId =
          await _fetchLatestConsultationId(patientData['Admission_no']);
      if (consultationId == null) {
        throw Exception("Unable to retrieve consultation reference.");
      }

      final pdf = pw.Document();
      const double margin = 36.0;
      const double sectionSpacing = 24.0;
      final PdfColor primaryColor = PdfColor.fromHex("#1a237e");
      final PdfColor accentColor = PdfColor.fromHex("#3949ab");

      // Professional header with logo placeholder
      pw.Widget _buildHeader() {
        return pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MEDICAL CONSULTATION REPORT',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Container(
                  width: 70,
                  height: 60,
                  decoration: pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: pw.BorderRadius.circular(30),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'MedoQRST',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.Divider(
              thickness: 1.5,
              color: primaryColor,
            ),
            pw.SizedBox(height: 12),
          ],
        );
      }

      // Elegant footer
      pw.Widget _buildFooter() {
        return pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Column(
            children: [
              pw.Divider(
                thickness: 1,
                color: PdfColors.grey300,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Confidential Medical Document • Generated ${DateFormat('MMMM d, y').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        );
      }

      void addPage(List<pw.Widget> content) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(margin),
            header: (pw.Context context) => _buildHeader(),
            footer: (pw.Context context) => _buildFooter(),
            build: (pw.Context context) => content,
            theme: pw.ThemeData.withFont(
              base: openSansRegular,
              bold: openSansBold,
            ),
          ),
        );
      }

      void addSection(pw.Widget widget, {bool forceNewPage = false}) {
        if (forceNewPage && currentPageContent.isNotEmpty) {
          addPage(currentPageContent);
          currentPageContent = [];
        }
        currentPageContent.add(widget);
      }

      // Section styling
      pw.Container _buildSectionContainer(String title, pw.Widget content) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          padding: const pw.EdgeInsets.all(16),
          margin: const pw.EdgeInsets.only(bottom: sectionSpacing),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(
                thickness: 1,
                color: PdfColors.grey300,
              ),
              pw.SizedBox(height: 12),
              content,
            ],
          ),
        );
      }

      // Consultation Request Section - Enhanced with all original fields
      if (patientData['ConsultationDetails'].isNotEmpty) {
        final latestConsultation = patientData['ConsultationDetails'].last;

        final requestContent = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Consultation Request Details:',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Dear Consultant, you have been requested by Dr. ${latestConsultation['Requesting_Doctor_Name'] ?? 'N/A'} '
              'from (${latestConsultation['Requesting_Department'] ?? 'N/A'}) department to provide your expert opinion regarding:\n\n'
              '"${latestConsultation['Reason'] ?? 'Unspecified medical concern'}"\n\n'
              'This consultation request is generated on ${parsePureDate(latestConsultation['ConsultationDate'])} '
              'at ${parsePureTime(latestConsultation['ConsultationTime'])}.',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 8),
            if (latestConsultation['TypeofComments'] != null &&
                latestConsultation['TypeofComments'].isNotEmpty)
              pw.Text(
                'This request has been marked as ${latestConsultation['TypeofComments']}.',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: accentColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            if (latestConsultation['Additional Description'] != null &&
                latestConsultation['Additional Description'].isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  'Additional details provided are:\n${latestConsultation['Additional Description']}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
          ],
        );

        addSection(
          _buildSectionContainer('Consultation Request', requestContent),
        );
      }

      // Enhanced Patient Summary Section with all original fields
      final patientSummary = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Patient Overview:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${patientData['PatientName'] ?? 'N/A'} (Admission No. ${patientData['Admission_no'] ?? 'N/A'})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Admission Details:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '• Admitted on: ${parsePureDate(patientData['Admission_date'])} at ${parsePureTime(patientData['Admission_time'])}\n'
            '• Location: Ward ${patientData['Ward_no'] ?? 'N/A'}, Bed ${patientData['Bed_no'] ?? 'N/A'}\n'
            '• Attending Physician: Dr. ${patientData['AdmittedunderthecareofDr'] ?? 'N/A'}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Clinical Presentation:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${patientData['Receiving note'] ?? 'No admission notes available'}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Diagnostic Information:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '• Primary Diagnosis: ${patientData['Primary_diagnosis'] ?? 'Not specified'}\n'
            '${patientData['Associate_diagnosis'] != 'None' && patientData['Associate_diagnosis'].isNotEmpty ? '• Secondary Diagnoses: ${patientData['Associate_diagnosis']}\n' : ''}'
            '${patientData['Procedure'] != null && patientData['Procedure'].isNotEmpty ? '• Procedures Performed: ${patientData['Procedure']}' : ''}',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      );

      addSection(
        _buildSectionContainer('Patient Summary', patientSummary),
      );

      // Action Required Section - Enhanced confirmation
      final actionContent = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Consultation Confirmation',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'By proceeding below, you confirm that you have reviewed the patient\'s details. '
            'This action will notify the requesting physician of your consultation decision.',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 12),
          pw.UrlLink(
            destination: 'http://10.57.148.47:8080/?id=$consultationId',
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'CLICK TO CONFIRM & RESPOND',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );

      addSection(
        _buildSectionContainer('Action Required', actionContent),
        forceNewPage: false,
      );

      if (currentPageContent.isNotEmpty) {
        addPage(currentPageContent);
      }

      // Save the PDF
      const filePath = "storage/emulated/0/Download/Consultation_Report.pdf";
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      return filePath;
    } catch (e) {
      print("Error generating consultation report: $e");
      return "";
    }
  }

  // Helper function to show a SnackBar
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Request permissions
  Future<void> requestPermissions(BuildContext context) async {
    if (await Permission.manageExternalStorage.request().isGranted) {
      _showSnackBar(context, "Manage External Storage permission granted.");
    } else {
      _showSnackBar(context, "Storage external permission denied.");
      openAppSettings();
    }

    // For Android 10 and below
    if (await Permission.storage.request().isGranted) {
      _showSnackBar(context, "Storage permission granted.");
    } else {
      _showSnackBar(context, "Storage permission denied.");
      openAppSettings();
    }
  }
}

class DoctorPage extends StatelessWidget {
  final String sheetName;
  final String admissionNo;
  final String bedNo;
  final String wardNo;
  final String doctorId;

  const DoctorPage({
    Key? key,
    required this.sheetName,
    required this.admissionNo,
    required this.bedNo,
    required this.wardNo,
    required this.doctorId,
  }) : super(key: key);

  Future<Map<String, dynamic>> fetchPatientData(
      String wardNo, String bedNo) async {
    const apiUrl = 'http://10.57.148.47:1232/patient';
    try {
      final response = await http.get(
        Uri.parse('$apiUrl?ward_no=$wardNo&bed_no=$bedNo'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List<dynamic> && data.isNotEmpty) {
          return data[0];
        } else {
          throw Exception('No patient data found');
        }
      } else {
        throw Exception('Failed to load patient data');
      }
    } catch (e) {
      throw Exception('Error fetching patient data: $e');
    }
  }

  Future<void> navigateToOptionPage(
      BuildContext context, String wardNo, String bedNo) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch patient data
      final patientData = await fetchPatientData(wardNo, bedNo);

      // Close loading dialog
      Navigator.of(context).pop();

      // Navigate to OptionPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OptionsPage(patientData: patientData, fromEditPage: true),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await navigateToOptionPage(context, wardNo, bedNo);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Doctor Page',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF103683),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Notifications(
                      doctorid: doctorId,
                      admissionNo: admissionNo,
                    ),
                  ),
                );
              },
            ),
            DoctorProfileMenu(userId: doctorId),
          ],
        ),
        body: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.edit_document,
                      size: 50,
                      color: Color(0xFF103683),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'WELCOME TO EDIT MODE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF103683), // Navy blue
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ClipPath(
                clipper: CurveClipper(),
                child: Container(
                  color: const Color(0xFF00008C),
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      _buildFeatureButton(
                        icon: Icons.assignment,
                        label: 'Consultation Sheet',
                        iconColor: Colors.blue,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConsultationFormPage(
                                admissionNo: admissionNo,
                                bedNo: bedNo,
                                wardNo: wardNo,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureButton(
                        icon: Icons.note_add,
                        label: 'Receiving Note Sheet',
                        iconColor: Colors.orange,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewAndEditVitalsPage(
                                admissionNo: admissionNo,
                                bedNo: bedNo,
                                wardNo: wardNo,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureButton(
                        icon: Icons.bar_chart,
                        label: 'Progress Report',
                        iconColor: Colors.green,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProgressReportPage(
                                admissionNo: admissionNo,
                                bedNo: bedNo,
                                wardNo: wardNo,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureButton(
                        icon: Icons.medication,
                        label: 'Drug Sheet',
                        iconColor: Colors.purple,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DrugSheetPage(
                                admissionNo: admissionNo,
                                bedNo: bedNo,
                                wardNo: wardNo,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureButton(
                        icon: Icons.exit_to_app,
                        label: 'Discharge Sheet',
                        iconColor: Colors.red,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DischargeSheetPage(
                                admissionNo: admissionNo,
                                doctorId: doctorId,
                              ),
                            ),
                          );
                        },
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

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF103683), width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: iconColor),
            const SizedBox(width: 13),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF103683),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Clipper for Curved Design
class CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}

//consultation class:

class ConsultationFormPage extends StatefulWidget {
  final String admissionNo;
  final String bedNo;
  final String wardNo;

  const ConsultationFormPage({
    Key? key,
    required this.admissionNo,
    required this.bedNo,
    required this.wardNo,
  }) : super(key: key);

  @override
  _ConsultationFormPageState createState() => _ConsultationFormPageState();
}

class _ConsultationFormPageState extends State<ConsultationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _additionalDescriptionController =
      TextEditingController();
  final TextEditingController _typeOfCommentsController =
      TextEditingController();
  final TextEditingController _requestingDoctorController =
      TextEditingController();
  bool _isSubmitting = false;

  String? _selectedDepartment;
  String? _selectedConsultingDoctor;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _doctors = [];
  String _requestingDoctorId = "";
  final List<String> _commentTypes = ["Urgent", "Routine", "Immediate"];
  String? _selectedCommentType;
  String? _selectedDoctorContactNumber;

  @override
  void initState() {
    super.initState();
    _loadDoctorId();
    _fetchDepartmentsWithDoctors();
  }

  Future<void> _fetchDepartmentsWithDoctors() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.57.148.47:1232/departmentsWithDoctors'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _departments = data.map((dept) {
            final availableDoctors =
                (dept['Doctors'] as List<dynamic>).where((doctor) {
              final isLoggedInDoctor =
                  doctor['DoctorID'] == _requestingDoctorId;
              return !isLoggedInDoctor;
            }).toList();

            return {
              'DepartmentID': dept['DepartmentID'],
              'DepartmentName': dept['DepartmentName'],
              'Doctors': availableDoctors.map((doctor) {
                return {
                  'DoctorID': doctor['DoctorID'],
                  'DoctorName': doctor['DoctorName'],
                  'Specialization': doctor['Specialization'],
                  'Unavailable_until': doctor['Unavailable_until'],
                };
              }).toList(),
            };
          }).toList();
        });
      }
    } catch (e) {
      print("Error fetching departments and doctors: $e");
    }
  }

  Future<void> _loadDoctorId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _requestingDoctorId = prefs.getString('userId') ?? "";
      _requestingDoctorController.text = _requestingDoctorId;
    });
  }

  Future<void> _submitConsultation() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final Map<String, String> consultationData = {
        "Admission_no": widget.admissionNo,
        "Requesting_Physician": _requestingDoctorId,
        "Consulting_Physician": _selectedConsultingDoctor ?? "",
        "Reason": _reasonController.text,
        "Date": DateTime.now().toIso8601String().split('T')[0],
        "Time": DateTime.now().toIso8601String().split('T')[1].split('.')[0],
        "Additional_Description": _additionalDescriptionController.text,
        "Type_of_Comments": _selectedCommentType ?? "Routine",
      };

      Uri url = Uri.http(
          "10.57.148.47:1232", "/insertConsultation", consultationData);
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Consultation data saved successfully!")),
          );
          _showGeneratePdfDialog(consultationData);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save data: ${response.body}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      } finally {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showGeneratePdfDialog(Map<String, dynamic> consultationData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Generate PDF"),
          content: const Text("Do you want to preview the PDF report?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PdfPreviewScreen(
                              wardNo: widget.wardNo,
                              bedNo: widget.bedNo,
                              admissionNo: widget.admissionNo,
                              doctorContactNumber:
                                  _selectedDoctorContactNumber ?? "no",
                            )));
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _fetchDoctorContactNumber(String doctorId) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.57.148.47:1232/doctor/$doctorId'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['Contact_number'];
      } else {
        print('Error: Server returned status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching doctor contact number: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Consultation Form',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00008C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Icon and Title
            Container(
              height: 180,
              decoration: const BoxDecoration(
                color: const Color(0xFF00008C),
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
                      'PROVIDE CONSULTATION DETAILS',
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

            // Form Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Requesting Doctor ID (Disabled)
                    _buildTextFieldWithIcon(
                      controller: _requestingDoctorController,
                      label: "Requesting Doctor ID",
                      hint: "Enter Requesting Doctor ID",
                      icon: Icons.person,
                      iconColor: Colors.blue,
                      enabled: false,
                    ),

                    // Department Dropdown
                    _buildDropdownWithIcon(
                      label: "Select Department",
                      value: _selectedDepartment,
                      items: _departments.map((dept) {
                        return DropdownMenuItem(
                          value: dept['DepartmentID'].toString(),
                          child: Text(dept['DepartmentName']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value;
                          _selectedConsultingDoctor = null;
                          final selectedDept = _departments.firstWhere(
                            (dept) => dept['DepartmentID'].toString() == value,
                            orElse: () => {},
                          );
                          _doctors = selectedDept.isNotEmpty
                              ? List<Map<String, dynamic>>.from(
                                      selectedDept['Doctors'] ?? [])
                                  .where((doctor) =>
                                      doctor['DoctorID'] != _requestingDoctorId)
                                  .toList()
                              : [];
                        });
                      },
                      icon: Icons.business,
                      iconColor: Colors.purple,
                    ),

                    // Consulting Doctor Dropdown
                    _buildDropdownWithIcon(
                      label: "Select Consulting Doctor",
                      value: _selectedConsultingDoctor,
                      items: [
                        if (_doctors.any(
                            (doctor) => doctor['Unavailable_until'] == null))
                          const DropdownMenuItem<String>(
                            enabled: false,
                            child: Text(
                              "Available Doctors",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00008C)),
                            ),
                          ),
                        ..._doctors
                            .where(
                                (doctor) => doctor['Unavailable_until'] == null)
                            .map((doctor) {
                          return DropdownMenuItem<String>(
                            value: doctor['DoctorID'].toString(),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green),
                                const SizedBox(width: 8),
                                Text(
                                    "${doctor['DoctorName']} - ${doctor['Specialization']}"),
                              ],
                            ),
                          );
                        }).toList(),
                        if (_doctors.any(
                            (doctor) => doctor['Unavailable_until'] != null))
                          const DropdownMenuItem<String>(
                            enabled: false,
                            child: Text(
                              "Unavailable Doctors",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00008C)),
                            ),
                          ),
                        ..._doctors
                            .where(
                                (doctor) => doctor['Unavailable_until'] != null)
                            .map((doctor) {
                          return DropdownMenuItem<String>(
                            value: doctor['DoctorID'].toString(),
                            enabled: false,
                            child: Row(
                              children: [
                                const Icon(Icons.block, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  "${doctor['DoctorName']} - ${doctor['Specialization']} (Unavailable)",
                                  style:
                                      const TextStyle(color: Color(0xFF00008C)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) async {
                        if (value != null) {
                          final contactNumber =
                              await _fetchDoctorContactNumber(value);
                          setState(() {
                            _selectedConsultingDoctor = value;
                            _selectedDoctorContactNumber = contactNumber;
                          });
                        }
                      },
                      icon: Icons.person_search,
                      iconColor: Colors.orange,
                    ),

                    // Reason Text Field
                    _buildTextFieldWithIcon(
                      controller: _reasonController,
                      label: "Reason",
                      hint: "Enter Reason",
                      icon: Icons.note,
                      iconColor: Colors.red,
                    ),

                    // Additional Description Text Field
                    _buildTextFieldWithIcon(
                      controller: _additionalDescriptionController,
                      label: "Additional Description",
                      hint: "Enter Additional Description",
                      icon: Icons.description,
                      iconColor: Colors.green,
                    ),

                    // Type of Comments Dropdown
                    _buildDropdownWithIcon(
                      label: "Type of Comments",
                      value: _selectedCommentType,
                      items: _commentTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCommentType = value;
                        });
                      },
                      icon: Icons.comment,
                      iconColor: Colors.teal,
                    ),

                    // Submit Button
                    const SizedBox(height: 20),
                    _isSubmitting
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submitConsultation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00008C),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Submit Consultation",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldWithIcon({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00008C),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF00008C), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      decoration: InputDecoration(
                        hintText: hint,
                        border: InputBorder.none,
                      ),
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

  Widget _buildDropdownWithIcon({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00008C),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF00008C), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: value,
                      items: items,
                      onChanged: onChanged,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
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

class PdfPreviewScreen extends StatefulWidget with WidgetsBindingObserver {
  final String wardNo;
  final String bedNo;
  final String admissionNo;
  final String doctorContactNumber;

  const PdfPreviewScreen({
    Key? key,
    required this.wardNo,
    required this.bedNo,
    required this.admissionNo,
    required this.doctorContactNumber,
  }) : super(key: key);

  @override
  _PdfPreviewScreenState createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen>
    with WidgetsBindingObserver {
  late PdfService _pdfService;
  String _pdfPath = "/storage/emulated/0/Download/samplenew.pdf";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pdfService = PdfService(
      wardNo: widget.wardNo,
      bedNo: widget.bedNo,
      admissionNo: widget.admissionNo,
    );
    _generateAndLoadPdf();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When user returns to the app, ensure file path is refreshed
      setState(() {
        _pdfPath = _pdfPath;
      });
    }
  }

  Future<void> _generateAndLoadPdf() async {
    try {
      final pdfPath = await _pdfService.generatePDF();
      setState(() {
        _pdfPath = pdfPath;
        _isLoading = false;
      });
    } catch (e) {
      print("Error generating PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate PDF: $e")),
      );
      Navigator.pop(context);
    }
  }

  Future<String> _renamePdfFile(String oldPath, String newName) async {
    try {
      File oldFile = File(oldPath);
      if (!oldFile.existsSync()) {
        return oldPath;
      }

      String directoryPath = "/storage/emulated/0/Download/";
      String newPath = "$directoryPath$newName.pdf";

      await oldFile.rename(newPath);
      return newPath;
    } catch (e) {
      print("Error renaming file: $e");
      return oldPath;
    }
  }

  Future<void> _sendFileViaWhatsApp() async {
    if (await Permission.storage.request().isGranted) {
      try {
        String message = "Consultancy Needed - Urgent Patient Case";
        String newPdfName = message.replaceAll(" ", "_");
        String renamedPdfPath = await _renamePdfFile(_pdfPath, newPdfName);

        File file = File(renamedPdfPath);
        if (!file.existsSync()) {
          print("File does not exist, regenerating PDF...");
          await _generateAndLoadPdf();
        }

        const platform = MethodChannel('whatsapp_file_sender');
        await platform.invokeMethod('sendFile', {
          "filePath": renamedPdfPath,
          "phoneNumber": widget.doctorContactNumber,
        });

        print("File sent successfully: $renamedPdfPath");
      } on PlatformException catch (e) {
        print("Error sending file: ${e.message}");
      }
    } else {
      print("Storage permission not granted.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Preview"),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sendFileViaWhatsApp,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfPdfViewer.file(File(_pdfPath)),
    );
  }
}

class DrugSheetPage extends StatefulWidget {
  final String admissionNo;
  final String bedNo;
  final String wardNo;

  const DrugSheetPage({
    Key? key,
    required this.admissionNo,
    required this.bedNo,
    required this.wardNo,
  }) : super(key: key);

  @override
  _DrugSheetPageState createState() => _DrugSheetPageState();
}

class _DrugSheetPageState extends State<DrugSheetPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String doctorId = "";
  bool _isSubmitting = false;
  bool _isAddingMedication = false;
  bool _isLoading = false;

  final TextEditingController _commercialNameController =
      TextEditingController();
  final TextEditingController _genericNameController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _monitoredByController = TextEditingController();
  String _selectedShift = "Morning";

  final TextEditingController _prescriptionCommercialNameController =
      TextEditingController();
  final TextEditingController _prescriptionGenericNameController =
      TextEditingController();
  final TextEditingController _prescriptionStrengthController =
      TextEditingController();
  final TextEditingController _prescriptionDosageController =
      TextEditingController();
  bool _isSubmittingPrescription = false;

  List<Map<String, dynamic>> _drugDetails = [];
  List<Map<String, dynamic>> _prescriptionDetails = [];
  String patientName = "";
  String dateOfAdmission = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDoctorId();
    _fetchPatientAndDrugDetails();
    _fetchPrescriptionDetails().then((prescriptions) {
      setState(() {
        _prescriptionDetails = prescriptions;
      });
    }).catchError((error) {
      print('Error loading prescriptions: $error');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      doctorId = prefs.getString('userId') ?? "";
      _monitoredByController.text = doctorId;
    });
  }

  Future<void> _fetchPatientAndDrugDetails() async {
    try {
      const String fetchUrl = 'http://10.57.148.47:1232/patient';
      final response = await http.get(
        Uri.parse('$fetchUrl?ward_no=${widget.wardNo}&bed_no=${widget.bedNo}'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final patientData = data.isNotEmpty ? data[0] : {};
        setState(() {
          patientName = patientData['PatientName'] ?? 'Unknown';
          dateOfAdmission = patientData['Admission_date'] ?? 'Unknown';
        });

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
              });
            }
          }
        }

        drugDetails.sort((a, b) {
          final dateComparison = DateTime.parse(b['Medication_Date'])
              .compareTo(DateTime.parse(a['Medication_Date']));
          if (dateComparison != 0) return dateComparison;
          return DateTime.parse(b['Medication_Time'])
              .compareTo(DateTime.parse(a['Medication_Time']));
        });

        setState(() {
          _drugDetails = drugDetails;
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to fetch patient and drug details")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPrescriptionDetails() async {
    try {
      final response = await http.get(
        Uri.parse(
            "http://10.57.148.47:1232/prescriptions/${widget.admissionNo}"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map &&
            data.containsKey('currentPrescriptions') &&
            data.containsKey('pastPrescriptions')) {
          // Combine both lists with a flag to identify current/past
          final current =
              List<Map<String, dynamic>>.from(data['currentPrescriptions'])
                  .map((p) => {...p, 'isCurrent': true})
                  .toList();
          final past =
              List<Map<String, dynamic>>.from(data['pastPrescriptions'])
                  .map((p) => {...p, 'isCurrent': false})
                  .toList();
          return [...current, ...past];
        }
        return [];
      } else {
        throw Exception('Failed to load prescription details');
      }
    } catch (e) {
      print('Error fetching prescription details: $e');
      throw Exception('Error fetching prescription details');
    }
  }

  String _parsePureDate(String recordedAt) {
    final dateTime = DateTime.tryParse(recordedAt);
    if (dateTime != null) {
      return DateFormat('yyyy-MM-dd').format(dateTime);
    }
    return 'N/A';
  }

  String _parsePureTime(String recordedAt) {
    final dateTime = DateTime.tryParse(recordedAt);
    if (dateTime != null) {
      return DateFormat('h:mm a').format(dateTime);
    }
    return 'N/A';
  }

  Future<void> _submitDrugPrescription() async {
    if (doctorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Doctor ID not found. Please log in again.")),
      );
      return;
    }
    // Only require commercial name and dosage
    if (_commercialNameController.text.isEmpty ||
        _dosageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final Map<String, dynamic> drugData = {
      "Admission_no": widget.admissionNo,
      "Commercial_name": _commercialNameController.text,
      "Generic_name": _genericNameController.text,
      "Strength": _strengthController.text,
      "Dosage": _dosageController.text,
      "Monitored_By": _monitoredByController.text,
      "Shift": _selectedShift,
      "Date": DateTime.now().toIso8601String().split('T')[0],
      "Time": DateTime.now().toIso8601String().split('T')[1].split('.')[0],
    };

    try {
      final response = await http.post(
        Uri.parse('http://10.57.148.47:1232/editDrugSheet'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(drugData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Drug prescription saved successfully!")),
        );
        _clearFields();
        setState(() {
          _isAddingMedication = false;
        });
        await _fetchPatientAndDrugDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save drug prescription.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitPrescription() async {
    if (_prescriptionCommercialNameController.text.isEmpty ||
        _prescriptionDosageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields")),
      );
      return;
    }

    setState(() {
      _isSubmittingPrescription = true;
    });

    try {
      final Map<String, dynamic> prescriptionData = {
        "Admission_no": widget.admissionNo,
        "Commercial_name": _prescriptionCommercialNameController.text,
        "Generic_name": _prescriptionGenericNameController.text,
        "Strength": _prescriptionStrengthController.text,
        "Dosage": _prescriptionDosageController.text,
        "Prescribed_by": doctorId,
      };

      final response = await http.post(
        Uri.parse('http://10.57.148.47:1232/insertPrescription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(prescriptionData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Prescription saved successfully!")),
        );
        _clearPrescriptionFields();
        final updatedPrescriptions = await _fetchPrescriptionDetails();
        setState(() {
          _prescriptionDetails = updatedPrescriptions;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Failed to save prescription: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isSubmittingPrescription = false;
      });
    }
  }

  void _clearFields() {
    _commercialNameController.clear();
    _genericNameController.clear();
    _strengthController.clear();
    _dosageController.clear();
    setState(() {
      _selectedShift = "Morning";
    });
  }

  void _clearPrescriptionFields() {
    _prescriptionCommercialNameController.clear();
    _prescriptionGenericNameController.clear();
    _prescriptionStrengthController.clear();
    _prescriptionDosageController.clear();
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

  Future<void> _showDeleteConfirmation(int recordId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content:
              const Text('Are you sure you want to remove this prescription?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deletePrescription(recordId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePrescription(int recordId) async {
    try {
      setState(() {
        _isSubmittingPrescription = true;
      });

      final response = await http.put(
        Uri.parse('http://10.57.148.47:1232/invalidate-prescription/$recordId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription removed successfully')),
        );

        // Instead of fetching all prescriptions again, update the local state
        setState(() {
          // Find the prescription and update its status
          final index = _prescriptionDetails
              .indexWhere((p) => p['Record_ID'] == recordId);
          if (index != -1) {
            _prescriptionDetails[index]['Medication_Status'] = 'invalid';
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove prescription')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSubmittingPrescription = false;
      });
    }
  }

  Widget _buildPrescriptionSheetContent() {
    // Separate current and past prescriptions
    List<Map<String, dynamic>> currentPrescriptions = _prescriptionDetails
        .where((prescription) => prescription['isCurrent'] == true)
        .toList();

    List<Map<String, dynamic>> pastPrescriptions = _prescriptionDetails
        .where((prescription) => prescription['isCurrent'] == false)
        .toList();

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Patient Details Section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF00008C), width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFF103683),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Patient Details",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRowWithIcon(
                              label: "Patient Name",
                              value: patientName,
                              icon: Icons.person,
                              iconColor: Colors.blue,
                            ),
                            _buildInfoRowWithIcon(
                              label: "Date of Admission",
                              value: _parsePureDate(dateOfAdmission),
                              icon: Icons.calendar_today,
                              iconColor: Colors.purple,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Current Prescription Plan Section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF00008C), width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFF103683),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Current Prescription Plan",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: currentPrescriptions.isEmpty
                            ? _buildNoDataMessage(
                                icon: Icons.medication_outlined,
                                message: 'No active prescriptions',
                                compact: true,
                              )
                            : Column(
                                children: currentPrescriptions
                                    .map((prescription) =>
                                        _buildPrescriptionItem(prescription))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Previous Prescription History Section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF00008C), width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFF103683),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Previous Prescription History",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: pastPrescriptions.isEmpty
                            ? _buildNoDataMessage(
                                icon: Icons.history,
                                message: 'No previous prescriptions',
                                compact: true,
                              )
                            : Column(
                                children: pastPrescriptions
                                    .map((prescription) =>
                                        _buildPrescriptionItem(prescription))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 80),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(
                      "Add New Prescription",
                      style: TextStyle(
                        color: Color(0xFF103683),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInputRowWithIcon(
                            label: "Commercial Name",
                            controller: _prescriptionCommercialNameController,
                            icon: Icons.medication,
                            iconColor: Colors.blue,
                          ),
                          _buildInputRowWithIcon(
                            label: "Generic Name",
                            controller: _prescriptionGenericNameController,
                            icon: Icons.medication,
                            iconColor: Colors.green,
                          ),
                          _buildInputRowWithIcon(
                            label: "Strength",
                            controller: _prescriptionStrengthController,
                            icon: Icons.bar_chart,
                            iconColor: Colors.orange,
                          ),
                          _buildInputRowWithIcon(
                            label: "Dosage",
                            controller: _prescriptionDosageController,
                            icon: Icons.medical_services,
                            iconColor: Colors.red,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await _submitPrescription();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 4, 189, 19),
                        ),
                        child: _isSubmittingPrescription
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Save"),
                      ),
                    ],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF103683),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 5,
              ),
              child: const Text(
                "Add New Prescription",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionItem(Map<String, dynamic> prescription) {
    final isCurrent = prescription['isCurrent'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.grey[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prescription['Commercial_name'] ?? 'Unknown Drug',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF103683),
                  ),
                ),
              ),
              if (!isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Past",
                    style: TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          _buildPrescriptionDetailRow(
            label: "Generic Name",
            value: prescription['Generic_name'] ?? 'N/A',
          ),
          _buildPrescriptionDetailRow(
            label: "Strength",
            value: prescription['Strength'] ?? 'N/A',
          ),
          _buildPrescriptionDetailRow(
            label: "Dosage",
            value: prescription['Dosage'] ?? 'N/A',
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Prescribed by: ${prescription['PrescribedByName'] ?? prescription['Prescribed_by'] ?? 'Unknown'}",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              if (isCurrent)
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () =>
                      _showDeleteConfirmation(prescription['Record_ID']),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage(
      {required IconData icon, required String message, bool compact = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 20.0 : 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: compact ? 40 : 60,
              color: Colors.grey[400],
            ),
            SizedBox(height: compact ? 10 : 20),
            Text(
              message,
              style: TextStyle(
                fontSize: compact ? 14 : 18,
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

  Widget _buildDrugSheetContent() {
    bool isDrugSheetEmpty = _drugDetails.isEmpty ||
        _drugDetails.every((drug) => drug['Monitored_By'] == 'Unknown Monitor');

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Patient Details Section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF00008C), width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFF103683),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Patient Details",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRowWithIcon(
                              label: "Patient Name",
                              value: patientName,
                              icon: Icons.person,
                              iconColor: Colors.blue,
                            ),
                            _buildInfoRowWithIcon(
                              label: "Date of Admission",
                              value: _parsePureDate(dateOfAdmission),
                              icon: Icons.calendar_today,
                              iconColor: Colors.purple,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Drug Details Section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF00008C), width: 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFF103683),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Medication History",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: isDrugSheetEmpty
                            ? _buildNoDataMessage(
                                icon: Icons.medication_outlined,
                                message: 'No drug details available yet',
                                compact: true,
                              )
                            : Column(
                                children: _drugDetails.map((drug) {
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'On ${_parsePureDate(drug['Medication_Date'])} at ${_parsePureTime(drug['Medication_Time'])}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF103683),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        _buildInfoRowWithIcon(
                                          label: "Commercial Name",
                                          value: drug['Drug_Commercial_Name'],
                                          icon: Icons.medication,
                                          iconColor: Colors.blue,
                                        ),
                                        _buildInfoRowWithIcon(
                                          label: "Generic Name",
                                          value: drug['Drug_Generic_Name'],
                                          icon: Icons.medication,
                                          iconColor: Colors.green,
                                        ),
                                        _buildInfoRowWithIcon(
                                          label: "Strength",
                                          value: drug['Strength'],
                                          icon: Icons.bar_chart,
                                          iconColor: Colors.orange,
                                        ),
                                        _buildInfoRowWithIcon(
                                          label: "Dosage",
                                          value: drug['Dosage'],
                                          icon: Icons.medical_services,
                                          iconColor: Colors.red,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 80),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isAddingMedication = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF103683),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 5,
              ),
              child: const Text(
                "Add New Medication",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ),
        if (_isAddingMedication)
          Positioned.fill(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInputRowWithIcon(
                      label: "Commercial Name",
                      controller: _commercialNameController,
                      icon: Icons.medication,
                      iconColor: Colors.blue,
                    ),
                    _buildInputRowWithIcon(
                      label: "Generic Name",
                      controller: _genericNameController,
                      icon: Icons.medication,
                      iconColor: Colors.green,
                      isOptional: true,
                    ),
                    _buildInputRowWithIcon(
                      label: "Strength",
                      controller: _strengthController,
                      icon: Icons.bar_chart,
                      iconColor: Colors.orange,
                      isOptional: true,
                    ),
                    _buildInputRowWithIcon(
                      label: "Dosage",
                      controller: _dosageController,
                      icon: Icons.medical_services,
                      iconColor: Colors.red,
                    ),
                    _buildInputRowWithIcon(
                      label: "Monitored By",
                      controller: _monitoredByController,
                      icon: Icons.person,
                      iconColor: Colors.purple,
                      enabled: false,
                    ),
                    SizedBox(height: 8),
                    _buildShiftDropdown(),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isAddingMedication = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 240, 152, 146),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: _submitDrugPrescription,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 7, 238, 103),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Drug Sheet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF103683),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Drug Sheet', icon: Icon(Icons.medication)),
            Tab(text: 'Prescription', icon: Icon(Icons.note_add)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDrugSheetContent(),
          _buildPrescriptionSheetContent(),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithIcon({
    required String label,
    required dynamic value,
    required IconData icon,
    required Color iconColor,
  }) {
    if (value == 'N/A') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: iconColor),
          SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              value?.toString() ?? 'N/A',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRowWithIcon({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    bool enabled = true,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              isOptional ? '$label (optional)' : label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 5,
            child: TextField(
              controller: controller,
              enabled: enabled,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.timer, size: 16, color: Colors.purple),
          SizedBox(width: 8),
          const Expanded(
            flex: 3,
            child: Text("Shift",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(
            flex: 5,
            child: DropdownButtonFormField(
              isDense: true,
              value: _selectedShift,
              items: const ["Morning", "Evening", "Night"]
                  .map((shift) => DropdownMenuItem(
                        value: shift,
                        child: Text(shift, style: TextStyle(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedShift = value as String;
                });
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressReportPage extends StatefulWidget {
  final String admissionNo;
  final String bedNo;
  final String wardNo;

  const ProgressReportPage({
    Key? key,
    required this.admissionNo,
    required this.bedNo,
    required this.wardNo,
  }) : super(key: key);

  @override
  _ProgressReportPageState createState() => _ProgressReportPageState();
}

class _ProgressReportPageState extends State<ProgressReportPage> {
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _progressNotes = [];
  bool _hasNoteForToday = false;
  String? _reportedByName;
  String? _loggedInDoctorId;

  // Variables for patient data
  String patientName = '';
  String dateOfAdmission = '';

  final String serverUrl = 'http://10.57.148.47:1232/insertProgress';
  final String fetchUrl = 'http://10.57.148.47:1232/patient';

  @override
  void initState() {
    super.initState();
    _fetchLoggedInDoctorId();
    _fetchProgressNotes();
    _fetchPatientDetails();
    _checkForTodayNote();
  }

  Future<void> _fetchLoggedInDoctorId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _loggedInDoctorId = prefs.getString('userId');
    });
  }

  Future<void> _checkForTodayNote() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://10.57.148.47:1232/progress-note-today/${widget.admissionNo}'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final noteDate = DateTime.parse(data['Progress_Date']);
        final now = DateTime.now();

        // Check if the note is from today (after midnight)
        final isToday = noteDate.year == now.year &&
            noteDate.month == now.month &&
            noteDate.day == now.day;

        setState(() {
          _hasNoteForToday = isToday;
          if (_hasNoteForToday) {
            _notesController.text = data['Notes'];
            _fetchDoctorName(data['Reported_By']);
          }
        });
      } else {
        setState(() {
          _hasNoteForToday = false;
        });
      }
    } catch (e) {
      print("Error checking for today's note: $e");
    }
  }

  Future<void> _fetchDoctorName(String? doctorId) async {
    if (doctorId == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://10.57.148.47:1232/departmentsWithDoctors'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var department in data) {
          for (var doctor in department['Doctors']) {
            if (doctor['DoctorID'] == doctorId) {
              setState(() {
                _reportedByName = doctor['DoctorName'];
              });
              return;
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching doctor name: $e");
    }
  }

  Widget _buildNoDataMessage(
      {required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
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

  Future<void> _fetchProgressNotes() async {
    try {
      final response = await http.get(
        Uri.parse('$fetchUrl?ward_no=${widget.wardNo}&bed_no=${widget.bedNo}'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Filter and sort progress notes by date, removing duplicates
        Set<String> seenDates = {};
        List<Map<String, dynamic>> filteredNotes = [];

        for (var note in data) {
          String progressDate = note['Progress_Date'];
          if (!seenDates.contains(progressDate)) {
            seenDates.add(progressDate);
            filteredNotes.add(note);
          }
        }

        // Sort the filtered notes by Progress_Date in descending order (latest first)
        filteredNotes.sort((a, b) => DateTime.parse(b['Progress_Date'])
            .compareTo(DateTime.parse(a['Progress_Date'])));

        // Fetch doctor names for all notes
        for (var note in filteredNotes) {
          if (note['Reported_By'] != null) {
            await _fetchDoctorNameForNote(note);
          }
        }

        setState(() {
          _progressNotes = filteredNotes;
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch progress notes")),
        );
      }
    } catch (e) {
      //
    }
  }

  Future<void> _fetchDoctorNameForNote(Map<String, dynamic> note) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.57.148.47:1232/departmentsWithDoctors'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var department in data) {
          for (var doctor in department['Doctors']) {
            if (doctor['DoctorID'] == note['Reported_By']) {
              note['ReportedByName'] = doctor['DoctorName'];
              return;
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching doctor name for note: $e");
    }
  }

  Future<void> _fetchPatientDetails() async {
    try {
      final response = await http.get(
        Uri.parse('$fetchUrl?ward_no=${widget.wardNo}&bed_no=${widget.bedNo}'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)[0];
        setState(() {
          patientName = data['PatientName'] ?? 'Unknown';
          dateOfAdmission = data['Admission_date'] ?? 'Unknown';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch patient details")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> _submitProgressNote() async {
    if (_notesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter progress notes")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "Admission_no": widget.admissionNo,
          "Progress_Date": DateTime.now().toIso8601String(),
          "Notes": _notesController.text,
          "Reported_By": _loggedInDoctorId,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Progress note added successfully")),
        );
        _notesController.clear();
        _fetchProgressNotes(); // Reload progress notes after adding a new one
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to add progress note")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _updateProgressNote() async {
    if (_notesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter progress notes")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://10.57.148.47:1232/update-progress-note/${widget.admissionNo}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "Notes": _notesController.text,
          "Reported_By": _loggedInDoctorId,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Progress note updated successfully")),
        );
        _fetchProgressNotes(); // Reload progress notes after updating
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update progress note")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _parsePureDate(String recordedAt) {
    final dateTime = DateTime.tryParse(recordedAt);
    if (dateTime != null) {
      return DateFormat('yyyy-MM-dd').format(dateTime); // Format: 2023-10-25
    }
    return 'N/A'; // Return 'N/A' if parsing fails
  }

  @override
  Widget build(BuildContext context) {
    bool isProgressEmpty = _progressNotes.isEmpty ||
        _progressNotes.every((progress) =>
            progress['Notes'] == null ||
            progress['Notes'] == 'No notes available' ||
            progress['Notes'].toString().isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Progress Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF103683),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 150,
              decoration: const BoxDecoration(
                color: Color(0xFF103683),
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
                      'PROGRESS REPORT',
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
            // Patient Details Section
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
                        'Patient Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00008C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        label: 'Patient Name',
                        value: patientName,
                        icon: Icons.person,
                        iconColor: const Color(0xFF659CDF),
                      ),
                      _buildDetailRow(
                        label: 'Date of Admission',
                        value: _parsePureDate(dateOfAdmission),
                        icon: Icons.calendar_today,
                        iconColor: Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Progress Notes Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: const Color.fromARGB(255, 178, 221, 248),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00008C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isProgressEmpty)
                        _buildNoDataMessage(
                          icon: Icons.medication_outlined,
                          message: 'No drug details available yet',
                        )
                      else
                        ..._progressNotes.map((note) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: const Color.fromARGB(255, 247, 248, 248),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 20,
                                        color: Color(0xFF103683),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Date: ${_parsePureDate(note['Progress_Date'])}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    note['Notes'] ?? 'No notes available',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (note['ReportedByName'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        "Last Updated By: ${note['ReportedByName']}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              ),
            ),
            // Add/Update Progress Note Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        _notesController.clear();
                        final now = DateTime.now();

                        if (_hasNoteForToday) {
                          // Edit today's note (after midnight)
                          _notesController.text = _progressNotes.firstWhere(
                              (note) =>
                                  _parsePureDate(note['Progress_Date']) ==
                                  _parsePureDate(now.toString()))['Notes'];
                        } else {
                          // Create a new note (no note exists for today)
                          _notesController.clear();
                        }

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              _hasNoteForToday
                                  ? 'Update Progress Note for Today'
                                  : 'Add Progress Note for Today',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00008C),
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: _notesController,
                                  maxLines: 5,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    labelText: 'Enter progress note',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (_hasNoteForToday) {
                                      await _updateProgressNote();
                                    } else {
                                      await _submitProgressNote();
                                    }
                                    Navigator.pop(context); // Close the dialog
                                    _fetchProgressNotes(); // Refresh the page
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF103683),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : Text(_hasNoteForToday
                                          ? 'Update'
                                          : 'Submit'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF103683),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _hasNoteForToday
                      ? "Update Progress Note for Today"
                      : "Add a Progress Note for Today",
                  style: const TextStyle(fontSize: 16),
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

class DischargeSheetPage extends StatefulWidget {
  final String admissionNo;
  final String doctorId;

  const DischargeSheetPage({
    Key? key,
    required this.admissionNo,
    required this.doctorId,
  }) : super(key: key);

  @override
  _DischargeSheetPageState createState() => _DischargeSheetPageState();
}

class _DischargeSheetPageState extends State<DischargeSheetPage> {
  bool _isFetching = false;
  final TextEditingController _mriController = TextEditingController();
  final TextEditingController _ctScanController = TextEditingController();
  final TextEditingController _biopsyController = TextEditingController();
  final TextEditingController _otherReportsController = TextEditingController();
  final TextEditingController _surgeryController = TextEditingController();
  final TextEditingController _operativeFindingsController =
      TextEditingController();
  final TextEditingController _conditionAtDischargeController =
      TextEditingController();
  final TextEditingController _examinationFindingsController =
      TextEditingController();
  final TextEditingController _dischargeTreatmentController =
      TextEditingController();
  final TextEditingController _followUpController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchDischargeDetails();
  }

  Future<void> _fetchDischargeDetails() async {
    setState(() {
      _isFetching = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'http://10.57.148.47:1232/discharge-details/${widget.admissionNo}'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        List<dynamic> responseData = jsonDecode(response.body);

        if (responseData.isNotEmpty) {
          final Map<String, dynamic> data = responseData.first;

          setState(() {
            _examinationFindingsController.text =
                data["Examination_findings"] ?? "";
            _dischargeTreatmentController.text =
                data["Discharge_treatment"] ?? "";
            _followUpController.text = data["Follow_up"] ?? "";
            _instructionsController.text = data["Instructions"] ?? "";
            _conditionAtDischargeController.text =
                data["Condition_at_discharge"] ?? "";
            _surgeryController.text = data["Surgery"] ?? "";
            _operativeFindingsController.text =
                data["Operative_findings"] ?? "";
            _mriController.text = data["MRI"] ?? "";
            _ctScanController.text = data["CT_scan"] ?? "";
            _biopsyController.text = data["Biopsy"] ?? "";
            _otherReportsController.text = data["Other_reports"] ?? "";
            _isFetching = false;
          });
        } else {
          throw Exception("No discharge details found");
        }
      } else {
        throw Exception("Failed to fetch discharge details");
      }
    } catch (e) {
      setState(() {
        _isFetching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Discharge Sheet",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF103683),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 180,
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
                      Icons.assignment,
                      size: 50,
                      color: Colors.white,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "EDITABLE DISCHARGE SHEET",
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Investigation Section in a Box
                  _buildSectionBox(
                    title: "Investigation",
                    children: [
                      _buildTextFieldWithIcon(
                        controller: _mriController,
                        label: "MRI",
                        hint: "Enter MRI details",
                        icon: Icons.light,
                        iconColor: Colors.blue,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _ctScanController,
                        label: "CT Scan",
                        hint: "Enter CT Scan details",
                        icon: Icons.scanner,
                        iconColor: Colors.purple,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _biopsyController,
                        label: "Biopsy Report",
                        hint: "Enter Biopsy Report details",
                        icon: Icons.medical_services,
                        iconColor: Colors.red,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _otherReportsController,
                        label: "Other Reports",
                        hint: "Enter other reports",
                        icon: Icons.description,
                        iconColor: Colors.orange,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _surgeryController,
                        label: "Surgery",
                        hint: "Enter Surgery details",
                        icon: Icons.medical_services,
                        iconColor: Colors.green,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _operativeFindingsController,
                        label: "Operative Findings",
                        hint: "Enter Operative Findings",
                        icon: Icons.find_in_page,
                        iconColor: Colors.teal,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _conditionAtDischargeController,
                        label: "Condition at Discharge",
                        hint: "Enter condition at discharge",
                        icon: Icons.health_and_safety,
                        iconColor: Colors.pink,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Discharge Treatment Section in a Box
                  _buildSectionBox(
                    title: "Discharge Treatment",
                    children: [
                      _buildTextFieldWithIcon(
                        controller: _examinationFindingsController,
                        label: "Examination Findings",
                        hint: "Enter Examination Findings",
                        icon: Icons.find_in_page,
                        iconColor: Colors.blue,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _dischargeTreatmentController,
                        label: "Treatment",
                        hint: "Enter Treatment details",
                        icon: Icons.medication,
                        iconColor: Colors.purple,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _followUpController,
                        label: "Follow Up",
                        hint: "Enter Follow Up details",
                        icon: Icons.calendar_today,
                        iconColor: Colors.red,
                      ),
                      _buildTextFieldWithIcon(
                        controller: _instructionsController,
                        label: "Instructions",
                        hint: "Enter Instructions",
                        icon: Icons.assignment,
                        iconColor: Colors.orange,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Discharge Button (Outside Boxes)
                  _buildDischargeButton(),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildTextFieldWithIcon({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF103683),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF00008C), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: hint,
                        border: InputBorder.none,
                      ),
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

  Widget _buildDischargeButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitDischargeDetails,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF103683),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Discharge",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
      ),
    );
  }

  Future<void> _submitDischargeDetails() async {
    setState(() {
      _isSubmitting = true;
    });

    final diagnosticReportsData = {
      "Admission_no": widget.admissionNo,
      "MRI": _mriController.text,
      "CT_scan": _ctScanController.text,
      "Biopsy": _biopsyController.text,
      "Other_reports": _otherReportsController.text,
    };

    final dischargeDetailsData = {
      "Examination_findings": _examinationFindingsController.text,
      "Discharge_treatment": _dischargeTreatmentController.text,
      "Follow_up": _followUpController.text,
      "Instructions": _instructionsController.text,
      "Condition_at_discharge": _conditionAtDischargeController.text,
      "Doctor_id": widget.doctorId,
      "Surgery": _surgeryController.text,
      "Operative_findings": _operativeFindingsController.text,
    };

    try {
      final diagnosticResponse = await http.put(
        Uri.parse(
            'http://10.57.148.47:1232/diagnostic-reports/${widget.admissionNo}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(diagnosticReportsData),
      );

      if (diagnosticResponse.statusCode != 200) {
        throw Exception("Failed to submit diagnostic reports");
      }

      final dischargeResponse = await http.put(
        Uri.parse(
            'http://10.57.148.47:1232/discharge-details/${widget.admissionNo}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dischargeDetailsData),
      );

      if (dischargeResponse.statusCode != 200 &&
          dischargeResponse.statusCode != 201) {
        throw Exception("Failed to submit discharge details");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Discharge details submitted successfully!")),
      );

      // Clear all fields after submission
      _mriController.clear();
      _ctScanController.clear();
      _biopsyController.clear();
      _otherReportsController.clear();
      _surgeryController.clear();
      _operativeFindingsController.clear();
      _conditionAtDischargeController.clear();
      _examinationFindingsController.clear();
      _dischargeTreatmentController.clear();
      _followUpController.clear();
      _instructionsController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
