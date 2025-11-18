import 'package:flutter/material.dart';
import 'package:media_downloader/media_downloader.dart';

import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the downloader
  await MediaDownloader.instance.initialize(
    const DownloadConfig(
      defaultStorageLocation: StorageLocation.downloads,
      showNotifications: true,
      maxRetries: 3,
      verifyChecksum: false,
    ),
  );

  runApp(const MyApp());
}
