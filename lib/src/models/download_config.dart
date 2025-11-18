enum StorageLocation {
  appDocuments,
  appSupport,
  externalStorage,
  downloads,
  custom,
}

class DownloadConfig {
  final StorageLocation defaultStorageLocation;
  final String? customStoragePath;
  final bool showNotifications;
  final int maxRetries;
  final bool verifyChecksum;

  const DownloadConfig({
    this.defaultStorageLocation = StorageLocation.appDocuments,
    this.customStoragePath,
    this.showNotifications = true,
    this.maxRetries = 3,
    this.verifyChecksum = false,
  });

  DownloadConfig copyWith({
    StorageLocation? defaultStorageLocation,
    String? customStoragePath,
    bool? showNotifications,
    int? maxRetries,
    bool? verifyChecksum,
  }) {
    return DownloadConfig(
      defaultStorageLocation:
          defaultStorageLocation ?? this.defaultStorageLocation,
      customStoragePath: customStoragePath ?? this.customStoragePath,
      showNotifications: showNotifications ?? this.showNotifications,
      maxRetries: maxRetries ?? this.maxRetries,
      verifyChecksum: verifyChecksum ?? this.verifyChecksum,
    );
  }
}
