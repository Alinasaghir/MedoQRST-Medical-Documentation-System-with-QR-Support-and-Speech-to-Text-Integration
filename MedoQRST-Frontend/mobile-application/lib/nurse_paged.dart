import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ViewAndEditVitalsPage extends StatefulWidget {
  final String admissionNo;
  final String bedNo;
  final String wardNo;

  const ViewAndEditVitalsPage({
    super.key,
    required this.admissionNo,
    required this.bedNo,
    required this.wardNo,
  });

  @override
  _ViewAndEditVitalsPageState createState() => _ViewAndEditVitalsPageState();
}

class _ViewAndEditVitalsPageState extends State<ViewAndEditVitalsPage> {
  List<Map<String, dynamic>>? vitalsData;
  bool isLoading = true;
  bool isInsertingVitals = false;

  // Diagnosis editing states
  bool isEditingPrimaryDiagnosis = false;
  bool isEditingAssociatedDiagnosis = false;
  bool isEditingProcedure = false;
  bool isEditingReceivingNote = false;

  String _primaryDiagnosis = 'N/A';
  String _associatedDiagnosis = 'N/A';
  String _procedure = 'N/A';
  String _receivingNote = 'N/A';
  String _name = 'N/A';
  String _daterecorded = 'N/A';

  // Controllers
  final TextEditingController _bloodPressureController = TextEditingController();
  final TextEditingController _pulseRateController = TextEditingController();
  final TextEditingController _respirationRateController = TextEditingController();
  final TextEditingController _oxygenSaturationController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _randomBloodSugarController = TextEditingController();
  final TextEditingController _primaryDiagnosisController = TextEditingController();
  final TextEditingController _associatedDiagnosisController = TextEditingController();
  final TextEditingController _procedureController = TextEditingController();
  final TextEditingController _receivingNoteController = TextEditingController();

  // Validation flags (only for vitals)
  bool _isOxygenValid = true;
  bool _isTemperatureValid = true;
  bool _isTemperatureEmpty = false;

  @override
  void initState() {
    super.initState();
    _fetchVitals();
  }

  Future<void> _fetchVitals() async {
    try {
      final uri = Uri.parse(
          'http://10.57.148.47:1232/patient?ward_no=${widget.wardNo}&bed_no=${widget.bedNo}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          vitalsData = _filterAndValidateVitals(data).map((entry) {
            return entry.map((key, value) {
              if (value == null) return MapEntry(key, 'N/A');
              return MapEntry(key, value.toString());
            });
          }).toList();

          vitalsData?.sort((a, b) {
            final recordedAtA = a['Recorded_at'] ?? '';
            final recordedAtB = b['Recorded_at'] ?? '';
            return DateTime.parse(recordedAtB).compareTo(DateTime.parse(recordedAtA));
          });

          isLoading = false;

          if (data.isNotEmpty) {
            final firstEntry = data[0];
            _primaryDiagnosis = firstEntry['Primary_diagnosis']?.toString() ?? 'N/A';
            _associatedDiagnosis = firstEntry['Associate_diagnosis']?.toString() ?? 'N/A';
            _procedure = firstEntry['Procedure']?.toString() ?? 'N/A';
            _receivingNote = firstEntry['Receiving_note']?.toString() ?? 'N/A';
            _name = firstEntry['PatientName']?.toString() ?? 'N/A';
            _daterecorded = firstEntry['Admission_date']?.toString() ?? 'N/A';
          }
        });
      } else {
        throw Exception('Failed to load vitals data');
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching vitals: $error')),
      );
    }
  }

  List<Map<String, dynamic>> _filterAndValidateVitals(List<dynamic> data) {
    Set<String> uniqueRecordedAt = <String>{};
    List<Map<String, dynamic>> validVitals = [];

    for (var entry in data) {
      Map<String, dynamic> stringEntry = {};

      entry.forEach((key, value) {
        if (value == null) {
          stringEntry[key] = 'N/A';
        } else if (value is int || value is double) {
          stringEntry[key] = value.toString();
        } else {
          stringEntry[key] = value;
        }
      });

      String recordedAt = stringEntry['Recorded_at'] ?? '';
      String temperature = stringEntry['Temperature'] ?? '';

      if (recordedAt.isNotEmpty && temperature.isNotEmpty && temperature != 'N/A') {
        if (!uniqueRecordedAt.contains(recordedAt)) {
          uniqueRecordedAt.add(recordedAt);
          validVitals.add(stringEntry);
        }
      }
    }

    return validVitals;
  }

  Future<void> _updatePrimaryDiagnosis() async {
    try {
      final newData = {
        'Admission_no': widget.admissionNo,
        'Primary_diagnosis': _primaryDiagnosisController.text,
      };

      final queryParams = Uri(queryParameters: newData).query;
      final uri = Uri.parse('http://10.57.148.47:1232/updatePrimaryDiagnosis?$queryParams');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primary diagnosis updated successfully!')),
        );
        setState(() {
          isEditingPrimaryDiagnosis = false;
          _primaryDiagnosisController.clear();
        });
        await _fetchVitals();
      } else {
        throw Exception('Error updating primary diagnosis: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating primary diagnosis: $error')),
      );
    }
  }

  Future<void> _updateAssociatedDiagnosis() async {
    try {
      final newData = {
        'Admission_no': widget.admissionNo,
        'Associate_diagnosis': _associatedDiagnosisController.text,
      };

      final queryParams = Uri(queryParameters: newData).query;
      final uri = Uri.parse('http://10.57.148.47:1232/updateAssociatedDiagnosis?$queryParams');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Associated diagnosis updated successfully!')),
        );
        setState(() {
          isEditingAssociatedDiagnosis = false;
          _associatedDiagnosisController.clear();
        });
        await _fetchVitals();
      } else {
        throw Exception('Error updating associated diagnosis: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating associated diagnosis: $error')),
      );
    }
  }

  Future<void> _updateProcedure() async {
    try {
      final newData = {
        'Admission_no': widget.admissionNo,
        'Procedure': _procedureController.text,
      };

      final queryParams = Uri(queryParameters: newData).query;
      final uri = Uri.parse('http://10.57.148.47:1232/updateProcedure?$queryParams');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Procedure updated successfully!')),
        );
        setState(() {
          isEditingProcedure = false;
          _procedureController.clear();
        });
        await _fetchVitals();
      } else {
        throw Exception('Error updating procedure: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating procedure: $error')),
      );
    }
  }

  Future<void> _updateReceivingNote() async {
    try {
      final newData = {
        'Admission_no': widget.admissionNo,
        'Receiving_note': _receivingNoteController.text,
      };

      final queryParams = Uri(queryParameters: newData).query;
      final uri = Uri.parse('http://10.57.148.47:1232/updateReceivingNote?$queryParams');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receiving note updated successfully!')),
        );
        setState(() {
          isEditingReceivingNote = false;
          _receivingNoteController.clear();
        });
        await _fetchVitals();
      } else {
        throw Exception('Error updating receiving note: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating receiving note: $error')),
      );
    }
  }

  Future<void> _insertVitals() async {
    if (_temperatureController.text.isEmpty) {
      setState(() {
        _isTemperatureEmpty = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temperature is required')),
      );
      return;
    }

    final tempValue = double.tryParse(_temperatureController.text);
    if (tempValue == null || tempValue < 95 || tempValue > 110) {
      setState(() {
        _isTemperatureValid = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temperature must be between 95-110°F')),
      );
      return;
    }

    if (_oxygenSaturationController.text.isNotEmpty) {
      final oxygenValue = double.tryParse(_oxygenSaturationController.text);
      if (oxygenValue == null || oxygenValue < 0 || oxygenValue > 100) {
        setState(() {
          _isOxygenValid = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oxygen saturation must be between 0-100%')),
        );
        return;
      }
    }

    try {
      final newVitals = {
        'Admission_no': widget.admissionNo,
        'Recorded_at': DateTime.now().toIso8601String(),
        'Blood_pressure': _bloodPressureController.text.isNotEmpty
            ? _bloodPressureController.text
            : 'N/A',
        'Pulse_rate': _pulseRateController.text.isNotEmpty
            ? _pulseRateController.text
            : 'N/A',
        'Respiration_rate': _respirationRateController.text.isNotEmpty
            ? _respirationRateController.text
            : 'N/A',
        'Oxygen_saturation': _oxygenSaturationController.text.isNotEmpty
            ? _oxygenSaturationController.text
            : 'N/A',
        'Temperature': _temperatureController.text,
        'Random_blood_sugar': _randomBloodSugarController.text.isNotEmpty
            ? _randomBloodSugarController.text
            : 'N/A',
      };

      final queryParams = Uri(queryParameters: newVitals).query;
      final uri = Uri.parse('http://10.57.148.47:1232/insertdrVitals?$queryParams');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vitals added successfully!')),
        );

        _clearVitalsInputFields();
        setState(() {
          vitalsData?.insert(0, newVitals);
          isInsertingVitals = false;
          _isOxygenValid = true;
          _isTemperatureValid = true;
          _isTemperatureEmpty = false;
        });
        await _fetchVitals();
      } else {
        throw Exception('Error inserting vitals: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inserting vitals: $error')),
      );
    }
  }

  void _clearVitalsInputFields() {
    _bloodPressureController.clear();
    _pulseRateController.clear();
    _respirationRateController.clear();
    _oxygenSaturationController.clear();
    _temperatureController.clear();
    _randomBloodSugarController.clear();
    setState(() {
      _isOxygenValid = true;
      _isTemperatureValid = true;
      _isTemperatureEmpty = false;
    });
  }

  String _parsePureDate(String recordedAt) {
    final dateTime = DateTime.tryParse(recordedAt);
    if (dateTime != null) {
      return DateFormat('yyyy-MM-dd').format(dateTime);
    }
    return 'N/A';
  }

  String _parseDateTime(String recordedAt) {
    final dateTime = DateTime.tryParse(recordedAt);
    if (dateTime != null) {
      return DateFormat('MMMM d, yyyy \'at\' h:mm a').format(dateTime);
    }
    return 'N/A';
  }

  void _validateOxygen(String value) {
    if (value.isEmpty) {
      setState(() => _isOxygenValid = true);
      return;
    }
    final oxygenValue = double.tryParse(value);
    setState(() {
      _isOxygenValid = oxygenValue != null && oxygenValue >= 0 && oxygenValue <= 100;
    });
  }

  void _validateTemperature(String value) {
    setState(() {
      _isTemperatureEmpty = value.isEmpty;
    });
    if (value.isEmpty) {
      setState(() => _isTemperatureValid = true);
      return;
    }
    final tempValue = double.tryParse(value);
    setState(() {
      _isTemperatureValid = tempValue != null && tempValue >= 95 && tempValue <= 110;
    });
  }

  bool get _isFormValid {
    if (isInsertingVitals) {
      return !_isTemperatureEmpty && _isTemperatureValid && _isOxygenValid;
    }
    return true;
  }

  Widget _buildEditableCommaList({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    final items = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 13),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (!isEditing)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(left: 32.0, top: 8.0),
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter new $title',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onSave,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) => 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                )
              ).toList(),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEditableNote({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 13),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (!isEditing)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(left: 32.0, top: 8.0),
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter new $title',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onSave,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Text(value),
          ),
        const SizedBox(height: 8),
      ],
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
        border: Border.all(color: const Color(0xFF103683), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF87CEFB).withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF103683),
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

  Widget _buildInfoRowWithIcon({
    required String label,
    required dynamic value,
    required IconData icon,
    required Color iconColor,
  }) {
    if (value == null || value == 'N/A' || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 13),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value?.toString() ?? 'N/A',
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    String? Function(String?)? validator,
    bool isError = false,
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
              color: isError ? Colors.red : const Color(0xFF103683),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isError ? Colors.red : const Color(0xFF103683),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(icon, color: isError ? Colors.red : iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: hint,
                        border: InputBorder.none,
                        errorText: validator?.call(controller.text),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: validator,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Receiving Note Sheet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF103683),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF103683),
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
                          "EDITABLE RECEIVING NOTE SHEET",
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
                      // Patient Details Section
                      _buildSectionBox(
                        title: "Patient Details",
                        children: [
                          _buildInfoRowWithIcon(
                            label: "Patient Name",
                            value: _name,
                            icon: Icons.person,
                            iconColor: Colors.blueAccent,
                          ),
                          _buildInfoRowWithIcon(
                            label: "Date of Admission",
                            value: _parsePureDate(_daterecorded),
                            icon: Icons.calendar_today,
                            iconColor: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Diagnosis Section
                      _buildSectionBox(
                        title: "Diagnosis",
                        children: [
                          _buildEditableCommaList(
                            title: "Primary Diagnosis",
                            value: _primaryDiagnosis,
                            icon: Icons.medical_services,
                            iconColor: Colors.redAccent,
                            controller: _primaryDiagnosisController,
                            isEditing: isEditingPrimaryDiagnosis,
                            onEdit: () {
                              setState(() {
                                isEditingPrimaryDiagnosis = true;
                                _primaryDiagnosisController.text = '';
                              });
                            },
                            onSave: _updatePrimaryDiagnosis,
                            onCancel: () {
                              setState(() {
                                isEditingPrimaryDiagnosis = false;
                                _primaryDiagnosisController.clear();
                              });
                            },
                          ),
                          _buildEditableCommaList(
                            title: "Associated Diagnosis",
                            value: _associatedDiagnosis,
                            icon: Icons.medical_services,
                            iconColor: Colors.orange,
                            controller: _associatedDiagnosisController,
                            isEditing: isEditingAssociatedDiagnosis,
                            onEdit: () {
                              setState(() {
                                isEditingAssociatedDiagnosis = true;
                                _associatedDiagnosisController.text = '';
                              });
                            },
                            onSave: _updateAssociatedDiagnosis,
                            onCancel: () {
                              setState(() {
                                isEditingAssociatedDiagnosis = false;
                                _associatedDiagnosisController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Procedure Section
                      _buildSectionBox(
                        title: "Procedure",
                        children: [
                          _buildEditableCommaList(
                            title: "Procedure",
                            value: _procedure,
                            icon: Icons.medical_services,
                            iconColor: Colors.purpleAccent,
                            controller: _procedureController,
                            isEditing: isEditingProcedure,
                            onEdit: () {
                              setState(() {
                                isEditingProcedure = true;
                                _procedureController.text = '';
                              });
                            },
                            onSave: _updateProcedure,
                            onCancel: () {
                              setState(() {
                                isEditingProcedure = false;
                                _procedureController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Receiving Note Section
                      _buildSectionBox(
                        title: "Receiving Note",
                        children: [
                          _buildEditableNote(
                            title: "Receiving Note",
                            value: _receivingNote,
                            icon: Icons.note,
                            iconColor: Colors.brown,
                            controller: _receivingNoteController,
                            isEditing: isEditingReceivingNote,
                            onEdit: () {
                              setState(() {
                                isEditingReceivingNote = true;
                                _receivingNoteController.text = _receivingNote;
                              });
                            },
                            onSave: _updateReceivingNote,
                            onCancel: () {
                              setState(() {
                                isEditingReceivingNote = false;
                                _receivingNoteController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Vitals Section
                      if (vitalsData != null && vitalsData!.isNotEmpty)
                        _buildSectionBox(
                          title: "Vitals",
                          children: [
                            ...vitalsData!.map((vital) {
                              final recordedAt = vital['Recorded_at'] ?? '';
                              final dateTime = _parseDateTime(recordedAt);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                child: ListTile(
                                  title: Text(
                                    'Date: $dateTime',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoRowWithIcon(
                                        label: "Temperature",
                                        value: vital['Temperature'],
                                        icon: Icons.thermostat,
                                        iconColor: Colors.deepOrange,
                                      ),
                                      _buildInfoRowWithIcon(
                                        label: "Blood Pressure",
                                        value: vital['Blood_pressure'],
                                        icon: Icons.monitor_heart,
                                        iconColor: Colors.red,
                                      ),
                                      _buildInfoRowWithIcon(
                                        label: "Pulse Rate",
                                        value: vital['Pulse_rate'],
                                        icon: Icons.favorite,
                                        iconColor: Colors.pink,
                                      ),
                                      _buildInfoRowWithIcon(
                                        label: "Respiration Rate",
                                        value: vital['Respiration_rate'],
                                        icon: Icons.air,
                                        iconColor: Colors.lightBlue,
                                      ),
                                      _buildInfoRowWithIcon(
                                        label: "Oxygen Saturation",
                                        value: vital['Oxygen_saturation'],
                                        icon: Icons.masks,
                                        iconColor: Colors.tealAccent,
                                      ),
                                      _buildInfoRowWithIcon(
                                        label: "Random Blood Sugar",
                                        value: vital['Random_blood_sugar'],
                                        icon: Icons.bloodtype,
                                        iconColor: Colors.deepPurple,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            if (vitalsData == null || vitalsData!.isEmpty)
                              _buildNoDataMessage(
                                icon: Icons.thermostat,
                                message: 'No vitals data available yet',
                              ),
                          ],
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Button at the Bottom (only for vitals)
          if (!isInsertingVitals && !isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isInsertingVitals = true;
                      _isOxygenValid = true;
                      _isTemperatureValid = true;
                      _isTemperatureEmpty = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF103683),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Insert New Vitals',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),

          if (isInsertingVitals)
            Positioned(
              top: 150,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(30.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildVitalInputField(
                        controller: _temperatureController,
                        label: "Temperature*",
                        hint: "95-110°F",
                        icon: Icons.thermostat,
                        iconColor: Colors.deepOrange,
                        validator: (value) {
                          _validateTemperature(value ?? '');
                          if (_isTemperatureEmpty) return 'Temperature is required';
                          if (!_isTemperatureValid) return 'Must be 95-110°F';
                          return null;
                        },
                        isError: _isTemperatureEmpty || !_isTemperatureValid,
                      ),
                      _buildVitalInputField(
                        controller: _bloodPressureController,
                        label: "Blood Pressure",
                        hint: "e.g. 120/80",
                        icon: Icons.monitor_heart,
                        iconColor: Colors.red,
                      ),
                      _buildVitalInputField(
                        controller: _pulseRateController,
                        label: "Pulse Rate",
                        hint: "e.g. 72",
                        icon: Icons.favorite,
                        iconColor: Colors.pink,
                      ),
                      _buildVitalInputField(
                        controller: _respirationRateController,
                        label: "Respiration Rate",
                        hint: "e.g. 16",
                        icon: Icons.air,
                        iconColor: Colors.lightBlue,
                      ),
                      _buildVitalInputField(
                        controller: _oxygenSaturationController,
                        label: "Oxygen Saturation",
                        hint: "0-100%",
                        icon: Icons.masks,
                        iconColor: Colors.tealAccent,
                        validator: (value) {
                          _validateOxygen(value ?? '');
                          if (!_isOxygenValid) return 'Must be 0-100%';
                          return null;
                        },
                        isError: !_isOxygenValid,
                      ),
                      _buildVitalInputField(
                        controller: _randomBloodSugarController,
                        label: "Random Blood Sugar",
                        hint: "e.g. 100",
                        icon: Icons.bloodtype,
                        iconColor: Colors.deepPurple,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                isInsertingVitals = false;
                                _clearVitalsInputFields();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isFormValid ? _insertVitals : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFormValid ? const Color(0xFF103683) : Colors.grey,
                              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Insert Vitals',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}