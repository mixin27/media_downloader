import 'download_status.dart';

class DownloadProgress {
  final String downloadId;
  final int downloadedBytes;
  final int totalBytes;
  final double progress;
  final double speedBytesPerSecond;
  final Duration? estimatedTimeRemaining;
  final DownloadStatus status;
  final String? error;

  const DownloadProgress({
    required this.downloadId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.speedBytesPerSecond,
    this.estimatedTimeRemaining,
    required this.status,
    this.error,
  });

  String get speedFormatted {
    if (speedBytesPerSecond < 1024) {
      return '${speedBytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (speedBytesPerSecond < 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String get downloadedFormatted => _formatBytes(downloadedBytes);
  String get totalFormatted => _formatBytes(totalBytes);

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  String get timeRemainingFormatted {
    if (estimatedTimeRemaining == null) return 'Calculating...';

    final seconds = estimatedTimeRemaining!.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '${minutes}m ${seconds % 60}s';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  DownloadProgress copyWith({
    String? downloadId,
    int? downloadedBytes,
    int? totalBytes,
    double? progress,
    double? speedBytesPerSecond,
    Duration? estimatedTimeRemaining,
    DownloadStatus? status,
    String? error,
  }) {
    return DownloadProgress(
      downloadId: downloadId ?? this.downloadId,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
