import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../database/download_database.dart';
import '../models/download_config.dart';
import '../models/download_progress.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';
import '../services/background_service.dart';
import '../services/download_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../ui/app_lifecycle_observer.dart';
import '../utils/file_utils.dart';
import '../utils/network_utils.dart';

class DownloadManager with WidgetsBindingObserver {
  static DownloadManager? _instance;
  static DownloadManager get instance {
    _instance ??= DownloadManager._init();
    return _instance!;
  }

  final DownloadDatabase _database = DownloadDatabase.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final PermissionService _permissionService = PermissionService.instance;
  final BackgroundService _backgroundService = BackgroundService.instance;
  final NetworkUtils _networkUtils = NetworkUtils.instance;

  late DownloadService _downloadService;
  late DownloadConfig _config;

  final Queue<DownloadTask> _queue = Queue<DownloadTask>();
  final Map<String, DownloadTask> _activeDownloads = {};
  final Map<String, StreamController<DownloadProgress>> _progressControllers =
      {};

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _initialized = false;
  bool _isPaused = false;

  DownloadManager._init();

  Future<void> initialize(DownloadConfig config) async {
    if (_initialized) return;

    _config = config;
    _downloadService = DownloadService(_config);

    // Initialize services
    await _backgroundService.initialize();
    await _notificationService.initialize(
      onNotificationAction: _handleNotificationAction,
    );

    // Request permissions
    await _permissionService.requestAllPermissions();

    // Listen to app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Listen to network changes
    _connectivitySubscription = _networkUtils.connectivityStream.listen(
      _handleConnectivityChange,
    );

    // Resume incomplete downloads
    await _resumeIncompleteDownloads();

    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    AppLifecycleObserver.instance.onStateChanged(state);

    if (state == AppLifecycleState.paused) {
      // App going to background
      _handleAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground
      _handleAppForeground();
    }
  }

  Future<void> _handleAppBackground() async {
    // Register background tasks for active downloads
    for (final task in _activeDownloads.values) {
      if (task.status == DownloadStatus.downloading) {
        await _backgroundService.registerDownloadTask(task.id);
      }
    }
  }

  Future<void> _handleAppForeground() async {
    // Resume downloads that were active
    await _resumeIncompleteDownloads();
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      // Network lost - pause all downloads
      _pauseAllActiveDownloads();
    } else {
      // Network restored - resume downloads
      if (!_isPaused) {
        _processQueue();
      }
    }
  }

  void _handleNotificationAction(String action, String downloadId) {
    switch (action) {
      case 'pause':
        pause(downloadId);
        break;
      case 'resume':
        resume(downloadId);
        break;
      case 'cancel':
        cancel(downloadId);
        break;
    }
  }

  Future<String> enqueue({
    required String url,
    String? fileName,
    String? savePath,
    Map<String, String>? headers,
    Map<String, dynamic>? metadata,
    DownloadPriority priority = DownloadPriority.medium,
    bool requiresWifi = false,
    String? checksum,
  }) async {
    _ensureInitialized();

    // Generate unique ID
    final id = const Uuid().v4();

    // Determine file name
    final finalFileName =
        fileName ??
        FileUtils.sanitizeFileName(url.split('/').last.split('?').first);

    // Get file size and check resumability
    int? fileSize;
    try {
      fileSize = await _downloadService.getContentLength(url, headers: headers);
    } catch (e) {
      // Continue without file size
    }

    // Create download task
    final task = DownloadTask(
      id: id,
      url: url,
      fileName: finalFileName,
      filePath: savePath,
      fileSize: fileSize,
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

    // Save to database
    await _database.insert(task);

    // Add to queue
    _addToQueue(task);

    // Process queue
    _processQueue();

    return id;
  }

  void _addToQueue(DownloadTask task) {
    // Add based on priority
    if (task.priority == DownloadPriority.high) {
      // Add high priority tasks to the front
      final tempQueue = Queue<DownloadTask>();
      tempQueue.add(task);
      while (_queue.isNotEmpty) {
        tempQueue.add(_queue.removeFirst());
      }
      _queue.addAll(tempQueue);
    } else {
      _queue.add(task);
    }
  }

  Future<void> _processQueue() async {
    while (_activeDownloads.length < _config.maxConcurrentDownloads &&
        _queue.isNotEmpty) {
      final task = _queue.removeFirst();

      // Check network conditions
      if (task.requiresWifi) {
        final isWifi = await _networkUtils.isWifiConnected();
        if (!isWifi) {
          // Re-add to queue and wait
          _queue.addFirst(task);
          break;
        }
      }

      final isConnected = await _networkUtils.isConnected();
      if (!isConnected) {
        _queue.addFirst(task);
        break;
      }

      await _startDownload(task);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    _activeDownloads[task.id] = task;

    // Update status
    await _database.updateStatus(task.id, DownloadStatus.downloading);

    // Create progress controller
    final progressController = StreamController<DownloadProgress>.broadcast();
    _progressControllers[task.id] = progressController;

    // Start download
    _downloadService.startDownload(
      task,
      (progress) async {
        // Update database
        await _database.updateProgress(task.id, progress.downloadedBytes);

        // Update notification
        if (_config.showNotifications) {
          await _notificationService.showDownloadProgress(
            progress,
            task.fileName,
          );
        }

        // Emit progress
        progressController.add(progress);
      },
      (completedTask) async {
        // Update database
        await _database.update(completedTask);

        // Show completion notification
        if (_config.showNotifications) {
          await _notificationService.showCompletionNotification(
            completedTask.id,
            completedTask.fileName,
            completedTask.filePath,
          );
        }

        // Cleanup
        _activeDownloads.remove(task.id);
        _progressControllers[task.id]?.close();
        _progressControllers.remove(task.id);

        // Cancel background task
        await _backgroundService.cancelDownloadTask(task.id);

        // Process next in queue
        if (_config.autoStartNextDownload) {
          _processQueue();
        }
      },
      (error) async {
        // Check if should retry
        final currentTask = await _database.getById(task.id);
        if (currentTask != null &&
            currentTask.retryCount < _config.maxRetries) {
          // Increment retry count
          await _database.incrementRetryCount(task.id);

          // Re-add to queue
          final updatedTask = currentTask.copyWith(
            status: DownloadStatus.queued,
            error: error,
          );
          await _database.update(updatedTask);
          _addToQueue(updatedTask);
        } else {
          // Mark as failed
          await _database.updateStatus(
            task.id,
            DownloadStatus.failed,
            error: error,
          );

          // Show error notification
          if (_config.showNotifications) {
            await _notificationService.showErrorNotification(
              task.id,
              task.fileName,
              error,
            );
          }

          // Emit error progress
          final errorProgress = DownloadProgress(
            downloadId: task.id,
            downloadedBytes: task.downloadedBytes,
            totalBytes: task.fileSize ?? 0,
            progress: task.progress,
            speedBytesPerSecond: 0,
            status: DownloadStatus.failed,
            error: error,
          );
          _progressControllers[task.id]?.add(errorProgress);
        }

        // Cleanup
        _activeDownloads.remove(task.id);
        _progressControllers[task.id]?.close();
        _progressControllers.remove(task.id);

        // Process next in queue
        _processQueue();
      },
    );
  }

  Future<void> pause(String downloadId) async {
    _ensureInitialized();

    // Remove from queue if present
    _queue.removeWhere((task) => task.id == downloadId);

    // Pause active download
    if (_activeDownloads.containsKey(downloadId)) {
      await _downloadService.pauseDownload(downloadId);
      _activeDownloads.remove(downloadId);
    }

    // Update database
    await _database.updateStatus(downloadId, DownloadStatus.paused);

    // Cancel notification
    await _notificationService.cancelNotification(downloadId);

    // Cancel background task
    await _backgroundService.cancelDownloadTask(downloadId);
  }

  Future<void> resume(String downloadId) async {
    _ensureInitialized();

    final task = await _database.getById(downloadId);
    if (task == null) return;

    // Update status to queued
    final updatedTask = task.copyWith(
      status: DownloadStatus.queued,
      updatedAt: DateTime.now(),
    );
    await _database.update(updatedTask);

    // Add to queue
    _addToQueue(updatedTask);

    // Process queue
    _processQueue();
  }

  Future<void> cancel(String downloadId) async {
    _ensureInitialized();

    // Remove from queue
    _queue.removeWhere((task) => task.id == downloadId);

    // Cancel active download
    if (_activeDownloads.containsKey(downloadId)) {
      await _downloadService.cancelDownload(downloadId);
      _activeDownloads.remove(downloadId);
    }

    // Get task to delete file
    final task = await _database.getById(downloadId);
    if (task?.filePath != null) {
      try {
        await FileUtils.deleteFile(task!.filePath!);
      } catch (e) {
        // Ignore file deletion errors
      }
    }

    // Update database
    await _database.updateStatus(downloadId, DownloadStatus.cancelled);

    // Cancel notification
    await _notificationService.cancelNotification(downloadId);

    // Cancel background task
    await _backgroundService.cancelDownloadTask(downloadId);

    // Process next in queue
    _processQueue();
  }

  Future<void> retry(String downloadId) async {
    _ensureInitialized();

    final task = await _database.getById(downloadId);
    if (task == null) return;

    // Reset task
    final resetTask = task.copyWith(
      status: DownloadStatus.queued,
      downloadedBytes: 0,
      error: null,
      retryCount: 0,
      updatedAt: DateTime.now(),
    );

    await _database.update(resetTask);

    // Delete partial file if exists
    if (task.filePath != null) {
      try {
        await FileUtils.deleteFile(task.filePath!);
      } catch (e) {
        // Ignore
      }
    }

    // Add to queue
    _addToQueue(resetTask);

    // Process queue
    _processQueue();
  }

  Future<void> pauseAll() async {
    _ensureInitialized();
    _isPaused = true;

    final activeIds = _activeDownloads.keys.toList();
    for (final id in activeIds) {
      await pause(id);
    }
  }

  Future<void> resumeAll() async {
    _ensureInitialized();
    _isPaused = false;

    final pausedTasks = await _database.getByStatus(DownloadStatus.paused);
    for (final task in pausedTasks) {
      await resume(task.id);
    }
  }

  Future<void> cancelAll() async {
    _ensureInitialized();

    final activeIds = _activeDownloads.keys.toList();
    for (final id in activeIds) {
      await cancel(id);
    }

    _queue.clear();
  }

  void _pauseAllActiveDownloads() {
    final activeIds = _activeDownloads.keys.toList();
    for (final id in activeIds) {
      pause(id);
    }
  }

  Future<void> _resumeIncompleteDownloads() async {
    final incompleteTasks = await _database.getIncompleteDownloads();

    for (final task in incompleteTasks) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.queued) {
        _addToQueue(task);
      }
    }

    _processQueue();
  }

  Future<DownloadTask?> getDownload(String downloadId) async {
    _ensureInitialized();
    return await _database.getById(downloadId);
  }

  Future<List<DownloadTask>> getAllDownloads() async {
    _ensureInitialized();
    return await _database.getAll();
  }

  Future<List<DownloadTask>> getDownloadsByStatus(DownloadStatus status) async {
    _ensureInitialized();
    return await _database.getByStatus(status);
  }

  Stream<DownloadProgress>? getProgressStream(String downloadId) {
    return _progressControllers[downloadId]?.stream;
  }

  Future<String?> getFilePath(String downloadId) async {
    _ensureInitialized();
    final task = await _database.getById(downloadId);
    return task?.filePath;
  }

  Future<void> clearCompleted() async {
    _ensureInitialized();

    final completed = await _database.getByStatus(DownloadStatus.completed);
    for (final task in completed) {
      await _notificationService.cancelNotification(task.id);
    }

    await _database.deleteCompleted();
  }

  Future<void> delete(String downloadId) async {
    _ensureInitialized();

    await cancel(downloadId);
    await _database.delete(downloadId);
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'DownloadManager not initialized. Call initialize() first.',
      );
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _downloadService.dispose();

    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
  }
}
