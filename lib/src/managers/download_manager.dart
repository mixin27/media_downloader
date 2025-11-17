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
  final Map<String, Timer?> _dbUpdateTimers = {};
  final Map<String, int> _pendingProgressUpdates = {};
  final Map<String, DateTime> _lastNotificationUpdate = {};

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _batchUpdateTimer;
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

    // Start batch update timer (updates database every 2 seconds)
    _batchUpdateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _performBatchDatabaseUpdate(),
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
    debugPrint(
      'Handling notification action: $action for download: $downloadId',
    );

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
      case 'open':
        // User tapped notification, could open app or show download
        debugPrint('Open notification tapped for: $downloadId');
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
    bool useUniqueFileName = true,
  }) async {
    _ensureInitialized();

    // Generate unique ID
    final id = const Uuid().v4();

    // Determine file name
    String finalFileName;
    if (fileName != null) {
      finalFileName = FileUtils.sanitizeFileName(fileName);
      // Generate unique filename to avoid conflicts
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
        // Store progress for batch update instead of immediate database write
        _pendingProgressUpdates[task.id] = progress.downloadedBytes;

        // Update notification (throttled to once per second)
        if (_config.showNotifications) {
          final now = DateTime.now();
          final lastUpdate = _lastNotificationUpdate[task.id];

          if (lastUpdate == null ||
              now.difference(lastUpdate).inMilliseconds >= 1000) {
            _lastNotificationUpdate[task.id] = now;

            try {
              await _notificationService.showDownloadProgress(
                progress,
                task.fileName,
              );
            } catch (e) {
              debugPrint('Notification error: $e');
            }
          }
        }

        // Emit progress - check if controller is still open
        if (!progressController.isClosed) {
          progressController.add(progress);
        }
      },
      (completedTask) async {
        // Cleanup notification tracking
        _lastNotificationUpdate.remove(task.id);

        // Cleanup progress controller first
        if (_progressControllers.containsKey(task.id)) {
          await _progressControllers[task.id]?.close();
          _progressControllers.remove(task.id);
        }

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

        // Remove from active downloads
        _activeDownloads.remove(task.id);

        // Cancel background task
        await _backgroundService.cancelDownloadTask(task.id);

        // Process next in queue
        if (_config.autoStartNextDownload) {
          _processQueue();
        }
      },
      (error) async {
        // Cleanup notification tracking
        _lastNotificationUpdate.remove(task.id);

        // Cleanup progress controller first
        if (_progressControllers.containsKey(task.id)) {
          // Emit error progress before closing
          final errorProgress = DownloadProgress(
            downloadId: task.id,
            downloadedBytes: task.downloadedBytes,
            totalBytes: task.fileSize ?? 0,
            progress: task.progress,
            speedBytesPerSecond: 0,
            status: DownloadStatus.failed,
            error: error,
          );

          if (!_progressControllers[task.id]!.isClosed) {
            _progressControllers[task.id]!.add(errorProgress);
          }

          await _progressControllers[task.id]?.close();
          _progressControllers.remove(task.id);
        }

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
        }

        // Remove from active downloads
        _activeDownloads.remove(task.id);

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

  Future<void> _performBatchDatabaseUpdate() async {
    if (_pendingProgressUpdates.isEmpty) return;

    // Copy and clear pending updates
    final updates = Map<String, int>.from(_pendingProgressUpdates);
    _pendingProgressUpdates.clear();

    // Perform batch update
    try {
      await _database.batchUpdateProgress(updates);
    } catch (e) {
      // Ignore database errors
      debugPrint('Batch update error: $e');
    }
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
    _batchUpdateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _downloadService.dispose();

    // Cancel all timers
    for (final timer in _dbUpdateTimers.values) {
      timer?.cancel();
    }
    _dbUpdateTimers.clear();

    // Close all controllers
    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _progressControllers.clear();
    _pendingProgressUpdates.clear();
    _lastNotificationUpdate.clear();
  }
}
