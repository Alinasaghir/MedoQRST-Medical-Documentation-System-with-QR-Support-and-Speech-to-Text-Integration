import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consultation Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.blue[50],
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const ConsultationPage(),
    );
  }
}

class ConsultationPage extends StatefulWidget {
  const ConsultationPage({super.key});

  @override
  _ConsultationPageState createState() => _ConsultationPageState();
}

class _ConsultationPageState extends State<ConsultationPage> {
  String? consultationId;
  final TextEditingController denialReasonController = TextEditingController();
  bool isDenied = false;
  DateTime? unavailableUntil;
  DateTime? consultationDate;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchConsultationIdFromUrl();
  }

  void fetchConsultationIdFromUrl() {
    Uri uri = Uri.base;
    consultationId = uri.queryParameters['id'];
    setState(() {});
  }

  Future<void> updateConsultation(String status, String? denialReason,
      DateTime? unavailableUntil, DateTime? consultationDate) async {
    setState(() => isLoading = true);

    try {
      if (consultationId == null) {
        showErrorToast("Consultation ID is missing!");
        return;
      }

      final url = Uri.parse("http://10.57.148.47:1232/updateConsultation");

      String? formattedUnavailableDate = unavailableUntil != null
          ? DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(unavailableUntil.toUtc())
          : null;

      String? formattedConsultationDate = consultationDate != null
          ? DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(consultationDate.toUtc())
          : null;

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'consultationId': consultationId,
          'status': status,
          'denialReason': denialReason,
          'unavailableUntil': formattedUnavailableDate,
          'consultationDate': formattedConsultationDate,
        }),
      );

      if (response.statusCode == 200) {
        showSuccessToast("Consultation updated successfully!");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessPage(
              status: status,
              denialReason: denialReason,
              unavailableUntil: unavailableUntil,
              consultationDate: consultationDate,
              onEditPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      } else {
        showErrorToast("Failed to update: ${response.body}");
      }
    } catch (e) {
      showErrorToast("Error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
    );
  }

  void showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  Future<void> _selectDate(BuildContext context,
      {bool isConsultationDate = false}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isConsultationDate) {
          consultationDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            12,
            0,
            0,
            0,
            0,
          );
        } else {
          unavailableUntil = DateTime(
            picked.year,
            picked.month,
            picked.day,
            12,
            0,
            0,
            0,
            0,
          );
        }
      });
    }
  }

  void _showAcceptConfirmation() {
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.blue, size: 30),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              "Confirm Acceptance",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Are you sure you want to accept this consultation request?",
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Please select consultation date:",
                        style: TextStyle(color: Colors.blue),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                12,
                                0,
                                0,
                                0,
                                0,
                              );
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate == null
                                    ? "Tap to select a date"
                                    : DateFormat('MMMM d, y')
                                        .format(selectedDate!),
                                style: const TextStyle(color: Colors.blue),
                              ),
                              const Icon(Icons.calendar_month,
                                  color: Colors.blue),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: selectedDate == null
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    await updateConsultation(
                                      'Accepted',
                                      null,
                                      null,
                                      selectedDate,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 20),
                                SizedBox(width: 5),
                                Text("Accept"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medical_services, color: Colors.white),
              SizedBox(width: 10),
              Text("Consultation Decision",
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 50.0),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment,
                                  color: Colors.blue, size: 30),
                              SizedBox(width: 10),
                              Text(
                                "Consultation Decision",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "What would you like to do with this consultation request?",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.blue),
                          ),
                          const SizedBox(height: 20),
                          if (!isDenied) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : _showAcceptConfirmation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text("ACCEPT",
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : () => setState(() => isDenied = true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[400],
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.close, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text("DENY",
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (isDenied) ...[
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel, color: Colors.red, size: 30),
                                SizedBox(width: 10),
                                Text(
                                  "Denial Details",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Please provide the following:",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.blue),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: denialReasonController,
                              decoration: InputDecoration(
                                labelText: 'Reason for denial*',
                                labelStyle: const TextStyle(color: Colors.blue),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.blue),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.blue, width: 2),
                                ),
                                prefixIcon:
                                    const Icon(Icons.info, color: Colors.blue),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Select unavailable until date (optional):",
                              style: TextStyle(color: Colors.blue),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _selectDate(context),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      unavailableUntil == null
                                          ? "Tap to select a date"
                                          : DateFormat('MMMM d, y')
                                              .format(unavailableUntil!),
                                      style:
                                          const TextStyle(color: Colors.blue),
                                    ),
                                    const Icon(Icons.calendar_month,
                                        color: Colors.blue),
                                  ],
                                ),
                              ),
                            ),
                            if (unavailableUntil != null) ...[
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () =>
                                    setState(() => unavailableUntil = null),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.refresh, size: 20),
                                    SizedBox(width: 8),
                                    Text("RESET DATE"),
                                  ],
                                ),
                              )
                            ],
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (denialReasonController.text.isEmpty &&
                                          unavailableUntil == null) {
                                        showErrorToast(
                                            "Please provide at least a reason or unavailability date.");
                                        return;
                                      }
                                      await updateConsultation(
                                          'Denied',
                                          denialReasonController.text.isEmpty
                                              ? null
                                              : denialReasonController.text,
                                          unavailableUntil,
                                          null);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[400],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send, size: 20),
                                  SizedBox(width: 8),
                                  Text("SUBMIT DENIAL",
                                      style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => setState(() => isDenied = false),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_back, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text("Go Back",
                                      style: TextStyle(color: Colors.blue)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (isLoading) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SuccessPage extends StatelessWidget {
  final String status;
  final String? denialReason;
  final DateTime? unavailableUntil;
  final DateTime? consultationDate;
  final VoidCallback onEditPressed;

  const SuccessPage({
    super.key,
    required this.status,
    this.denialReason,
    this.unavailableUntil,
    this.consultationDate,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text("Submission Successful",
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.blue[700],
                  size: 80,
                ),
                const SizedBox(height: 20),
                Text(
                  "Your response has been submitted successfully!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description, color: Colors.blue),
                            SizedBox(width: 10),
                            Text(
                              "Response Details",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            const Icon(Icons.info,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 5),
                            const Text("Status: ",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                            Text(
                              status,
                              style: TextStyle(
                                color: status == 'Accepted'
                                    ? Colors.blue
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (denialReason != null &&
                            denialReason!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.message,
                                  color: Colors.blue, size: 20),
                              const SizedBox(width: 5),
                              const Text("Reason: ",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue)),
                              Expanded(
                                child: Text(denialReason!,
                                    style: const TextStyle(color: Colors.blue)),
                              ),
                            ],
                          ),
                        ],
                        if (unavailableUntil != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: Colors.blue, size: 20),
                              const SizedBox(width: 5),
                              const Text("Unavailable until: ",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue)),
                              Text(
                                DateFormat('MMMM d, y')
                                    .format(unavailableUntil!),
                              )
                            ],
                          ),
                        ],
                        if (consultationDate != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.event_available,
                                  color: Colors.blue, size: 20),
                              const SizedBox(width: 5),
                              const Text("Consultation date: ",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue)),
                              Text(
                                DateFormat('MMMM d, y')
                                    .format(consultationDate!),
                              )
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home, color: Colors.white),
                          SizedBox(width: 8),
                          Text("Back to Home",
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onEditPressed,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text("Edit Response",
                              style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
