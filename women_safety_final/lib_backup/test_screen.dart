import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:math';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  // Sensor variables
  int _shakeCount = 0;
  String _sensorStatus = "Initializing sensors...";
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  final List<String> _sensorLog = [];
  
  // Voice variables
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceStatus = "Initializing voice...";
  String _lastWords = "";
  bool _isVoiceAvailable = false;
  final List<String> _voiceLog = [];

  @override
  void initState() {
    super.initState();
    _initSensors();
    _initVoice();
  }

  void _initSensors() {
    try {
      _addToSensorLog("Attempting to initialize sensors...");
      
      _sensorSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          setState(() {
            double intensity = sqrt(event.x*event.x + event.y*event.y + event.z*event.z);
            
            // Update status
            _sensorStatus = "X: ${event.x.toStringAsFixed(2)}\n"
                           "Y: ${event.y.toStringAsFixed(2)}\n"
                           "Z: ${event.z.toStringAsFixed(2)}\n"
                           "Intensity: ${intensity.toStringAsFixed(2)}";
            
            // Check for shake (intensity > 25 is a good threshold)
            if (intensity > 25) {
              _shakeCount++;
              _addToSensorLog("✅ SHAKE DETECTED! #$_shakeCount (Intensity: ${intensity.toStringAsFixed(2)})");
              
              // Show dialog on every 3rd shake
              if (_shakeCount % 3 == 0) {
                _showShakeDialog();
              }
            }
          });
        },
        onError: (error) {
          _addToSensorLog("❌ Sensor error: $error");
          setState(() {
            _sensorStatus = "Error: $error";
          });
        },
      );
      
      _addToSensorLog("✅ Sensors initialized successfully");
    } catch (e) {
      _addToSensorLog("❌ Failed to initialize sensors: $e");
      setState(() {
        _sensorStatus = "Failed: $e";
      });
    }
  }

  Future<void> _initVoice() async {
    try {
      _addToVoiceLog("Initializing voice recognition...");
      
      _isVoiceAvailable = await _speech.initialize(
        onStatus: (status) {
          _addToVoiceLog("Status: $status");
          setState(() {
            _voiceStatus = "Status: $status";
          });
        },
        onError: (error) {
          _addToVoiceLog("❌ Error: $error");
          setState(() {
            _voiceStatus = "Error: $error";
          });
        },
      );
      
      if (_isVoiceAvailable) {
        _addToVoiceLog("✅ Voice recognition available");
        setState(() {
          _voiceStatus = "Ready - Tap Start Listening";
        });
      } else {
        _addToVoiceLog("❌ Voice recognition not available");
        setState(() {
          _voiceStatus = "Not available";
        });
      }
    } catch (e) {
      _addToVoiceLog("❌ Init failed: $e");
      setState(() {
        _voiceStatus = "Failed: $e";
      });
    }
  }

  void _startListening() async {
    if (!_isVoiceAvailable) {
      await _initVoice();
    }
    
    if (_isVoiceAvailable) {
      setState(() {
        _isListening = true;
        _voiceStatus = "Listening... Speak now";
      });
      
      _addToVoiceLog("Started listening...");
      
      _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
            _voiceStatus = "Heard: $_lastWords";
          });
          _addToVoiceLog("✅ Recognized: '${result.recognizedWords}'");
          
          // Check for emergency words
          String lower = result.recognizedWords.toLowerCase();
          if (lower.contains('help') || 
              lower.contains('save') || 
              lower.contains('caught') || 
              lower.contains('emergency')) {
            _showVoiceDialog(lower);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
        localeId: 'en_US',
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      _voiceStatus = "Stopped";
    });
    _addToVoiceLog("Stopped listening");
  }

  void _addToSensorLog(String message) {
    setState(() {
      _sensorLog.insert(0, "${DateTime.now().toString().split(' ')[1]} - $message");
      if (_sensorLog.length > 10) _sensorLog.removeLast();
    });
  }

  void _addToVoiceLog(String message) {
    setState(() {
      _voiceLog.insert(0, "${DateTime.now().toString().split(' ')[1]} - $message");
      if (_voiceLog.length > 10) _voiceLog.removeLast();
    });
  }

  void _showShakeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SHAKE DETECTED!'),
        content: Text('You have shaken the phone $_shakeCount times'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVoiceDialog(String command) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('VOICE COMMAND DETECTED'),
        content: Text('You said: "$command"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor & Voice Test'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sensor Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📳 SHAKE SENSOR TEST',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _sensorStatus,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Shake Count: $_shakeCount',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _shakeCount > 0 ? Colors.green : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• Shake phone vigorously'),
                    const Text('• Watch for SHAKE DETECTED messages'),
                    const Text('• Every 3 shakes should show a dialog'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _shakeCount = 0;
                          _sensorLog.clear();
                        });
                      },
                      child: const Text('Reset Counter'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Event Log:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        reverse: true,
                        itemCount: _sensorLog.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              _sensorLog[index],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Voice Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎤 VOICE TEST',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _voiceStatus,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          if (_lastWords.isNotEmpty)
                            Text(
                              'Last: "$_lastWords"',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isListening ? null : _startListening,
                          icon: const Icon(Icons.mic),
                          label: const Text('Start'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isListening ? _stopListening : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Try saying:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• "help me"'),
                    const Text('• "save me"'),
                    const Text('• "i am caught"'),
                    const Text('• "emergency"'),
                    const SizedBox(height: 8),
                    const Text(
                      'Event Log:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        reverse: true,
                        itemCount: _voiceLog.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              _voiceLog[index],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
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
}