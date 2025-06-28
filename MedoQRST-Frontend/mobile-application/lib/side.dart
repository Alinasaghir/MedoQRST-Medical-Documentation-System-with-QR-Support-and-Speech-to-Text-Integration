import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:MedoQRST/doctorview.dart';

Future<void> requestMicrophonePermission() async {
  var status = await Permission.microphone.status;
  if (!status.isGranted) {
    await Permission.microphone.request();
  }
}

class WardOverScreen extends StatefulWidget {
  final String wardNo;
  const WardOverScreen({Key? key, required this.wardNo}) : super(key: key);

  @override
  WardOverScreenState createState() => WardOverScreenState();
}

class WardOverScreenState extends State<WardOverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _speechResult = '';
  List<Map<String, dynamic>> _wardBeds = [];
  List<Map<String, dynamic>> _allBeds = [];
  List<Map<String, dynamic>> _filteredBeds = [];
  bool _isLoading = true;
  String? _currentUserId;
  bool? _isDoctor;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _loadUserInfo();
    _fetchData();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId') ??
          prefs.getString('logged_in_doctor_id') ??
          '';
      _isDoctor = _currentUserId?.isNotEmpty;
    });
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speechToText.initialize();
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final wardBeds = await _fetchWardBeds(widget.wardNo);
      final wardOverData = await _fetchHospitalData();

      final mergedBeds = wardBeds.map((bed) {
        final bedNo = bed['Bed_no'];
        final wardNo = bed['Ward_no'];

        final wardOverEntry = wardOverData.firstWhere(
          (item) => item['Bed_no'] == bedNo && item['Ward_no'] == wardNo,
          orElse: () => {
            'Bed_no': bedNo,
            'Ward_no': wardNo,
            'messages': [],
          },
        );

        return {
          ...bed,
          ...wardOverEntry,
        };
      }).toList();

      setState(() {
        _wardBeds = wardBeds;
        _allBeds = mergedBeds;
        _filteredBeds = List.from(mergedBeds);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: ${e.toString()}')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWardBeds(String wardNo) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.57.148.47:1232/ward-beds?ward_no=$wardNo'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load ward beds: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching ward beds: $e');
      throw Exception('Failed to load ward beds');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchHospitalData() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.57.148.47:8090/api/orders'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as List<dynamic>;
        Map<String, Map<String, dynamic>> groupedData = {};

        for (var entry in data) {
          if (entry['Ward_no'] == widget.wardNo) {
            String key = '${entry['Bed_no']}-${entry['Ward_no']}';
            String doctorId = entry['Last_updated_by'] ?? 'Unknown';

            if (!groupedData.containsKey(key)) {
              groupedData[key] = {
                'Bed_no': entry['Bed_no'],
                'Ward_no': entry['Ward_no'],
                'messages': [
                  {
                    'note': entry['Update_notes'],
                    'time': entry['Last_update_time'],
                    'date': entry['Last_update_date'],
                    'doctor_id': doctorId,
                  }
                ],
              };
            } else {
              groupedData[key]!['messages'].add({
                'note': entry['Update_notes'],
                'time': entry['Last_update_time'],
                'date': entry['Last_update_date'],
                'doctor_id': doctorId,
              });
            }
          }
        }
        return groupedData.entries.map((e) => e.value).toList();
      } else {
        throw Exception(
            'Failed to fetch hospital data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error: $e');
      throw Exception('Failed to fetch hospital data');
    }
  }

  void _updateSearchQuery(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBeds = List<Map<String, dynamic>>.from(_allBeds);
      } else {
        String normalizedQuery = query.toLowerCase().replaceAll(' ', '');

        _filteredBeds = _allBeds.where((bed) {
          String bedNumber = bed['Bed_no'].toString();
          String wardNumber = bed['Ward_no'].toString();

          return 'bed$bedNumber'
                  .toLowerCase()
                  .replaceAll(' ', '')
                  .contains(normalizedQuery) ||
              'ward$wardNumber'
                  .toLowerCase()
                  .replaceAll(' ', '')
                  .contains(normalizedQuery) ||
              bedNumber.toLowerCase().contains(normalizedQuery) ||
              wardNumber.toLowerCase().contains(normalizedQuery) ||
              _matchWordNumber(query, bedNumber);
        }).toList();
      }
    });
  }

  bool _matchWordNumber(String query, String bedNumber) {
    final numberWords = {
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
    };

    String normalizedQuery = query.toLowerCase().replaceAll(' ', '');

    for (final entry in numberWords.entries) {
      if (normalizedQuery.contains(entry.key)) {
        return bedNumber == entry.value;
      }
    }

    return false;
  }

  void _toggleListening() async {
    try {
      if (_isListening) {
        _speechToText.stop();
      } else {
        await requestMicrophonePermission();

        bool available = await _speechToText.initialize();
        if (available) {
          _speechToText.listen(
            onResult: (result) {
              setState(() {
                _speechResult = result.recognizedWords;
                _searchController.text = _speechResult;
                _updateSearchQuery(_speechResult);
              });
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available')),
          );
        }
      }
      setState(() {
        _isListening = !_isListening;
      });
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to initialize speech recognition')),
      );
    }
  }

  void _navigateToNotesScreen(Map<String, dynamic> bed) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotesScreen(bed: bed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
// In your WardOverScreen's AppBar, add a custom back button handler:
appBar: AppBar(
  title: const Text('Ward Over Register', style: TextStyle(color: Colors.white)),
  elevation: 4,
  backgroundColor: const Color(0xFF00008C),
  iconTheme: const IconThemeData(color: Colors.white),
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      // This will pop the current route and go back to QRViewExample
      Navigator.of(context).pop();
    },
  ),
),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search beds...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF00008C)),
                      suffixIcon: IconButton(
                        icon: Icon(_isListening ? Icons.stop : Icons.mic,
                            color: const Color(0xFF00008C)),
                        onPressed: _toggleListening,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF87CEFB).withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _updateSearchQuery,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredBeds.length,
                    itemBuilder: (context, index) {
                      final bed = _filteredBeds[index];
                      final bedNo = bed['Bed_no'];
                      final wardNo = bed['Ward_no'];
                      final hasPatient = bed['hasPatient'] == 1;
                      final hasMessages = (bed['messages'] as List).isNotEmpty;
                      return GestureDetector(
                        onTap: () => _navigateToNotesScreen(bed),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFF00008C),
                              width: 2,
                            ),
                          ),
                          color: hasPatient ? Colors.white : Colors.grey[200],
                          child: ListTile(
                            leading: Icon(Icons.bed,
                                color: hasPatient
                                    ? const Color(0xFF659CDF)
                                    : Colors.grey),
                            title: Text(
                              'Bed $bedNo - Ward $wardNo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: hasPatient
                                    ? const Color(0xFF00008C)
                                    : Colors.grey,
                              ),
                            ),
                            subtitle: hasMessages
                                ? const Text('Please tap to add more notes',
                                    style: TextStyle(color: Color(0xFF103683)))
                                : const Text('No ward over notes - tap to add',
                                    style: TextStyle(color: Color(0xFF103683))),
                            trailing: const Icon(Icons.chevron_right,
                                color: Color(0xFF00008C)),
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
}

class NotesScreen extends StatefulWidget {
  final Map<String, dynamic> bed;

  const NotesScreen({Key? key, required this.bed}) : super(key: key);

  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final bool _isListening = false;
  String _doctorId = '';
  String _speechResult = '';
  List<dynamic> _filteredMessages = [];
  String? _currentUserId;
  bool? _isDoctor;
  bool _isListeningForSearch = false;
  bool _isListeningForMessage = false;
  Map<String, String> _doctorNames = {};
  @override
  void initState() {
    super.initState();
    _filteredMessages = List<dynamic>.from(widget.bed['messages']);
    _sortMessages();
    _loadUserInfo();
    _initializeDoctorId();
    _initializeSpeech();
    _fetchDoctorNames();
  }

  Future<void> _fetchDoctorNames() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.57.148.47:1232/departmentsWithDoctors'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> departments = jsonDecode(response.body);
        final Map<String, String> doctorNames = {};

        for (var dept in departments) {
          if (dept['Doctors'] != null) {
            for (var doctor in dept['Doctors']) {
              if (doctor['DoctorID'] != null && doctor['DoctorName'] != null) {
                doctorNames[doctor['DoctorID'].toString()] =
                    doctor['DoctorName'].toString();
              }
            }
          }
        }

        setState(() {
          _doctorNames = doctorNames;
        });
      }
    } catch (e) {
      debugPrint('Error fetching doctor names: $e');
    }
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId') ??
          prefs.getString('logged_in_doctor_id') ??
          '';
      _isDoctor = _currentUserId?.isNotEmpty ?? false;
    });
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speechToText.initialize();
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
    }
  }

  Future<void> _initializeDoctorId() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDoctorId = prefs.getString('userId') ??
        prefs.getString('logged_in_doctor_id') ??
        'Unknown';
    setState(() {
      _doctorId = storedDoctorId;
    });
  }

  void _toggleListeningForMessage() async {
    try {
      if (_isListeningForMessage) {
        _speechToText.stop();
      } else {
        await requestMicrophonePermission();
        bool available = await _speechToText.initialize();
        if (available) {
          _speechToText.listen(
            onResult: (result) {
              setState(() {
                _speechResult = result.recognizedWords;
                _messageController.text = _speechResult;
              });
            },
          );
        }
      }
      setState(() {
        _isListeningForMessage = !_isListeningForMessage;
        if (_isListeningForMessage) _isListeningForSearch = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _updateSearchQuery(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMessages = List<dynamic>.from(widget.bed['messages']);
      } else {
        _filteredMessages = widget.bed['messages']
            .where((message) => message['note']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
    _sortMessages();
  }

  void _sortMessages() {
    _filteredMessages.sort((a, b) {
      final dateTimeA = DateTime.parse('${a['date']} ${a['time']}');
      final dateTimeB = DateTime.parse('${b['date']} ${b['time']}');
      return dateTimeA.compareTo(dateTimeB);
    });
  }

  Future<void> _deleteMessage(int index) async {
    final bedNoToDelete = widget.bed['Bed_no'];
    final wardNoToDelete = widget.bed['Ward_no'];
    final messageTimeToDelete = widget.bed['messages'][index]['time'];
    final messageDateToDelete = widget.bed['messages'][index]['date'];

    final url = Uri.parse(
        'http://10.57.148.47:8090/api/orders/$bedNoToDelete/$wardNoToDelete/$messageTimeToDelete/$messageDateToDelete');

    final response = await http.delete(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    setState(() {
      widget.bed['messages'].removeAt(index);
      _filteredMessages.removeAt(index);
    });
  }

  Future<void> _updateMessageToApi(int index, String updatedNote) async {
    try {
      final message = _filteredMessages[index];
      final url = Uri.parse(
          'http://10.57.148.47:8090/api/orders/${widget.bed['Bed_no']}/${widget.bed['Ward_no']}/${message['time']}/${message['date']}');

      final body = {
        'Update_notes': updatedNote,
        'Last_updated_by': _doctorId,
      };

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _filteredMessages[index]['note'] = updatedNote;
          widget.bed['messages'][index]['note'] = updatedNote;
        });
      } else {
        throw Exception('Failed to update message: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to update message. Please try again.')),
      );
    }
  }

  Future<void> _editMessage(int index) async {
    final messageToEdit = _filteredMessages[index];
    final TextEditingController _editController =
        TextEditingController(text: messageToEdit['note']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: _editController,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Enter your updated message...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedNote = _editController.text.trim();
                if (updatedNote.isNotEmpty) {
                  await _updateMessageToApi(index, updatedNote);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addMessageToApi(String note) async {
    try {
      final now = DateTime.now();
      final formattedTime = DateFormat('HH:mm:ss').format(now);
      final formattedDate = DateFormat('yyyy-MM-dd').format(now);

      final url = Uri.parse('http://10.57.148.47:8090/api/orders');
      final body = {
        'Bed_no': widget.bed['Bed_no'].toString(),
        'Ward_no': widget.bed['Ward_no'].toString(),
        'Update_notes': note,
        'Last_update_time': formattedTime,
        'Last_update_date': formattedDate,
        'Last_updated_by': _doctorId,
      };

      final postResponse = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (postResponse.statusCode == 200 || postResponse.statusCode == 201) {
        setState(() {
          widget.bed['messages'].add({
            'note': note,
            'time': formattedTime,
            'date': formattedDate,
            'doctor_id': _doctorId,
          });
          _filteredMessages = List<dynamic>.from(widget.bed['messages']);
          _sortMessages();
        });
      } else {
        throw Exception(
            'Failed to add message to the server: ${postResponse.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to add message. Please try again.')),
      );
    }
  }

  void _toggleListeningForSearch() async {
    try {
      if (_isListeningForSearch) {
        _speechToText.stop();
      } else {
        await requestMicrophonePermission();
        bool available = await _speechToText.initialize();
        if (available) {
          _speechToText.listen(
            onResult: (result) {
              setState(() {
                _speechResult = result.recognizedWords;
                _searchController.text = _speechResult;
                _updateSearchQuery(_speechResult);
              });
            },
          );
        }
      }
      setState(() {
        _isListeningForSearch = !_isListeningForSearch;
        if (_isListeningForSearch) _isListeningForMessage = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes for Bed ${widget.bed['Bed_no']}',
            style: const TextStyle(color: Colors.white)),
        elevation: 4,
        backgroundColor: const Color(0xFF00008C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00008C)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isListeningForSearch ? Icons.stop : Icons.mic,
                    color: const Color(0xFF00008C),
                  ),
                  onPressed: _toggleListeningForSearch,
                ),
                filled: true,
                fillColor: const Color(0xFF87CEFB).withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => _updateSearchQuery(value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredMessages.length,
              itemBuilder: (context, index) {
                final message = _filteredMessages[index];
                final doctorId = message['doctor_id'] ?? 'Unknown';
                final doctorName = _doctorNames[doctorId] ?? doctorId;
                final isLoggedDoctor = message['doctor_id'] == _doctorId;
                final messageDate = DateTime.parse(message['date']);
                final messageDateTime =
                    DateTime.parse("${message['date']} ${message['time']}");
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final yesterday = today.subtract(const Duration(days: 1));

                bool showDate = false;
                String dateDisplay = '';

                if (index == 0 ||
                    DateTime.parse(_filteredMessages[index - 1]['date'])
                            .toLocal()
                            .day !=
                        messageDate.toLocal().day) {
                  if (messageDate.isAtSameMomentAs(today)) {
                    dateDisplay = 'Today';
                  } else if (messageDate.isAtSameMomentAs(yesterday)) {
                    dateDisplay = 'Yesterday';
                  } else {
                    dateDisplay =
                        DateFormat('MMM dd, yyyy').format(messageDate);
                  }
                  showDate = true;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDate)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: Text(
                            dateDisplay,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: isLoggedDoctor
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isLoggedDoctor
                                  ? const Color(0xFF87CEFB).withOpacity(0.3)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isLoggedDoctor
                                    ? const Radius.circular(16)
                                    : const Radius.circular(0),
                                bottomRight: isLoggedDoctor
                                    ? const Radius.circular(0)
                                    : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['note'],
                                  style: const TextStyle(fontSize: 16),
                                  softWrap: true,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('h:mm a').format(messageDateTime),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Sent by: Dr. ${doctorName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Color.fromARGB(255, 128, 85, 185),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isLoggedDoctor)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Color(0xFF00008C)),
                                onPressed: () => _editMessage(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Color.fromARGB(255, 218, 61, 61)),
                                onPressed: () => _deleteMessage(index),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Enter your message...',
                prefixIcon: const Icon(Icons.message, color: Color(0xFF00008C)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isListeningForMessage ? Icons.stop : Icons.mic,
                        color: const Color(0xFF00008C),
                      ),
                      onPressed: _toggleListeningForMessage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF00008C)),
                      onPressed: () {
                        String message = _messageController.text.trim();
                        if (message.isNotEmpty) {
                          _addMessageToApi(message);
                          _messageController.clear();
                        }
                      },
                    ),
                  ],
                ),
                filled: true,
                fillColor: const Color(0xFF87CEFB).withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: null,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final String wardNo;
  const HistoryScreen({Key? key, required this.wardNo}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final bool _isListening = false;
  final String _speechResult = '';

  List<Map<String, dynamic>> _allBeds = [];
  List<Map<String, dynamic>> _filteredBeds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHospitalData();
  }

  Future<void> _fetchHospitalData() async {
    try {
      final wardBeds = await http.get(
        Uri.parse(
            'http://10.57.148.47:1232/ward-beds?ward_no=${widget.wardNo}'),
      );

      if (wardBeds.statusCode == 200) {
        final List<dynamic> beds = jsonDecode(wardBeds.body);

        final response =
            await http.get(Uri.parse('http://10.57.148.47:8090/api/orders'));
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body) as List<dynamic>;

          Map<String, Map<String, dynamic>> groupedData = {};

          for (var bed in beds) {
            String key = '${bed['Bed_no']}-${bed['Ward_no']}';
            groupedData[key] = {
              'Bed_no': bed['Bed_no'],
              'Ward_no': bed['Ward_no'],
              'messages': [],
            };
          }

          for (var entry in data) {
            if (entry['Ward_no'] == widget.wardNo) {
              String key = '${entry['Bed_no']}-${entry['Ward_no']}';
              if (groupedData.containsKey(key)) {
                groupedData[key]!['messages'].add({
                  'note': entry['Update_notes'],
                  'time': entry['Last_update_time'],
                  'date': entry['Last_update_date'],
                  'doctor_id': entry['Last_updated_by'] ?? 'Unknown',
                });
              }
            }
          }

          setState(() {
            _allBeds = groupedData.values.toList();
            _filteredBeds = List.from(_allBeds);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updateSearchQuery(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBeds = List<Map<String, dynamic>>.from(_allBeds);
      } else {
        _filteredBeds = _allBeds
            .where((bed) =>
                'bed${bed['Bed_no']}'
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                bed['Ward_no']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('History File', style: TextStyle(color: Colors.white)),
        elevation: 4,
        backgroundColor: const Color(0xFF00008C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search beds...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF00008C)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: const Color(0xFF00008C),
                        ),
                        onPressed: () {},
                      ),
                      filled: true,
                      fillColor: const Color(0xFF87CEFB).withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => _updateSearchQuery(value),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredBeds.length,
                    itemBuilder: (context, index) {
                      final bed = _filteredBeds[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BedDetailsScreen(
                                bedNo: bed['Bed_no'].toString(),
                                wardNo: bed['Ward_no'].toString(),
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFF00008C),
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            leading:
                                Icon(Icons.bed, color: const Color(0xFF659CDF)),
                            title: Text(
                              'Bed ${bed['Bed_no']} - Ward ${bed['Ward_no']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00008C)),
                            ),
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
}

class BedDetailsScreen extends StatefulWidget {
  final String bedNo;
  final String wardNo;

  const BedDetailsScreen({
    Key? key,
    required this.bedNo,
    required this.wardNo,
  }) : super(key: key);

  @override
  _BedDetailsScreenState createState() => _BedDetailsScreenState();
}

class _BedDetailsScreenState extends State<BedDetailsScreen> {
  Map<String, dynamic> _patientData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPatientData();
  }

  Future<void> _fetchPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'http://10.57.148.47:1232/patient?ward_no=${widget.wardNo}&bed_no=${widget.bedNo}'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List<dynamic> && data.isNotEmpty) {
          final patient = data[0];

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

          List<Map<String, dynamic>> consultationDetails = [];
          Set<String> uniqueConsultationKeys = {};
          for (var item in data) {
            if (item.containsKey('ConsultingPhysicianDepartment') &&
                item.containsKey('ConsultationDate')) {
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
                      item['RequestingPhysicianDepartment'] ?? 'Unknown',
                  'Requesting_Doctor_ID':
                      item['Requesting_Physician'] ?? 'Unknown',
                  'Requesting_Doctor_Name':
                      item['RequestingPhysicianName'] ?? 'Unknown',
                  'ConsultationDate': item['ConsultationDate'] ?? 'N/A',
                  'ConsultationTime': item['ConsultationTime'] ?? 'N/A',
                  'Reason': item['Reason'] ?? 'No reason provided',
                  'Additional_Description':
                      item['Additional_Description'] ?? 'No description',
                  'Type_of_Comments': item['Type_of_Comments'] ?? 'No comments',
                });
              }
            }
          }

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
                      item['DrugCommercialName'] ?? 'Unknown',
                  'Drug_Generic_Name': item['DrugGenericName'] ?? 'Unknown',
                  'Strength': item['DrugStrength'] ?? 'Unknown',
                  'Dosage': item['Dosage'] ?? 'Unknown',
                  'Medication_Date': item['MedicationDate'] ?? 'N/A',
                  'Medication_Time': item['MedicationTime'] ?? 'N/A',
                  'Monitored_By': item['Monitored_By'] ?? 'Unknown',
                  'Shift': item['Shift'] ?? 'Unknown',
                });
              }
            }
          }

          List<Map<String, dynamic>> vitalDetails = [];
          Set<String> uniqueVitalKeys = {};
          for (var item in data) {
            if (item.containsKey('Recorded_at') &&
                item.containsKey('Blood_pressure')) {
              final vitalKey =
                  '${item['Recorded_at']}-${item['Blood_pressure']}';
              if (!uniqueVitalKeys.contains(vitalKey)) {
                uniqueVitalKeys.add(vitalKey);
                vitalDetails.add({
                  'Recorded_at': item['Recorded_at'] ?? 'N/A',
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
            "vitalDetails": vitalDetails,
          };

          setState(() {
            _patientData = filteredPatientData;
            _isLoading = false;
          });
        } else {
          throw Exception('No patient data found');
        }
      } else {
        throw Exception('Failed to fetch patient data');
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch patient data')),
      );
    }
  }

  void _navigateToDetailPage(String sheetName) {
    if (sheetName == 'Discharge Sheet') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DischargeSheet(
            admissionNo: _patientData['Admission_no'] ?? 'N/A',
            name: _patientData['PatientName'] ?? 'N/A',
            date: _patientData['Admission_date'] ?? 'N/A',
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DetailPageWithoutEdit(
            sheetName: sheetName,
            patientData: _patientData,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF87CEFB), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_hospital,
                                    size: 18,
                                    color: Color(0xFF00008C),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ward: ${widget.wardNo}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 10, 10, 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.hotel,
                                    size: 18,
                                    color: Color(0xFF00008C),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Bed: ${widget.bedNo}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF659CDF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF103683), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 16,
                                color: Color(0xFF103683),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'View Mode',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF103683),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const BreathingAnimation(
                      child: Icon(
                        Icons.medical_services,
                        size: 60,
                        color: Color(0xFF00008C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Patient Records Overview',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00008C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Select a document to view detailed information:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF103683),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 16.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildOptionButton(context, 'Progress Report',
                          Icons.timeline, const Color(0xFF659CDF)),
                      _buildOptionButton(context, 'Consultation Sheet',
                          Icons.people, const Color(0xFF659CDF)),
                      _buildOptionButton(context, 'Drug Sheet',
                          Icons.medication, const Color(0xFF659CDF)),
                      _buildOptionButton(context, 'Receiving Notes',
                          Icons.note_add, const Color(0xFF659CDF)),
                      _buildOptionButton(context, 'Registration Sheet',
                          Icons.assignment, const Color(0xFF659CDF)),
                      _buildOptionButton(context, 'Discharge Sheet', Icons.copy,
                          const Color(0xFF659CDF)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
        onTap: () => _navigateToDetailPage(title),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFF00008C),
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
}
