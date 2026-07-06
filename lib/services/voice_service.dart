import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../utils/logger.dart';

class VoiceService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';
  bool _isAvailable = false;

  static const List<String> _emergencyPhrases = [
    'i am caught',
    'help me',
    'save me',
    'emergency',
    'someone save me',
    'i am in danger',
    'caught someone',
    'please help',
    'danger',
  ];

  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  bool get isAvailable => _isAvailable;

  Future<void> initialize() async {
    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        Logger.log('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          notifyListeners();
        }
      },
      onError: (error) {
        Logger.log('Speech error: $error');
        _isListening = false;
        notifyListeners();
      },
    );

    if (!_isAvailable) {
      Logger.log('Speech recognition not available');
    }
    notifyListeners();
  }

  Future<void> startListening(Function(String) onEmergencyDetected) async {
    if (!_isAvailable) {
      await initialize();
    }

    if (!_isAvailable) {
      Logger.log('Speech recognition still not available');
      return;
    }

    _isListening = true;
    notifyListeners();

    _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords.toLowerCase();
        Logger.log('Heard: $_lastWords');

        for (String phrase in _emergencyPhrases) {
          if (_lastWords.contains(phrase)) {
            onEmergencyDetected(_lastWords);
            break;
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
      localeId: 'en_US',
    );
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
