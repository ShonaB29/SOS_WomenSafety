import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/logger.dart';

class PermissionService {
  static Future<bool> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.sms,
      Permission.phone,
      Permission.microphone,
      Permission.sensors,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      Logger.log('${permission.toString()}: $status');
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    return allGranted;
  }

  static Future<bool> checkLocationService() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // New method to check SMS permission
  static Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }
}
