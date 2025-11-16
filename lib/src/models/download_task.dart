import 'dart:convert';

import 'download_status.dart';

class DownloadTask {
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

  const DownloadTask({
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'downloadedBytes': downloadedBytes,
      'status': status.name,
      'mimeType': mimeType,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'headers': headers != null ? jsonEncode(headers) : null,
      'priority': priority.name,
      'error': error,
      'retryCount': retryCount,
      'checksum': checksum,
      'requiresWifi': requiresWifi ? 1 : 0,
    };
  }

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String,
      url: map['url'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String?,
      fileSize: map['fileSize'] as int?,
      downloadedBytes: map['downloadedBytes'] as int? ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DownloadStatus.queued,
      ),
      mimeType: map['mimeType'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      metadata: map['metadata'] != null
          ? jsonDecode(map['metadata'] as String) as Map<String, dynamic>
          : null,
      headers: map['headers'] != null
          ? Map<String, String>.from(jsonDecode(map['headers'] as String))
          : null,
      priority: DownloadPriority.values.firstWhere(
        (e) => e.name == (map['priority'] ?? 'medium'),
        orElse: () => DownloadPriority.medium,
      ),
      error: map['error'] as String?,
      retryCount: map['retryCount'] as int? ?? 0,
      checksum: map['checksum'] as String?,
      requiresWifi: (map['requiresWifi'] as int?) == 1,
    );
  }

  DownloadTask copyWith({
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
    return DownloadTask(
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
