import 'dart:io';

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
      return true; // Not needed for Android < 13
    } else if (Platform.isIOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  Future<bool> checkNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 33) {
        return await Permission.notification.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      return await Permission.notification.isGranted;
    }
    return true;
  }

  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    results['storage'] = await requestStoragePermission();
    results['notification'] = await requestNotificationPermission();

    return results;
  }

  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  Future<PermissionStatus> getPermissionStatus(Permission permission) async {
    return await permission.status;
  }

  Future<bool> shouldShowRequestRationale(Permission permission) async {
    if (Platform.isAndroid) {
      return await permission.shouldShowRequestRationale;
    }
    return false;
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      // This is a simplified version. In production, you might want to use
      // platform channels or a plugin to get the exact Android version
      try {
        // Assume modern Android by default
        return 33;
      } catch (e) {
        return 33;
      }
    }
    return 0;
  }

  String getPermissionMessage(Permission permission, PermissionStatus status) {
    if (status.isDenied) {
      return 'Permission denied. Please grant ${_getPermissionName(permission)} permission to continue.';
    } else if (status.isPermanentlyDenied) {
      return 'Permission permanently denied. Please enable ${_getPermissionName(permission)} permission in app settings.';
    } else if (status.isRestricted) {
      return '${_getPermissionName(permission)} permission is restricted on this device.';
    }
    return '';
  }

  String _getPermissionName(Permission permission) {
    if (permission == Permission.storage ||
        permission == Permission.manageExternalStorage) {
      return 'storage';
    } else if (permission == Permission.notification) {
      return 'notification';
    } else if (permission == Permission.photos) {
      return 'photos';
    }
    return 'unknown';
  }
}
