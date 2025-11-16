import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/download_progress.dart';
import '../models/download_status.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Function(String, String)? _onNotificationAction;

  NotificationService._init();

  Future<void> initialize({
    Function(String, String)? onNotificationAction,
  }) async {
    if (_initialized) return;

    _onNotificationAction = onNotificationAction;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundNotificationResponse,
    );

    _initialized = true;
  }

  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) {
    // Handle background notification response
    if (response.payload != null) {
      final parts = response.payload!.split('|');
      if (parts.length >= 2) {
        final action = parts[0];
        final downloadId = parts[1];
        debugPrint('[meder:NotificationService]: action($action)');
        debugPrint('[meder:NotificationService]: downloadId($downloadId)');
        debugPrint(
          '[meder:NotificationService]: This will be handled by the download manager through WorkManager',
        );
        // This will be handled by the download manager through WorkManager
      }
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      final parts = response.payload!.split('|');
      if (parts.length >= 2) {
        final action = parts[0];
        final downloadId = parts[1];
        _onNotificationAction?.call(action, downloadId);
      }
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidImplementation
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> showDownloadProgress(
    DownloadProgress progress,
    String fileName,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Download progress notifications',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress.progress * 100).toInt(),
      ongoing: progress.status.isActive,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      actions: _getNotificationActions(progress.status),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = _getNotificationTitle(progress.status, fileName);
    final body = _getNotificationBody(progress);

    await _notifications.show(
      progress.downloadId.hashCode,
      title,
      body,
      details,
      payload: 'open|${progress.downloadId}',
    );
  }

  List<AndroidNotificationAction> _getNotificationActions(
    DownloadStatus status,
  ) {
    if (status == DownloadStatus.downloading) {
      return [
        const AndroidNotificationAction(
          'pause',
          'Pause',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          'cancel',
          'Cancel',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ];
    } else if (status == DownloadStatus.paused) {
      return [
        const AndroidNotificationAction(
          'resume',
          'Resume',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          'cancel',
          'Cancel',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ];
    }
    return [];
  }

  String _getNotificationTitle(DownloadStatus status, String fileName) {
    switch (status) {
      case DownloadStatus.downloading:
        return 'Downloading $fileName';
      case DownloadStatus.paused:
        return 'Download Paused';
      case DownloadStatus.completed:
        return 'Download Complete';
      case DownloadStatus.failed:
        return 'Download Failed';
      case DownloadStatus.cancelled:
        return 'Download Cancelled';
      case DownloadStatus.queued:
        return 'Download Queued';
    }
  }

  String _getNotificationBody(DownloadProgress progress) {
    if (progress.status == DownloadStatus.downloading) {
      return '${progress.downloadedFormatted} / ${progress.totalFormatted} • ${progress.speedFormatted}';
    } else if (progress.status == DownloadStatus.paused) {
      return '${progress.downloadedFormatted} / ${progress.totalFormatted}';
    } else if (progress.status == DownloadStatus.completed) {
      return 'File downloaded successfully';
    } else if (progress.status == DownloadStatus.failed) {
      return progress.error ?? 'Download failed';
    } else if (progress.status == DownloadStatus.cancelled) {
      return 'Download was cancelled';
    } else if (progress.status == DownloadStatus.queued) {
      return 'Waiting to start...';
    }
    return '';
  }

  Future<void> showCompletionNotification(
    String downloadId,
    String fileName,
    String? filePath,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'download_complete_channel',
      'Download Complete',
      channelDescription: 'Download completion notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      downloadId.hashCode,
      'Download Complete',
      fileName,
      details,
      payload: 'open|$downloadId',
    );
  }

  Future<void> showErrorNotification(
    String downloadId,
    String fileName,
    String error,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'download_error_channel',
      'Download Errors',
      channelDescription: 'Download error notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      downloadId.hashCode,
      'Download Failed',
      '$fileName: $error',
      details,
      payload: 'open|$downloadId',
    );
  }

  Future<void> cancelNotification(String downloadId) async {
    await _notifications.cancel(downloadId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
