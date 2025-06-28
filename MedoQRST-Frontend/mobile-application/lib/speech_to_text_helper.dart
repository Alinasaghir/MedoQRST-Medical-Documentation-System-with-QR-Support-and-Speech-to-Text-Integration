import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToTextHelper {
  late stt.SpeechToText _speech;
  bool _isListening = false;

  SpeechToTextHelper() {
    _speech = stt.SpeechToText();
  }

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
        },
        onError: (error) {
          debugPrint('Speech error: $error');
        },
      );
      return available;
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      return false;
    }
  }

  Future<void> startListening(Function(String) onResult, BuildContext context) async {
    if (!_isListening) {
      bool available = await initialize();
      if (available) {
        _isListening = true;
        _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              onResult(result.recognizedWords);
            }
          },
          listenMode: stt.ListenMode.dictation,
          partialResults: false,
        );
      } else {
        debugPrint('Speech-to-text not available');
        // Show a message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device.'),
          ),
        );
      }
    }
  }

  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
  }
}