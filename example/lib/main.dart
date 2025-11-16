import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_downloader/media_downloader.dart';

import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the downloader
  await MediaDownloader.initialize(
    const DownloadConfig(
      maxConcurrentDownloads: 3,
      defaultStorageLocation: StorageLocation.downloads,
      showNotifications: true,
      enableBackgroundDownloads: true,
      maxRetries: 3,
      requiresWifiByDefault: false,
      autoStartNextDownload: true,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}
