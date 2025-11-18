import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._init();

  PermissionService._init();

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();

      if (androidVersion >= 33) {
        // Android 13+ - Request specific permissions
        final status = await Permission.photos.request();
        return status.isGranted;
      } else if (androidVersion >= 30) {
        // Android 11, 12 - Use MANAGE_EXTERNAL_STORAGE for broad access
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) return true;

        // Fallback to storage permission
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      } else {
        // Android 10 and below
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      // iOS doesn't require storage permission for app directories
      return true;
    }
    return true;
  }

  Future<bool> checkStoragePermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();

      if (androidVersion >= 33) {
        return await Permission.photos.isGranted;
      } else if (androidVersion >= 30) {
        final manageStorage = await Permission.manageExternalStorage.isGranted;
        if (manageStorage) return true;
        return await Permission.storage.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return true;
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 33) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};
    results['storage'] = await requestStoragePermission();
    results['notification'] = await requestNotificationPermission();
    return results;
  }

  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.version.sdkInt;
      } catch (e) {
        return 33;
      }
    }
    return 0;
  }
}
