import 'package:flutter/services.dart';

class NativeSmsService {
  static const MethodChannel _channel = MethodChannel('native_sms_channel');

  static Future<bool> sendSmsDirectly(
      String phoneNumber, String message) async {
    try {
      final bool result = await _channel.invokeMethod('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result;
    } catch (e) {
      print('Error sending SMS natively: $e');
      return false;
    }
  }
}
