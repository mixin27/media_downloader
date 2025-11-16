import 'dart:async';

import 'package:workmanager/workmanager.dart';

import '../database/download_database.dart';
import '../models/download_status.dart';

const String downloadTaskName = 'media_downloader_task';
const String downloadTaskTag = 'media_download';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == downloadTaskName) {
        final downloadId = inputData?['downloadId'] as String?;
        if (downloadId == null) return Future.value(true);

        // Get download task from database
        final db = DownloadDatabase.instance;
        final downloadTask = await db.getById(downloadId);

        if (downloadTask == null) {
          return Future.value(true);
        }

        // Check if task should continue
        if (downloadTask.status == DownloadStatus.cancelled ||
            downloadTask.status == DownloadStatus.completed) {
          return Future.value(true);
        }

        // Update status to indicate background processing
        await db.updateStatus(downloadId, DownloadStatus.downloading);

        // Signal that the download should be picked up by the foreground service
        // when the app comes back to foreground
        return Future.value(true);
      }
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

class BackgroundService {
  static final BackgroundService instance = BackgroundService._init();
  bool _initialized = false;
  final Set<String> _registeredTasks = {};

  BackgroundService._init();

  Future<void> initialize() async {
    if (_initialized) return;

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    _initialized = true;
  }

  Future<void> registerDownloadTask(String downloadId) async {
    if (!_initialized) {
      await initialize();
    }

    if (_registeredTasks.contains(downloadId)) {
      return;
    }

    // Register a periodic task that checks download status
    await Workmanager().registerPeriodicTask(
      downloadId,
      downloadTaskName,
      frequency: const Duration(minutes: 15), // Minimum allowed by WorkManager
      inputData: {'downloadId': downloadId},
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 10),
      tag: downloadTaskTag,
    );

    _registeredTasks.add(downloadId);
  }

  Future<void> registerOneTimeTask(String downloadId) async {
    if (!_initialized) {
      await initialize();
    }

    await Workmanager().registerOneOffTask(
      downloadId,
      downloadTaskName,
      inputData: {'downloadId': downloadId},
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 10),
      tag: downloadTaskTag,
    );
  }

  Future<void> cancelDownloadTask(String downloadId) async {
    await Workmanager().cancelByUniqueName(downloadId);
    _registeredTasks.remove(downloadId);
  }

  Future<void> cancelAllTasks() async {
    await Workmanager().cancelByTag(downloadTaskTag);
    _registeredTasks.clear();
  }

  Future<void> resumeIncompleteDownloads() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final db = DownloadDatabase.instance;
      final incompleteDownloads = await db.getIncompleteDownloads();

      for (final download in incompleteDownloads) {
        if (download.status != DownloadStatus.completed &&
            download.status != DownloadStatus.cancelled) {
          await registerDownloadTask(download.id);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }
}
