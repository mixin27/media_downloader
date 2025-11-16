# Media Downloader

A comprehensive Flutter package for downloading media files with background support, notifications, pause/resume functionality, and progress tracking.

## Features

- ✅ **Multiple File Types**: Download videos, audio, documents, zip files, and more
- ✅ **Background Downloads**: Continue downloads even when the app is closed
- ✅ **Pause/Resume/Cancel**: Full control over downloads
- ✅ **Rich Notifications**: Progress indicators with network speed and download status
- ✅ **Notification Controls**: Pause, resume, and cancel directly from notifications
- ✅ **Queue Management**: Concurrent downloads with priority support
- ✅ **Network Awareness**: Auto-pause on network loss, WiFi-only option
- ✅ **Resumable Downloads**: Continue interrupted downloads from where they left off
- ✅ **File Verification**: Optional checksum verification
- ✅ **State Management Agnostic**: Works with any state management solution
- ✅ **Persistent Storage**: Downloads persist across app restarts
- ✅ **Error Handling**: Automatic retries with exponential backoff
- ✅ **Progress Tracking**: Real-time speed, progress, and ETA

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  media_downloader:
    git:
      url: https://github.com/yourusername/media_downloader.git
```

## Platform Setup

### Android

1. Update `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

2. The `AndroidManifest.xml` is already configured (see artifact above)

### iOS

1. Update `ios/Podfile`:

```ruby
platform :ios, '12.0'
```

2. Add the required Info.plist entries (see artifact above)

3. Run `pod install` in the ios directory

## Quick Start

### 1. Initialize

```dart
import 'package:media_downloader/media_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MediaDownloader.initialize(
    DownloadConfig(
      maxConcurrentDownloads: 3,
      showNotifications: true,
      enableBackgroundDownloads: true,
    ),
  );

  runApp(MyApp());
}
```

### 2. Start a Download

```dart
final downloadId = await MediaDownloader.download(
  url: 'https://example.com/file.mp4',
  fileName: 'my_video.mp4', // Optional
  priority: DownloadPriority.high,
  requiresWifi: false,
);
```

### 3. Monitor Progress

```dart
MediaDownloader.getProgressStream(downloadId)?.listen((progress) {
  print('Progress: ${progress.progressPercentage}');
  print('Speed: ${progress.speedFormatted}');
  print('Downloaded: ${progress.downloadedFormatted} / ${progress.totalFormatted}');
});
```

### 4. Control Downloads

```dart
// Pause
await MediaDownloader.pause(downloadId);

// Resume
await MediaDownloader.resume(downloadId);

// Cancel
await MediaDownloader.cancel(downloadId);

// Retry failed download
await MediaDownloader.retry(downloadId);
```

### 5. Get File Path

```dart
final filePath = await MediaDownloader.getFilePath(downloadId);
print('File saved at: $filePath');
```

## Configuration Options

```dart
DownloadConfig(
  // Maximum concurrent downloads
  maxConcurrentDownloads: 3,

  // Default storage location
  defaultStorageLocation: StorageLocation.appDocuments,

  // Custom storage path (for StorageLocation.custom)
  customStoragePath: '/path/to/directory',

  // Show notifications
  showNotifications: true,

  // Enable background downloads
  enableBackgroundDownloads: true,

  // Maximum retry attempts
  maxRetries: 3,

  // Connection timeout
  connectionTimeout: Duration(seconds: 30),

  // Receive timeout
  receiveTimeout: Duration(seconds: 30),

  // Require WiFi by default
  requiresWifiByDefault: false,

  // Download chunk size
  chunkSize: 1024 * 1024, // 1MB

  // Verify checksum
  verifyChecksum: false,

  // Auto start next download
  autoStartNextDownload: true,
)
```

## Storage Locations

```dart
enum StorageLocation {
  appDocuments,    // Application documents directory
  appSupport,      // Application support directory
  externalStorage, // External storage (Android only)
  downloads,       // Downloads folder (Android/Desktop)
  custom,          // Custom path
}
```

## Download Priority

```dart
enum DownloadPriority {
  low,
  medium,
  high,
}
```

High priority downloads are processed first.

## Advanced Usage

### With Riverpod

See the example app for a complete Riverpod integration with code generation.

```dart
@riverpod
class DownloadList extends _$DownloadList {
  @override
  Future<List<DownloadTask>> build() async {
    return await MediaDownloader.getAllDownloads();
  }

  Future<void> addDownload(String url) async {
    await MediaDownloader.download(url: url);
    await refresh();
  }
}
```

### Custom Headers

```dart
await MediaDownloader.download(
  url: 'https://example.com/file.mp4',
  headers: {
    'Authorization': 'Bearer token',
    'Custom-Header': 'value',
  },
);
```

### Metadata

Store custom metadata with downloads:

```dart
await MediaDownloader.download(
  url: 'https://example.com/file.mp4',
  metadata: {
    'courseId': '123',
    'lessonId': '456',
    'userId': 'abc',
  },
);
```

### Checksum Verification

```dart
await MediaDownloader.download(
  url: 'https://example.com/file.mp4',
  checksum: 'expected_md5_hash',
);
```

Make sure to enable checksum verification in config:

```dart
DownloadConfig(
  verifyChecksum: true,
)
```

### WiFi-Only Downloads

```dart
await MediaDownloader.download(
  url: 'https://example.com/large_file.mp4',
  requiresWifi: true, // Download only on WiFi
);
```

### Query Downloads

```dart
// Get all downloads
final allDownloads = await MediaDownloader.getAllDownloads();

// Get by status
final activeDownloads = await MediaDownloader.getDownloadsByStatus(
  DownloadStatus.downloading,
);

// Get specific download
final download = await MediaDownloader.getDownload(downloadId);
```

### Batch Operations

```dart
// Pause all
await MediaDownloader.pauseAll();

// Resume all
await MediaDownloader.resumeAll();

// Cancel all
await MediaDownloader.cancelAll();

// Clear completed
await MediaDownloader.clearCompleted();
```

## Background Downloads

The package uses WorkManager for Android and background fetch for iOS to ensure downloads continue even when the app is closed or in the background.

### How it Works

1. When app goes to background, active downloads are registered with WorkManager
2. Downloads continue in the background
3. When app returns to foreground, downloads are automatically synced
4. Notifications keep users informed of progress

### Limitations

- **iOS**: Background downloads have time limits imposed by the OS
- **Android**: WorkManager minimum interval is 15 minutes for periodic tasks
- Both platforms may restrict background operations based on battery optimization settings

## Notifications

The package provides rich notifications with:

- Progress bar with percentage
- Download speed and downloaded/total size
- Pause/Resume/Cancel actions (Android)
- Tap to open app

### Customization

Notifications are automatically managed, but you can disable them:

```dart
DownloadConfig(
  showNotifications: false,
)
```

## Error Handling

The package handles various errors automatically:

- **Network errors**: Auto-retry with exponential backoff
- **Connection timeout**: Configurable timeout with retry
- **File system errors**: Proper error messages
- **Insufficient storage**: Error reported
- **Permission denied**: Error reported

### Retry Logic

Failed downloads are automatically retried up to `maxRetries` times. You can also manually retry:

```dart
await MediaDownloader.retry(downloadId);
```

## File Utilities

The package includes helpful file utilities:

```dart
import 'package:media_downloader/src/utils/file_utils.dart';

// Sanitize file name
final safeName = FileUtils.sanitizeFileName(fileName);

// Get MIME type
final mimeType = FileUtils.getMimeType(fileName);

// Check if file exists
final exists = await FileUtils.fileExists(filePath);

// Delete file
await FileUtils.deleteFile(filePath);

// Calculate checksum
final checksum = await FileUtils.calculateChecksum(
  filePath,
  type: ChecksumType.md5,
);
```

## Best Practices

1. **Initialize Early**: Call `MediaDownloader.initialize()` in `main()` before `runApp()`

2. **Handle Permissions**: The package requests permissions automatically, but you may want to check them:

```dart
import 'package:media_downloader/src/services/permission_service.dart';

final hasPermission = await PermissionService.instance.checkStoragePermission();
if (!hasPermission) {
  await PermissionService.instance.requestStoragePermission();
}
```

3. **Clean Up**: Clear completed downloads periodically:

```dart
await MediaDownloader.clearCompleted();
```

4. **Monitor Storage**: Check available storage before large downloads

5. **Use Priorities**: Assign appropriate priorities to downloads based on user needs

6. **Error UI**: Show appropriate UI feedback for different error states

## Example App

The package includes a complete example app demonstrating:

- Riverpod integration with code generation
- Download list with real-time progress
- Add download dialog with sample URLs
- Pause/Resume/Cancel controls
- Tab-based UI (All, Active, Completed)
- Error handling and retry
- Notification controls

To run the example:

```bash
cd example
flutter pub get
flutter pub run build_runner build
flutter run
```

## Troubleshooting

### Android

**Issue**: Downloads not working on Android 11+
**Solution**: Make sure you have the correct storage permissions in AndroidManifest.xml

**Issue**: Background downloads stop
**Solution**: Check battery optimization settings. You may need to request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

### iOS

**Issue**: Downloads stop in background
**Solution**: iOS has strict background execution limits. Consider using `URLSession` background transfer for critical downloads

**Issue**: Notifications not showing
**Solution**: Check notification permissions in device settings

### Both Platforms

**Issue**: "Not initialized" error
**Solution**: Call `MediaDownloader.initialize()` before using any other methods

**Issue**: Downloads failing silently
**Solution**: Check the error property of the DownloadTask for error details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Support

For issues and feature requests, please file an issue on GitHub.
