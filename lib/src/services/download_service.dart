import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/download_config.dart';
import '../models/download_progress.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';
import '../utils/file_utils.dart';
import '../utils/network_utils.dart';

class DownloadService {
  final Dio _dio;
  final DownloadConfig _config;
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, SpeedCalculator> _speedCalculators = {};
  final Map<String, StreamController<DownloadProgress>> _progressControllers =
      {};

  DownloadService(this._config) : _dio = Dio() {
    _dio.options = BaseOptions(
      connectTimeout: _config.connectionTimeout,
      receiveTimeout: _config.receiveTimeout,
      sendTimeout: _config.connectionTimeout,
    );
  }

  Future<void> startDownload(
    DownloadTask task,
    Function(DownloadProgress) onProgress,
    Function(DownloadTask) onComplete,
    Function(String error) onError,
  ) async {
    RandomAccessFile? raf;

    try {
      // Check network conditions
      if (task.requiresWifi) {
        final isWifi = await NetworkUtils.instance.isWifiConnected();
        if (!isWifi) {
          onError('WiFi connection required for this download');
          return;
        }
      }

      final isConnected = await NetworkUtils.instance.isConnected();
      if (!isConnected) {
        onError('No internet connection');
        return;
      }

      // Prepare file path
      final filePath =
          task.filePath ?? await _getDefaultFilePath(task.fileName);
      final file = File(filePath);

      // Ensure directory exists
      await file.parent.create(recursive: true);

      // Initialize speed calculator and progress controller
      final speedCalculator = SpeedCalculator();
      _speedCalculators[task.id] = speedCalculator;
      speedCalculator.start();

      _progressControllers[task.id] =
          StreamController<DownloadProgress>.broadcast();

      // Create cancel token
      final cancelToken = CancelToken();
      _cancelTokens[task.id] = cancelToken;

      // Prepare download options
      final options = Options(
        headers: task.headers ?? {},
        receiveTimeout: _config.receiveTimeout,
        sendTimeout: _config.connectionTimeout,
        responseType: ResponseType.stream, // Important: stream response
      );

      // Check if resumable
      int startByte = 0;

      if (task.isResumable && await file.exists()) {
        final existingSize = await file.length();
        if (existingSize > 0 && existingSize < (task.fileSize ?? 0)) {
          startByte = existingSize;
          raf = await file.open(mode: FileMode.append);
          options.headers!['Range'] = 'bytes=$startByte-';
          debugPrint('Resuming download from byte: $startByte');
        } else {
          // File exists but not resumable, start fresh
          raf = await file.open(mode: FileMode.write);
        }
      } else {
        raf = await file.open(mode: FileMode.write);
      }

      debugPrint('Starting download: ${task.url}');
      debugPrint('File path: $filePath');
      debugPrint('Start byte: $startByte');

      // Start download with stream response
      final response = await _dio.get<ResponseBody>(
        task.url,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final totalBytes = total != -1 ? total : task.fileSize ?? 0;
          final currentBytes = startByte + received;
          final speed = speedCalculator.calculateSpeed(currentBytes);
          final estimatedTime = speedCalculator.estimateTimeRemaining(
            currentBytes,
            totalBytes,
            speed,
          );

          final progress = DownloadProgress(
            downloadId: task.id,
            downloadedBytes: currentBytes,
            totalBytes: totalBytes,
            progress: totalBytes > 0 ? currentBytes / totalBytes : 0,
            speedBytesPerSecond: speed,
            estimatedTimeRemaining: estimatedTime,
            status: DownloadStatus.downloading,
          );

          onProgress(progress);
          _progressControllers[task.id]?.add(progress);
        },
      );

      // Write response to file
      final stream = response.data?.stream;
      if (stream == null) {
        await raf.close();
        throw Exception('Failed to get response stream');
      }

      debugPrint('Writing to file...');

      // Write with buffer to handle large files
      await for (final data in stream) {
        if (cancelToken.isCancelled) {
          await raf.close();
          debugPrint('Download cancelled by user');
          return;
        }

        try {
          await raf.writeFrom(data);
          await raf.flush(); // Ensure data is written to disk
        } catch (e) {
          await raf.close();
          throw Exception('Failed to write to file: $e');
        }
      }

      await raf.close();
      debugPrint('File writing completed');

      // Verify file exists and has content
      if (!await file.exists()) {
        throw Exception('File was not created');
      }

      final fileSize = await file.length();
      debugPrint('Final file size: $fileSize bytes');

      if (fileSize == 0) {
        throw Exception('Downloaded file is empty');
      }

      // Verify file size if known
      final expectedSize = task.fileSize ?? 0;

      if (expectedSize > 0 &&
          (fileSize < expectedSize * 0.95 || fileSize > expectedSize * 1.05)) {
        // Allow 5% variance for compression/encoding differences
        debugPrint(
          'Warning: File size mismatch. Expected: $expectedSize, Got: $fileSize',
        );
        // Don't fail, just warn
      }

      // Verify checksum if provided
      if (_config.verifyChecksum && task.checksum != null) {
        debugPrint('Verifying checksum...');
        final isValid = await FileUtils.verifyChecksum(
          filePath,
          task.checksum!,
        );
        if (!isValid) {
          await file.delete();
          throw Exception('Checksum verification failed');
        }
        debugPrint('Checksum verified');
      }

      // Download completed
      final completedTask = task.copyWith(
        filePath: filePath,
        status: DownloadStatus.completed,
        downloadedBytes: fileSize,
        fileSize: fileSize > 0 ? fileSize : task.fileSize,
        updatedAt: DateTime.now(),
      );

      _cleanup(task.id);
      debugPrint('Download completed successfully: ${task.fileName}');
      onComplete(completedTask);
    } on DioException catch (e) {
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }

      _cleanup(task.id);

      if (e.type == DioExceptionType.cancel) {
        debugPrint('Download cancelled: ${task.fileName}');
        return; // Cancelled by user, don't report as error
      }

      String errorMessage = _getDioErrorMessage(e);
      debugPrint('Download error: $errorMessage');
      onError(errorMessage);
    } catch (e, stackTrace) {
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }

      _cleanup(task.id);
      debugPrint('Download error: $e');
      debugPrint('Stack trace: $stackTrace');
      onError('Download failed: ${e.toString()}');
    }
  }

  Future<void> pauseDownload(String downloadId) async {
    final cancelToken = _cancelTokens[downloadId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Paused by user');
    }
    _cleanup(downloadId);
  }

  Future<void> cancelDownload(String downloadId) async {
    final cancelToken = _cancelTokens[downloadId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Cancelled by user');
    }
    _cleanup(downloadId);
  }

  Stream<DownloadProgress>? getProgressStream(String downloadId) {
    return _progressControllers[downloadId]?.stream;
  }

  Future<int?> getContentLength(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.head(url, options: Options(headers: headers));
      final contentLength = response.headers.value('content-length');
      return contentLength != null ? int.tryParse(contentLength) : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> supportsRangeRequests(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.head(url, options: Options(headers: headers));
      final acceptRanges = response.headers.value('accept-ranges');
      return acceptRanges?.toLowerCase() == 'bytes';
    } catch (e) {
      return false;
    }
  }

  Future<String> _getDefaultFilePath(String fileName) async {
    return await FileUtils.getFullFilePath(
      fileName,
      _config.defaultStorageLocation,
      customPath: _config.customStoragePath,
    );
  }

  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.sendTimeout:
        return 'Send timeout. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout. Please try again.';
      case DioExceptionType.badResponse:
        return 'Server error: ${e.response?.statusCode ?? 'Unknown'}';
      case DioExceptionType.connectionError:
        return 'Connection error. Please check your internet connection.';
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return 'Network error. Please check your internet connection.';
        }
        return 'Download failed: ${e.message ?? 'Unknown error'}';
      default:
        return 'Download failed: ${e.message ?? 'Unknown error'}';
    }
  }

  void _cleanup(String downloadId) {
    _cancelTokens.remove(downloadId);
    _speedCalculators.remove(downloadId);
    _progressControllers[downloadId]?.close();
    _progressControllers.remove(downloadId);
  }

  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _cancelTokens.clear();
    _speedCalculators.clear();
  }
}
