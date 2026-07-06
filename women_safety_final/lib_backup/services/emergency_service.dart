import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import '../models/user_model.dart';
import 'voice_service.dart';
import 'sms_manager.dart';

class EmergencyService extends ChangeNotifier {
  final VoiceService _voiceService = VoiceService();
  bool _isListening = false;
  bool _isEmergencyTriggered = false;
  Position? _currentLocation;

  bool _isShakeDetectionActive = true;
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  Timer? _shakeResetTimer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  static const double SHAKE_THRESHOLD = 25.0;
  static const int SHAKE_COUNT_REQUIRED = 3;
  static const int SHAKE_TIMEOUT_MS = 1500;

  bool get isListening => _isListening;
  bool get isEmergencyTriggered => _isEmergencyTriggered;
  Position? get currentLocation => _currentLocation;

  EmergencyService() {
    _initializeSensors();
    _initializeVoice();
  }

  void _initializeSensors() {
    try {
      _accelerometerSubscription?.cancel();
      _accelerometerSubscription = accelerometerEvents.listen(
        (AccelerometerEvent event) {
          if (_isShakeDetectionActive) {
            _detectShake(event);
          }
        },
        onError: (error) {
          print('Sensor error: $error');
        },
      );
    } catch (e) {
      print('Error initializing sensors: $e');
    }
  }

  void _detectShake(AccelerometerEvent event) {
    double acceleration =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    double netAcceleration = (acceleration - 9.81).abs();

    if (netAcceleration > SHAKE_THRESHOLD) {
      DateTime now = DateTime.now();

      if (_lastShakeTime == null ||
          now.difference(_lastShakeTime!).inMilliseconds > SHAKE_TIMEOUT_MS) {
        _shakeCount = 1;
      } else {
        _shakeCount++;
      }
      _lastShakeTime = now;

      _shakeResetTimer?.cancel();
      _shakeResetTimer = Timer(Duration(milliseconds: SHAKE_TIMEOUT_MS), () {
        if (_shakeCount < SHAKE_COUNT_REQUIRED) {
          _shakeCount = 0;
        }
      });

      if (_shakeCount >= SHAKE_COUNT_REQUIRED) {
        _triggerEmergency('Shake gesture');
        _shakeCount = 0;
        _shakeResetTimer?.cancel();
      }
    }
  }

  Future<void> _initializeVoice() async {
    await _voiceService.initialize();
  }

  Future<void> startVoiceListening() async {
    try {
      await _voiceService.startListening((command) {
        _triggerEmergency('Voice: $command');
      });
      _isListening = true;
      notifyListeners();
    } catch (e) {
      print('Voice error: $e');
    }
  }

  void stopVoiceListening() {
    _voiceService.stopListening();
    _isListening = false;
    notifyListeners();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return;
      }

      _currentLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print(
          'Location obtained: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
    } catch (e) {
      print('Location error: $e');
    }
  }

  Future<void> _triggerEmergency(String triggerMethod) async {
    if (_isEmergencyTriggered) return;

    _isEmergencyTriggered = true;
    notifyListeners();

    await _getCurrentLocation();

    final prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('user_data');

    if (userJson != null) {
      Map<String, dynamic> userMap = jsonDecode(userJson);
      UserModel user = UserModel.fromJson(userMap);

      String locationText = _currentLocation != null
          ? "${_currentLocation!.latitude.toStringAsFixed(6)},${_currentLocation!.longitude.toStringAsFixed(6)}"
          : "Location unavailable";

      String mapsLink = _currentLocation != null
          ? "https://maps.google.com/?q=${_currentLocation!.latitude},${_currentLocation!.longitude}"
          : "No location";

      String message = '''
🚨 EMERGENCY ALERT 🚨
From: ${user.fullName}
Phone: ${user.phoneNumber}
Trigger: $triggerMethod
📍 Location: $locationText
🗺️ Map: $mapsLink
🕐 Time: ${DateTime.now()}

PLEASE HELP IMMEDIATELY!
''';

      // Send to emergency contact
      if (user.emergencyContactPhone.isNotEmpty) {
        print('Sending to emergency: ${user.emergencyContactPhone}');
        await SmsManager.sendSms(user.emergencyContactPhone, message);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Send to police
      if (user.policePhone.isNotEmpty) {
        print('Sending to police: ${user.policePhone}');
        await SmsManager.sendSms(user.policePhone, message);
      }
    }

    Future.delayed(const Duration(seconds: 30), () {
      _isEmergencyTriggered = false;
      notifyListeners();
    });
  }

  Future<void> manualEmergencyTrigger() async {
    print('Manual SOS triggered');
    await _triggerEmergency('Manual SOS');
  }

  void toggleShakeDetection(bool active) {
    _isShakeDetectionActive = active;
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _shakeResetTimer?.cancel();
    _voiceService.dispose();
    super.dispose();
  }
}
