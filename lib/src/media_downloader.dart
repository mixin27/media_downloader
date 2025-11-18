import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'models/download_config.dart';
import 'models/download_task.dart';
import 'models/download_status.dart';
import 'models/download_progress.dart';
import 'utils/file_utils.dart';
import 'utils/network_utils.dart';
import 'services/permission_service.dart';

class MediaDownloader {
  static MediaDownloader? _instance;
  static MediaDownloader get instance {
    _instance ??= MediaDownloader._init();
    return _instance!;
  }

  MediaDownloader._init();

  final PermissionService _permissionService = PermissionService.instance;
  final NetworkUtils _networkUtils = NetworkUtils.instance;
  final Connectivity _connectivity = Connectivity();

  late DownloadConfig _config;
  bool _initialized = false;

  // Track our downloads with metadata
  final Map<String, MediaDownloadTask> _downloadTasks = {};
  final Map<String, StreamController<DownloadProgress>> _progressControllers =
      {};

  // Port for receiving updates from flutter_downloader
  final ReceivePort _port = ReceivePort();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Initialize the downloader with configuration
  Future<void> initialize([DownloadConfig? config]) async {
    if (_initialized) return;

    _config = config ?? const DownloadConfig();

    // Initialize flutter_downloader
    await FlutterDownloader.initialize(
      debug: kDebugMode,
      ignoreSsl: kReleaseMode,
    );

    // Register callback port
    IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );

    // Listen to download updates
    _port.listen(_handleDownloadUpdate);

    // Register callback
    FlutterDownloader.registerCallback(downloadCallback);

    // Request permissions
    await _permissionService.requestAllPermissions();

    // Listen to network changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    _initialized = true;
  }

  /// Callback for flutter_downloader
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(
      'downloader_send_port',
    );
    send?.send([id, status, progress]);
  }

  void _handleDownloadUpdate(dynamic data) {
    final String id = data[0];
    final int status = data[1];
    final int progress = data[2];

    final task = _downloadTasks[id];
    if (task == null) return;

    // Convert flutter_downloader status to our status
    final downloadStatus = _convertStatus(DownloadTaskStatus.values[status]);

    // Calculate progress
    final downloadedBytes = task.fileSize != null
        ? (task.fileSize! * progress / 100).round()
        : 0;

    final progressData = DownloadProgress(
      downloadId: id,
      downloadedBytes: downloadedBytes,
      totalBytes: task.fileSize ?? 0,
      progress: progress / 100,
      speedBytesPerSecond: 0, // flutter_downloader doesn't provide speed
      status: downloadStatus,
    );

    // Update task status
    _downloadTasks[id] = task.copyWith(
      status: downloadStatus,
      downloadedBytes: downloadedBytes,
      updatedAt: DateTime.now(),
    );

    // Emit progress
    if (_progressControllers.containsKey(id)) {
      _progressControllers[id]?.add(progressData);
    }

    // Handle completion
    if (downloadStatus == DownloadStatus.completed) {
      _handleDownloadComplete(id);
    } else if (downloadStatus == DownloadStatus.failed) {
      _handleDownloadFailed(id);
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.isEmpty || results.first == ConnectivityResult.none) {
      // Network lost - pause WiFi-required downloads
      _pauseWifiRequiredDownloads();
    } else {
      // Network restored - resume if not manually paused
      _resumeWifiDownloads();
    }
  }

  void _pauseWifiRequiredDownloads() {
    for (final task in _downloadTasks.values) {
      if (task.requiresWifi && task.status == DownloadStatus.downloading) {
        pause(task.id);
      }
    }
  }

  void _resumeWifiDownloads() async {
    final isWifi = await _networkUtils.isWifiConnected();
    if (!isWifi) return;

    for (final task in _downloadTasks.values) {
      if (task.requiresWifi && task.status == DownloadStatus.paused) {
        resume(task.id);
      }
    }
  }

  void _handleDownloadComplete(String id) async {
    final task = _downloadTasks[id];
    if (task == null) return;

    // Verify checksum if provided
    if (_config.verifyChecksum &&
        task.checksum != null &&
        task.filePath != null) {
      try {
        final isValid = await FileUtils.verifyChecksum(
          task.filePath!,
          task.checksum!,
        );
        if (!isValid) {
          await cancel(id);
          _downloadTasks[id] = task.copyWith(
            status: DownloadStatus.failed,
            error: 'Checksum verification failed',
          );
          return;
        }
      } catch (e) {
        debugPrint('Checksum verification error: $e');
      }
    }

    // Close progress controller
    await _progressControllers[id]?.close();
    _progressControllers.remove(id);
  }

  void _handleDownloadFailed(String id) async {
    final task = _downloadTasks[id];
    if (task == null) return;

    // Check if should retry
    if (task.retryCount < _config.maxRetries) {
      await Future.delayed(const Duration(seconds: 2));
      await retry(id);
    } else {
      // Close progress controller
      await _progressControllers[id]?.close();
      _progressControllers.remove(id);
    }
  }

  /// Download a file
  /// Returns the download ID
  Future<String> download({
    required String url,
    String? fileName,
    String? savePath,
    Map<String, String>? headers,
    Map<String, dynamic>? metadata,
    DownloadPriority priority = DownloadPriority.medium,
    bool requiresWifi = false,
    String? checksum,
    bool useUniqueFileName = true,
    bool showNotification = true,
    bool openFileFromNotification = true,
  }) async {
    _ensureInitialized();

    // Check network conditions
    if (requiresWifi) {
      final isWifi = await _networkUtils.isWifiConnected();
      if (!isWifi) {
        throw Exception('WiFi connection required for this download');
      }
    }

    final isConnected = await _networkUtils.isConnected();
    if (!isConnected) {
      throw Exception('No internet connection');
    }

    // Generate unique ID
    // final id = const Uuid().v4();

    // Determine file name
    String finalFileName;
    if (fileName != null) {
      finalFileName = FileUtils.sanitizeFileName(fileName);
      if (useUniqueFileName) {
        finalFileName = FileUtils.generateUniqueFileName(finalFileName);
      }
    } else {
      finalFileName = FileUtils.sanitizeFileName(
        url.split('/').last.split('?').first,
      );
      if (useUniqueFileName) {
        finalFileName = FileUtils.generateUniqueFileName(finalFileName);
      }
    }

    // Determine save path
    String finalSavePath;
    if (savePath != null) {
      finalSavePath = savePath;
    } else {
      finalSavePath = await FileUtils.getStoragePath(
        _config.defaultStorageLocation,
        customPath: _config.customStoragePath,
      );
    }

    // Ensure directory exists
    await FileUtils.ensureDirectoryExists(finalSavePath);

    // Start download with flutter_downloader
    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: finalSavePath,
      fileName: finalFileName,
      headers: headers ?? {},
      showNotification: showNotification && _config.showNotifications,
      openFileFromNotification: openFileFromNotification,
      requiresStorageNotLow: true,
      saveInPublicStorage:
          _config.defaultStorageLocation == StorageLocation.downloads,
    );

    if (taskId == null) {
      throw Exception('Failed to enqueue download');
    }

    // Create our task wrapper
    final task = MediaDownloadTask(
      id: taskId,
      url: url,
      fileName: finalFileName,
      filePath: FileUtils.joinPath(finalSavePath, finalFileName),
      status: DownloadStatus.queued,
      mimeType: FileUtils.getMimeType(finalFileName),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: metadata,
      headers: headers,
      priority: priority,
      requiresWifi: requiresWifi,
      checksum: checksum,
    );

    _downloadTasks[taskId] = task;

    // Create progress controller
    _progressControllers[taskId] =
        StreamController<DownloadProgress>.broadcast();

    return taskId;
  }

  /// Pause a download
  Future<void> pause(String downloadId) async {
    _ensureInitialized();
    await FlutterDownloader.pause(taskId: downloadId);

    final task = _downloadTasks[downloadId];
    if (task != null) {
      _downloadTasks[downloadId] = task.copyWith(
        status: DownloadStatus.paused,
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Resume a paused download
  Future<String?> resume(String downloadId) async {
    _ensureInitialized();

    final task = _downloadTasks[downloadId];
    if (task == null) return null;

    // Check WiFi requirement
    if (task.requiresWifi) {
      final isWifi = await _networkUtils.isWifiConnected();
      if (!isWifi) {
        throw Exception('WiFi connection required for this download');
      }
    }

    final newTaskId = await FlutterDownloader.resume(taskId: downloadId);

    if (newTaskId != null) {
      // Update task with new ID
      _downloadTasks.remove(downloadId);
      _downloadTasks[newTaskId] = task.copyWith(
        id: newTaskId,
        status: DownloadStatus.downloading,
        updatedAt: DateTime.now(),
      );

      // Move progress controller
      final controller = _progressControllers.remove(downloadId);
      if (controller != null) {
        _progressControllers[newTaskId] = controller;
      }

      return newTaskId;
    }

    return null;
  }

  /// Cancel a download
  Future<void> cancel(String downloadId) async {
    _ensureInitialized();
    await FlutterDownloader.cancel(taskId: downloadId);

    final task = _downloadTasks[downloadId];
    if (task != null) {
      _downloadTasks[downloadId] = task.copyWith(
        status: DownloadStatus.cancelled,
        updatedAt: DateTime.now(),
      );

      // Delete partial file
      if (task.filePath != null) {
        try {
          await FileUtils.deleteFile(task.filePath!);
        } catch (e) {
          debugPrint('Error deleting file: $e');
        }
      }
    }

    // Close progress controller
    await _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
  }

  /// Retry a failed or cancelled download
  Future<String?> retry(String downloadId) async {
    _ensureInitialized();

    final task = _downloadTasks[downloadId];
    if (task == null) return null;

    final newTaskId = await FlutterDownloader.retry(taskId: downloadId);

    if (newTaskId != null) {
      // Update task
      _downloadTasks.remove(downloadId);
      _downloadTasks[newTaskId] = task.copyWith(
        id: newTaskId,
        status: DownloadStatus.downloading,
        retryCount: task.retryCount + 1,
        updatedAt: DateTime.now(),
      );

      // Move progress controller
      final controller = _progressControllers.remove(downloadId);
      if (controller != null) {
        _progressControllers[newTaskId] = controller;
      }

      return newTaskId;
    }

    return null;
  }

  /// Pause all active downloads
  Future<void> pauseAll() async {
    _ensureInitialized();

    for (final task in _downloadTasks.values) {
      if (task.status == DownloadStatus.downloading) {
        await pause(task.id);

        _downloadTasks[task.id] = task.copyWith(
          status: DownloadStatus.paused,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  /// Resume all paused downloads
  Future<void> resumeAll() async {
    _ensureInitialized();

    for (final task in _downloadTasks.values) {
      if (task.status == DownloadStatus.paused) {
        await resume(task.id);
      }
    }
  }

  /// Cancel all downloads
  Future<void> cancelAll() async {
    _ensureInitialized();
    await FlutterDownloader.cancelAll();

    for (final task in _downloadTasks.values) {
      _downloadTasks[task.id] = task.copyWith(
        status: DownloadStatus.cancelled,
        updatedAt: DateTime.now(),
      );

      // Close progress controller
      await _progressControllers[task.id]?.close();
      _progressControllers.remove(task.id);
    }
  }

  /// Get a download task by ID
  Future<MediaDownloadTask?> getDownload(String downloadId) async {
    _ensureInitialized();

    // First check our cache
    if (_downloadTasks.containsKey(downloadId)) {
      return _downloadTasks[downloadId];
    }

    // Query flutter_downloader
    final tasks = await FlutterDownloader.loadTasksWithRawQuery(
      query: "SELECT * FROM task WHERE task_id='$downloadId'",
    );

    if (tasks == null || tasks.isEmpty) return null;

    // Convert to our task
    return _convertToMediaTask(tasks.first);
  }

  /// Get all downloads
  Future<List<MediaDownloadTask>> getAllDownloads() async {
    _ensureInitialized();

    final tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) return [];

    return tasks.map((task) => _convertToMediaTask(task)).toList();
  }

  /// Get downloads by status
  Future<List<MediaDownloadTask>> getDownloadsByStatus(
    DownloadStatus status,
  ) async {
    _ensureInitialized();

    final tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) return [];

    return tasks
        .where((task) => _convertStatus(task.status) == status)
        .map((task) => _convertToMediaTask(task))
        .toList();
  }

  /// Get progress stream for a download
  Stream<DownloadProgress>? getProgressStream(String downloadId) {
    return _progressControllers[downloadId]?.stream;
  }

  /// Get the file path of a downloaded file
  Future<String?> getFilePath(String downloadId) async {
    _ensureInitialized();
    final task = await getDownload(downloadId);
    return task?.filePath;
  }

  /// Remove a download task from the database
  Future<void> remove(String downloadId) async {
    _ensureInitialized();
    await FlutterDownloader.remove(
      taskId: downloadId,
      shouldDeleteContent: false,
    );
    _downloadTasks.remove(downloadId);
  }

  /// Delete a download and its file
  Future<void> delete(String downloadId) async {
    _ensureInitialized();

    final task = _downloadTasks[downloadId];
    if (task?.filePath != null) {
      try {
        await FileUtils.deleteFile(task!.filePath!);
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
    }

    await FlutterDownloader.remove(
      taskId: downloadId,
      shouldDeleteContent: true,
    );

    _downloadTasks.remove(downloadId);

    await _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
  }

  /// Open a downloaded file
  Future<bool> open(String downloadId) async {
    _ensureInitialized();
    return await FlutterDownloader.open(taskId: downloadId);
  }

  /// Helper methods

  MediaDownloadTask _convertToMediaTask(DownloadTask task) {
    final cachedTask = _downloadTasks[task.taskId];

    return MediaDownloadTask(
      id: task.taskId,
      url: task.url,
      fileName: task.filename ?? '',
      filePath: task.filename != null
          ? FileUtils.joinPath(task.savedDir, task.filename!)
          : null,
      fileSize: null,
      downloadedBytes: task.progress,
      status: _convertStatus(task.status),
      mimeType: cachedTask?.mimeType,
      createdAt: cachedTask?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: cachedTask?.metadata,
      headers: cachedTask?.headers,
      priority: cachedTask?.priority ?? DownloadPriority.medium,
      requiresWifi: cachedTask?.requiresWifi ?? false,
      checksum: cachedTask?.checksum,
      retryCount: cachedTask?.retryCount ?? 0,
    );
  }

  DownloadStatus _convertStatus(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.undefined:
        return DownloadStatus.queued;
      case DownloadTaskStatus.enqueued:
        return DownloadStatus.queued;
      case DownloadTaskStatus.running:
        return DownloadStatus.downloading;
      case DownloadTaskStatus.complete:
        return DownloadStatus.completed;
      case DownloadTaskStatus.failed:
        return DownloadStatus.failed;
      case DownloadTaskStatus.canceled:
        return DownloadStatus.cancelled;
      case DownloadTaskStatus.paused:
        return DownloadStatus.paused;
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'MediaDownloader not initialized. Call initialize() first.',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();

    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _downloadTasks.clear();

    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _port.close();
  }
}
