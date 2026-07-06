import 'package:flutter/services.dart';

class SmsManager {
  static const MethodChannel _channel = MethodChannel('native_sms');

  static Future<bool> sendSms(String phoneNumber, String message) async {
    try {
      final bool result = await _channel.invokeMethod('sendSms', {
        'phone': phoneNumber,
        'message': message,
      });
      return result;
    } catch (e) {
      print('SMS error: $e');
      return false;
    }
  }
}
