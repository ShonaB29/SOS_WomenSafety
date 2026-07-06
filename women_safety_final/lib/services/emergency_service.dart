import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import '../models/user_model.dart';
import '../utils/logger.dart';
import 'voice_service.dart';
import 'sms_service.dart';

class EmergencyService extends ChangeNotifier {
  final VoiceService _voiceService = VoiceService();
  final SmsService _smsService = SmsService();
  bool _isListening = false;
  bool _isEmergencyTriggered = false;
  Position? _currentLocation;
  
  // Shake detection variables
  bool _isShakeDetectionActive = true;
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  Timer? _shakeResetTimer;
  
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  
  static const double _shakeThreshold = 25.0;
  static const int _shakeCountRequired = 3;
  static const int _shakeTimeoutMs = 1500;

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
      
      _accelerometerSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (_isShakeDetectionActive) {
            _detectShake(event);
          }
        },
        onError: (error) {
          Logger.log('Sensor error: $error');
          Future.delayed(const Duration(seconds: 2), () {
            _initializeSensors();
          });
        },
      );
      
      Logger.log('Sensors initialized successfully');
    } catch (e) {
      Logger.log('Error initializing sensors: $e');
    }
  }

  void _detectShake(AccelerometerEvent event) {
    double acceleration = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    double netAcceleration = (acceleration - 9.81).abs();
    
    if (netAcceleration > _shakeThreshold) {
      DateTime now = DateTime.now();
      
      if (_lastShakeTime == null || 
          now.difference(_lastShakeTime!).inMilliseconds > _shakeTimeoutMs) {
        _shakeCount = 1;
      } else {
        _shakeCount++;
      }
      
      _lastShakeTime = now;
      Logger.log('Shake detected! Count: $_shakeCount');
      
      _shakeResetTimer?.cancel();
      
      _shakeResetTimer = Timer(const Duration(milliseconds: _shakeTimeoutMs), () {
        if (_shakeCount < _shakeCountRequired) {
          _shakeCount = 0;
          Logger.log('Shake count reset');
        }
      });
      
      if (_shakeCount >= _shakeCountRequired) {
        Logger.log('SOS triggered by shake gesture!');
        _triggerEmergency('Shake gesture (3 continuous shakes)');
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
        Logger.log('Voice command detected: $command');
        _triggerEmergency('Voice command: "$command"');
      });
      _isListening = true;
      notifyListeners();
      Logger.log('Voice listening started');
    } catch (e) {
      Logger.log('Error starting voice listening: $e');
    }
  }

  void stopVoiceListening() {
    _voiceService.stopListening();
    _isListening = false;
    notifyListeners();
    Logger.log('Voice listening stopped');
  }

  Future<void> _triggerEmergency(String triggerMethod) async {
    if (_isEmergencyTriggered) return;
    
    Logger.log('🚨 EMERGENCY TRIGGERED! Method: $triggerMethod');
    _isEmergencyTriggered = true;
    notifyListeners();

    await _getCurrentLocation();

    final prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('user_data');
    
    if (userJson != null) {
      Map<String, dynamic> userMap = jsonDecode(userJson);
      UserModel user = UserModel.fromJson(userMap);
      
      String shortLocation = _currentLocation != null 
          ? "${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}"
          : "Location unavailable";
          
      String mapsLink = _currentLocation != null
          ? "https://maps.google.com/?q=${_currentLocation!.latitude},${_currentLocation!.longitude}"
          : "Location unavailable";

      String emergencyMessage = '''🚨 EMERGENCY! ${user.fullName}
📍 $shortLocation
🕐 ${DateTime.now().toString().substring(0, 19)}
🔍 $mapsLink''';

      Logger.log('Sending SMS to emergency contact: ${user.emergencyContactPhone}');
      await _smsService.sendDirectSms(user.emergencyContactPhone, emergencyMessage);
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      Logger.log('Sending SMS to police: ${user.policePhone}');
      await _smsService.sendDirectSms(user.policePhone, emergencyMessage);
      
      Logger.log('✅ Emergency SMS sent to both contacts');
    }

    Future.delayed(const Duration(seconds: 30), () {
      _isEmergencyTriggered = false;
      notifyListeners();
      Logger.log('Emergency state reset');
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Logger.log('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.log('Location permissions are denied');
          return;
        }
      }

      _currentLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      Logger.log('Location obtained');
    } catch (e) {
      Logger.log('Location error: $e');
    }
  }

Future<void> manualEmergencyTrigger() async {
    await _triggerEmergency('Manual SOS button');
  }

  void toggleShakeDetection(bool active) {
    _isShakeDetectionActive = active;
    Logger.log('Shake detection ${active ? 'enabled' : 'disabled'}');
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _shakeResetTimer?.cancel();
    _voiceService.dispose();
    super.dispose();
  }
}