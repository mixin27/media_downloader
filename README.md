# Media Downloader

A comprehensive Flutter package for downloading media files with background support, notifications, and progress tracking. Built on top of `flutter_downloader` for robust native platform integration.

## Features

- ✅ Background downloads (works even when app is killed)
- ✅ Native notifications with download progress
- ✅ Pause/Resume/Cancel/Retry support
- ✅ WiFi-only download option
- ✅ Download priority management
- ✅ Checksum verification
- ✅ Progress tracking with speed calculation
- ✅ Multiple concurrent downloads
- ✅ Custom storage locations
- ✅ Metadata support for organizing downloads

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  media_downloader: ^1.0.0
```

## Platform Setup

### Android

1. Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />

    <!-- Android 13+ -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

    <!-- Notifications (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application>
        <!-- flutter_downloader provider -->
        <provider
            android:name="vn.hunghd.flutterdownloader.DownloadedFileProvider"
            android:authorities="${applicationId}.flutter_downloader.provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/provider_paths"/>
        </provider>
    </application>
</manifest>
```

2. Create `android/app/src/main/res/xml/provider_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="."/>
</paths>
```

3. In `android/app/build.gradle`, set:

```gradle
android {
    compileSdk 34

    defaultConfig {
        minSdk 21
        targetSdk 34
    }
}
```

### iOS

1. Add to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to save downloaded media</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

2. Set minimum iOS version to 10.0 in `ios/Podfile`:

```ruby
platform :ios, '10.0'
```

## Usage

### Initialize

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MediaDownloader.instance.initialize(
    DownloadConfig(
      defaultStorageLocation: StorageLocation.downloads,
      showNotifications: true,
      maxRetries: 3,
      verifyChecksum: false,
    ),
  );

  runApp(MyApp());
}
```

### Start a Download

```dart
final downloader = MediaDownloader.instance;

try {
  final downloadId = await downloader.download(
    url: 'https://example.com/video.mp4',
    fileName: 'my_video.mp4',
    requiresWifi: false,
    showNotification: true,
    openFileFromNotification: true,
    metadata: {
      'courseId': '123',
      'lessonId': '456',
      'type': 'video',
    },
  );

  print('Download started: $downloadId');
} catch (e) {
  print('Error: $e');
}
```

### Track Progress

```dart
downloader.getProgressStream(downloadId)?.listen((progress) {
  print('Progress: ${progress.progressPercentage}');
  print('Speed: ${progress.speedFormatted}');
  print('Downloaded: ${progress.downloadedFormatted} / ${progress.totalFormatted}');
  print('Time remaining: ${progress.timeRemainingFormatted}');
});
```

### Control Downloads

```dart
// Pause
await downloader.pause(downloadId);

// Resume
final newId = await downloader.resume(downloadId);

// Cancel
await downloader.cancel(downloadId);

// Retry
final retryId = await downloader.retry(downloadId);

// Delete
await downloader.delete(downloadId);

// Open file
final success = await downloader.open(downloadId);
```

### Query Downloads

```dart
// Get all downloads
final allDownloads = await downloader.getAllDownloads();

// Get by status
final completed = await downloader.getDownloadsByStatus(DownloadStatus.completed);
final active = await downloader.getDownloadsByStatus(DownloadStatus.downloading);

// Get specific download
final task = await downloader.getDownload(downloadId);
```

### Batch Operations

```dart
// Pause all downloads
await downloader.pauseAll();

// Resume all paused downloads
await downloader.resumeAll();

// Cancel all downloads
await downloader.cancelAll();
```

## Configuration Options

```dart
DownloadConfig(
  // Storage location for downloads
  defaultStorageLocation: StorageLocation.downloads, // or .appDocuments, .appSupport, .externalStorage, .custom

  // Custom storage path (required if using StorageLocation.custom)
  customStoragePath: '/custom/path',

  // Show system notifications
  showNotifications: true,

  // Maximum retry attempts for failed downloads
  maxRetries: 3,

  // Verify file checksum after download
  verifyChecksum: false,
)
```

## Storage Locations

- `StorageLocation.appDocuments` - App's documents directory
- `StorageLocation.appSupport` - App's support directory
- `StorageLocation.externalStorage` - External storage (Android only)
- `StorageLocation.downloads` - System downloads folder
- `StorageLocation.custom` - Custom path (must provide `customStoragePath`)

## Download Status

```dart
enum DownloadStatus {
  queued,       // Waiting to start
  downloading,  // Actively downloading
  paused,       // Paused by user
  completed,    // Successfully completed
  failed,       // Failed (will retry if maxRetries not reached)
  cancelled,    // Cancelled by user
}
```

## For LMS Integration

The package is designed to be LMS-agnostic. Use the `metadata` field to store course-related information:

```dart
await downloader.download(
  url: 'https://lms.example.com/course/video.mp4',
  metadata: {
    'courseId': course.id,
    'lessonId': lesson.id,
    'moduleId': module.id,
    'contentType': 'video',
    'duration': video.duration,
    'instructorId': instructor.id,
  },
);
```

Later retrieve and filter:

```dart
final allDownloads = await downloader.getAllDownloads();
final courseDownloads = allDownloads.where((task) {
  final courseId = task.metadata?['courseId'];
  return courseId == targetCourseId;
}).toList();
```

## Integration with media_player

After downloading, get the file path and use with your media player:

```dart
// Get file path
final filePath = await downloader.getFilePath(downloadId);

if (filePath != null) {
  // Use with your media_player package
  mediaPlayer.play(filePath);
}
```

## Important Notes

1. **Background Downloads**: Downloads continue even when the app is killed, thanks to `flutter_downloader`'s native implementation.

2. **Notifications**: The package uses `flutter_downloader`'s built-in notification system. You cannot fully customize notifications, but you can enable/disable them.

3. **Permissions**: The package handles permission requests automatically, but ensure you've added the required permissions to your platform manifests.

4. **File Management**: Downloaded files are managed by the native platform. Use the provided methods to delete files when no longer needed.

5. **Network Changes**: The package automatically handles network connectivity changes. WiFi-only downloads will pause when WiFi is lost and resume when available.

## Troubleshooting

### Downloads not working in background

- Ensure you've added all required permissions to AndroidManifest.xml
- Check that provider is properly configured in AndroidManifest.xml
- Verify minimum SDK version is 21 or higher

### Notifications not showing

- Request notification permission (Android 13+)
- Check that `showNotifications: true` in config
- Verify notification channel is not disabled in system settings

### Files not accessible

- Check storage permissions are granted
- Ensure directory exists and is writable
- Try different storage location

## License

MIT License - see LICENSE file for details
