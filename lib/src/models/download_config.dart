enum StorageLocation {
  appDocuments,
  appSupport,
  externalStorage,
  downloads,
  custom,
}

class DownloadConfig {
  final int maxConcurrentDownloads;
  final StorageLocation defaultStorageLocation;
  final String? customStoragePath;
  final bool showNotifications;
  final bool enableBackgroundDownloads;
  final int maxRetries;
  final Duration connectionTimeout;
  final Duration receiveTimeout;
  final bool requiresWifiByDefault;
  final int chunkSize;
  final bool verifyChecksum;
  final bool autoStartNextDownload;

  const DownloadConfig({
    this.maxConcurrentDownloads = 3,
    this.defaultStorageLocation = StorageLocation.appDocuments,
    this.customStoragePath,
    this.showNotifications = true,
    this.enableBackgroundDownloads = true,
    this.maxRetries = 3,
    this.connectionTimeout = const Duration(minutes: 2),
    this.receiveTimeout = const Duration(minutes: 5),
    this.requiresWifiByDefault = false,
    this.chunkSize = 1024 * 1024, // 1MB chunks
    this.verifyChecksum = false,
    this.autoStartNextDownload = true,
  });

  DownloadConfig copyWith({
    int? maxConcurrentDownloads,
    StorageLocation? defaultStorageLocation,
    String? customStoragePath,
    bool? showNotifications,
    bool? enableBackgroundDownloads,
    int? maxRetries,
    Duration? connectionTimeout,
    Duration? receiveTimeout,
    bool? requiresWifiByDefault,
    int? chunkSize,
    bool? verifyChecksum,
    bool? autoStartNextDownload,
  }) {
    return DownloadConfig(
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      defaultStorageLocation:
          defaultStorageLocation ?? this.defaultStorageLocation,
      customStoragePath: customStoragePath ?? this.customStoragePath,
      showNotifications: showNotifications ?? this.showNotifications,
      enableBackgroundDownloads:
          enableBackgroundDownloads ?? this.enableBackgroundDownloads,
      maxRetries: maxRetries ?? this.maxRetries,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      requiresWifiByDefault:
          requiresWifiByDefault ?? this.requiresWifiByDefault,
      chunkSize: chunkSize ?? this.chunkSize,
      verifyChecksum: verifyChecksum ?? this.verifyChecksum,
      autoStartNextDownload:
          autoStartNextDownload ?? this.autoStartNextDownload,
    );
  }
}
