library;

// Models
export 'src/models/download_task.dart';
export 'src/models/download_status.dart';
export 'src/models/download_progress.dart';
export 'src/models/download_config.dart';

// Services
export 'src/services/background_service.dart';
export 'src/services/download_service.dart';
export 'src/services/notification_service.dart';
export 'src/services/permission_service.dart';

// Managers
export 'src/managers/download_manager.dart';

// UI
export 'src/ui/app_lifecycle_observer.dart';

import 'media_downloader.dart';

class MediaDownloader {
  static final DownloadManager _manager = DownloadManager.instance;

  /// Initialize the downloader with configuration
  static Future<void> initialize([DownloadConfig? config]) async {
    await _manager.initialize(config ?? const DownloadConfig());
  }

  /// Download a file
  /// Returns the download ID
  static Future<String> download({
    required String url,
    String? fileName,
    String? savePath,
    Map<String, String>? headers,
    Map<String, dynamic>? metadata,
    DownloadPriority priority = DownloadPriority.medium,
    bool requiresWifi = false,
    String? checksum,
  }) async {
    return await _manager.enqueue(
      url: url,
      fileName: fileName,
      savePath: savePath,
      headers: headers,
      metadata: metadata,
      priority: priority,
      requiresWifi: requiresWifi,
      checksum: checksum,
    );
  }

  /// Pause a download
  static Future<void> pause(String downloadId) async {
    await _manager.pause(downloadId);
  }

  /// Resume a paused download
  static Future<void> resume(String downloadId) async {
    await _manager.resume(downloadId);
  }

  /// Cancel a download
  static Future<void> cancel(String downloadId) async {
    await _manager.cancel(downloadId);
  }

  /// Retry a failed or cancelled download
  static Future<void> retry(String downloadId) async {
    await _manager.retry(downloadId);
  }

  /// Pause all active downloads
  static Future<void> pauseAll() async {
    await _manager.pauseAll();
  }

  /// Resume all paused downloads
  static Future<void> resumeAll() async {
    await _manager.resumeAll();
  }

  /// Cancel all downloads
  static Future<void> cancelAll() async {
    await _manager.cancelAll();
  }

  /// Get a download task by ID
  static Future<DownloadTask?> getDownload(String downloadId) async {
    return await _manager.getDownload(downloadId);
  }

  /// Get all downloads
  static Future<List<DownloadTask>> getAllDownloads() async {
    return await _manager.getAllDownloads();
  }

  /// Get downloads by status
  static Future<List<DownloadTask>> getDownloadsByStatus(
    DownloadStatus status,
  ) async {
    return await _manager.getDownloadsByStatus(status);
  }

  /// Get progress stream for a download
  static Stream<DownloadProgress>? getProgressStream(String downloadId) {
    return _manager.getProgressStream(downloadId);
  }

  /// Get the file path of a downloaded file
  static Future<String?> getFilePath(String downloadId) async {
    return await _manager.getFilePath(downloadId);
  }

  /// Clear all completed downloads from database
  static Future<void> clearCompleted() async {
    await _manager.clearCompleted();
  }

  /// Delete a download and its file
  static Future<void> delete(String downloadId) async {
    await _manager.delete(downloadId);
  }
}
