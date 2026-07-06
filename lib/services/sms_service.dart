import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/logger.dart';

class SmsService {
  // Request SMS permissions
  Future<bool> requestSmsPermissions() async {
    try {
      var status = await Permission.sms.status;
      if (!status.isGranted) {
        Logger.log('Requesting SMS permission...');
        status = await Permission.sms.request();
      }
      Logger.log('SMS permission status: $status');
      return status.isGranted;
    } catch (e) {
      Logger.log('Error requesting SMS permission: $e');
      return false;
    }
  }

  // Send SMS using url_launcher
  Future<bool> sendDirectSms(String phoneNumber, String message) async {
    try {
      Logger.log('Attempting to send SMS to $phoneNumber');

      final encodedMessage = Uri.encodeComponent(message);
      final Uri smsUri = Uri.parse('sms:$phoneNumber?body=$encodedMessage');
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        Logger.log('SMS app opened for: $phoneNumber');
        return true;
      } else {
        Logger.log('Could not launch SMS app');
        return false;
      }
    } catch (e) {
      Logger.log('Error sending SMS: $e');
      return false;
    }
  }

  // Check if SMS permissions are granted
  Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }
}
