import 'download_status.dart';

class MediaDownloadTask {
  final String id;
  final String url;
  final String fileName;
  final String? filePath;
  final int? fileSize;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;
  final Map<String, String>? headers;
  final DownloadPriority priority;
  final String? error;
  final int retryCount;
  final String? checksum;
  final bool requiresWifi;

  const MediaDownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    this.filePath,
    this.fileSize,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.queued,
    this.mimeType,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
    this.headers,
    this.priority = DownloadPriority.medium,
    this.error,
    this.retryCount = 0,
    this.checksum,
    this.requiresWifi = false,
  });

  double get progress {
    if (fileSize == null || fileSize == 0) return 0.0;
    return downloadedBytes / fileSize!;
  }

  bool get isResumable =>
      downloadedBytes > 0 && downloadedBytes < (fileSize ?? 0);

  MediaDownloadTask copyWith({
    String? id,
    String? url,
    String? fileName,
    String? filePath,
    int? fileSize,
    int? downloadedBytes,
    DownloadStatus? status,
    String? mimeType,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    Map<String, String>? headers,
    DownloadPriority? priority,
    String? error,
    int? retryCount,
    String? checksum,
    bool? requiresWifi,
  }) {
    return MediaDownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      headers: headers ?? this.headers,
      priority: priority ?? this.priority,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
      checksum: checksum ?? this.checksum,
      requiresWifi: requiresWifi ?? this.requiresWifi,
    );
  }
}
