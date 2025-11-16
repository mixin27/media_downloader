# Integration Examples for LMS Platform

This guide shows how to integrate the media downloader package with your Learning Management System.

## 1. Course Content Download Integration

### Model Structure

```dart
class CourseContent {
  final String id;
  final String title;
  final String type; // 'video', 'document', 'audio'
  final String url;
  final int size;
  final String? downloadId; // Link to download task
  final bool isDownloaded;

  CourseContent({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    required this.size,
    this.downloadId,
    this.isDownloaded = false,
  });
}
```

### Download Service for LMS

```dart
class LMSDownloadService {
  final DatabaseHelper _db;

  LMSDownloadService(this._db);

  Future<String> downloadCourseContent(CourseContent content) async {
    // Start download
    final downloadId = await MediaDownloader.download(
      url: content.url,
      fileName: '${content.id}_${content.title}',
      metadata: {
        'contentId': content.id,
        'courseId': content.courseId,
        'type': content.type,
      },
      priority: DownloadPriority.high,
    );

    // Save mapping to database
    await _db.saveCourseContentDownload(
      contentId: content.id,
      downloadId: downloadId,
    );

    // Listen for completion
    MediaDownloader.getProgressStream(downloadId)?.listen((progress) {
      if (progress.status == DownloadStatus.completed) {
        _handleDownloadComplete(content.id, downloadId, progress);
      }
    });

    return downloadId;
  }

  Future<void> _handleDownloadComplete(
    String contentId,
    String downloadId,
    DownloadProgress progress,
  ) async {
    final filePath = await MediaDownloader.getFilePath(downloadId);

    // Update database
    await _db.updateCourseContent(
      contentId: contentId,
      isDownloaded: true,
      localPath: filePath,
    );
  }

  Future<String?> getLocalPath(String contentId) async {
    final downloadId = await _db.getDownloadIdForContent(contentId);
    if (downloadId == null) return null;

    final task = await MediaDownloader.getDownload(downloadId);
    if (task?.status == DownloadStatus.completed) {
      return task?.filePath;
    }
    return null;
  }
}
```

## 2. Bulk Course Download

```dart
class CourseBulkDownloader {
  Future<void> downloadEntireCourse(Course course) async {
    final contents = await _fetchCourseContents(course.id);

    for (final content in contents) {
      await MediaDownloader.download(
        url: content.url,
        fileName: _generateFileName(course, content),
        metadata: {
          'courseId': course.id,
          'courseName': course.name,
          'contentId': content.id,
          'contentType': content.type,
        },
        priority: DownloadPriority.low, // Bulk = low priority
        requiresWifi: true, // Large downloads need WiFi
      );
    }
  }

  String _generateFileName(Course course, CourseContent content) {
    // Organize by course
    return '${course.name}/${content.type}/${content.title}';
  }

  Future<void> downloadLesson(String lessonId) async {
    final contents = await _fetchLessonContents(lessonId);

    for (final content in contents) {
      await MediaDownloader.download(
        url: content.url,
        fileName: _generateFileName(content),
        priority: DownloadPriority.medium,
      );
    }
  }
}
```

## 3. Offline Video Player Integration

```dart
class OfflineVideoPlayer extends StatefulWidget {
  final CourseContent content;

  const OfflineVideoPlayer({required this.content});

  @override
  State<OfflineVideoPlayer> createState() => _OfflineVideoPlayerState();
}

class _OfflineVideoPlayerState extends State<OfflineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isDownloaded = false;
  String? _downloadId;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    // Check if content is downloaded
    final downloadId = await _db.getDownloadIdForContent(widget.content.id);

    if (downloadId != null) {
      final task = await MediaDownloader.getDownload(downloadId);

      if (task?.status == DownloadStatus.completed && task?.filePath != null) {
        setState(() {
          _isDownloaded = true;
        });
        _initializeVideoPlayer(task!.filePath!);
      } else {
        setState(() {
          _downloadId = downloadId;
        });
      }
    }
  }

  void _initializeVideoPlayer(String filePath) {
    _controller = VideoPlayerController.file(File(filePath))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  Future<void> _downloadVideo() async {
    final downloadId = await MediaDownloader.download(
      url: widget.content.url,
      fileName: widget.content.title,
    );

    setState(() {
      _downloadId = downloadId;
    });

    // Listen for completion
    MediaDownloader.getProgressStream(downloadId)?.listen((progress) {
      if (progress.status == DownloadStatus.completed) {
        _checkDownloadStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloaded && _controller != null) {
      return VideoPlayer(_controller!);
    }

    if (_downloadId != null) {
      return _buildDownloadProgress(_downloadId!);
    }

    return _buildDownloadButton();
  }

  Widget _buildDownloadProgress(String downloadId) {
    return StreamBuilder<DownloadProgress>(
      stream: MediaDownloader.getProgressStream(downloadId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        final progress = snapshot.data!;
        return Column(
          children: [
            LinearProgressIndicator(value: progress.progress),
            Text('${progress.progressPercentage}'),
            Text(progress.speedFormatted),
          ],
        );
      },
    );
  }

  Widget _buildDownloadButton() {
    return ElevatedButton.icon(
      onPressed: _downloadVideo,
      icon: Icon(Icons.download),
      label: Text('Download to watch offline'),
    );
  }
}
```

## 4. Download Management UI for Teachers

```dart
class TeacherContentManager extends ConsumerWidget {
  final String courseId;

  const TeacherContentManager({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Course Downloads'),
        actions: [
          IconButton(
            icon: Icon(Icons.download_for_offline),
            onPressed: () => _downloadAllContent(context),
          ),
        ],
      ),
      body: FutureBuilder<List<CourseContent>>(
        future: _fetchCourseContent(courseId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final content = snapshot.data![index];
              return ContentDownloadItem(content: content);
            },
          );
        },
      ),
    );
  }

  Future<void> _downloadAllContent(BuildContext context) async {
    final contents = await _fetchCourseContent(courseId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download All Content'),
        content: Text('Download ${contents.length} items for offline access?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              for (final content in contents) {
                await MediaDownloader.download(
                  url: content.url,
                  fileName: content.title,
                  metadata: {
                    'courseId': courseId,
                    'contentId': content.id,
                  },
                  requiresWifi: true,
                );
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading ${contents.length} items')),
              );
            },
            child: Text('Download'),
          ),
        ],
      ),
    );
  }
}
```

## 5. Student Download Dashboard

```dart
@riverpod
class StudentDownloads extends _$StudentDownloads {
  @override
  Future<Map<String, List<DownloadTask>>> build() async {
    final downloads = await MediaDownloader.getAllDownloads();

    // Group by course
    final grouped = <String, List<DownloadTask>>{};

    for (final download in downloads) {
      final courseId = download.metadata?['courseId'] as String? ?? 'Other';
      grouped.putIfAbsent(courseId, () => []).add(download);
    }

    return grouped;
  }

  Future<void> clearCourseDownloads(String courseId) async {
    final downloads = await MediaDownloader.getAllDownloads();

    for (final download in downloads) {
      if (download.metadata?['courseId'] == courseId) {
        await MediaDownloader.delete(download.id);
      }
    }

    await refresh();
  }
}

class StudentDownloadDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(studentDownloadsProvider);

    return downloadsAsync.when(
      data: (grouped) {
        return ListView(
          children: grouped.entries.map((entry) {
            return _buildCourseSection(context, ref, entry.key, entry.value);
          }).toList(),
        );
      },
      loading: () => Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildCourseSection(
    BuildContext context,
    WidgetRef ref,
    String courseId,
    List<DownloadTask> downloads,
  ) {
    final totalSize = downloads.fold<int>(
      0,
      (sum, d) => sum + (d.fileSize ?? 0),
    );

    final completedCount = downloads.where(
      (d) => d.status == DownloadStatus.completed,
    ).length;

    return Card(
      child: ExpansionTile(
        title: Text('Course: $courseId'),
        subtitle: Text(
          '$completedCount/${downloads.length} downloaded • ${_formatBytes(totalSize)}',
        ),
        children: downloads.map((d) => DownloadItem(task: d)).toList(),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline),
          onPressed: () => _confirmClearCourse(context, ref, courseId),
        ),
      ),
    );
  }
}
```

## 6. Admin Download Statistics

```dart
@riverpod
class DownloadStatistics extends _$DownloadStatistics {
  @override
  Future<DownloadStats> build() async {
    final downloads = await MediaDownloader.getAllDownloads();

    return DownloadStats(
      total: downloads.length,
      completed: downloads.where((d) => d.status.isCompleted).length,
      active: downloads.where((d) => d.status.isActive).length,
      failed: downloads.where((d) => d.status.isFailed).length,
      totalSize: downloads.fold<int>(0, (sum, d) => sum + (d.fileSize ?? 0)),
      downloadedSize: downloads.fold<int>(
        0,
        (sum, d) => sum + d.downloadedBytes,
      ),
    );
  }
}

class AdminDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(downloadStatisticsProvider);

    return statsAsync.when(
      data: (stats) {
        return GridView.count(
          crossAxisCount: 2,
          children: [
            _buildStatCard('Total Downloads', stats.total.toString()),
            _buildStatCard('Completed', stats.completed.toString()),
            _buildStatCard('Active', stats.active.toString()),
            _buildStatCard('Failed', stats.failed.toString()),
            _buildStatCard('Total Size', _formatBytes(stats.totalSize)),
            _buildStatCard('Downloaded', _formatBytes(stats.downloadedSize)),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}
```

## 7. Smart Download Scheduler

```dart
class SmartDownloadScheduler {
  Future<void> scheduleOptimalDownloads() async {
    // Download large files during off-peak hours
    final now = DateTime.now();
    final isOffPeak = now.hour >= 22 || now.hour <= 6;

    if (isOffPeak) {
      await _downloadLargeFiles();
    }
  }

  Future<void> _downloadLargeFiles() async {
    final pendingContent = await _db.getPendingLargeContent();

    for (final content in pendingContent) {
      await MediaDownloader.download(
        url: content.url,
        fileName: content.title,
        priority: DownloadPriority.low,
        requiresWifi: true,
      );
    }
  }

  Future<void> optimizeStorageSpace() async {
    // Remove old completed downloads
    final downloads = await MediaDownloader.getDownloadsByStatus(
      DownloadStatus.completed,
    );

    downloads.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    // Keep only last 30 days
    final cutoffDate = DateTime.now().subtract(Duration(days: 30));

    for (final download in downloads) {
      if (download.updatedAt.isBefore(cutoffDate)) {
        await MediaDownloader.delete(download.id);
      }
    }
  }
}
```

## 8. Network Quality Detection

```dart
class NetworkQualityDownloader {
  Future<void> downloadWithQualityCheck(CourseContent content) async {
    final isWifi = await NetworkUtils.instance.isWifiConnected();

    // Adjust based on connection type
    final config = isWifi
        ? _getWifiConfig()
        : _getMobileConfig();

    await MediaDownloader.initialize(config);

    await MediaDownloader.download(
      url: content.url,
      fileName: content.title,
      requiresWifi: !isWifi && content.size > 50 * 1024 * 1024, // 50MB
    );
  }

  DownloadConfig _getWifiConfig() {
    return DownloadConfig(
      maxConcurrentDownloads: 5,
      chunkSize: 2 * 1024 * 1024, // 2MB chunks
    );
  }

  DownloadConfig _getMobileConfig() {
    return DownloadConfig(
      maxConcurrentDownloads: 2,
      chunkSize: 512 * 1024, // 512KB chunks
    );
  }
}
```

## 9. Integration with Native Video Player

```dart
class NativeVideoPlayerIntegration {
  Future<void> playOfflineVideo(String contentId) async {
    final downloadId = await _db.getDownloadIdForContent(contentId);

    if (downloadId == null) {
      throw Exception('Content not downloaded');
    }

    final filePath = await MediaDownloader.getFilePath(downloadId);

    if (filePath == null) {
      throw Exception('File not found');
    }

    // Use video_player package or better_player
    final controller = VideoPlayerController.file(File(filePath));
    await controller.initialize();
    await controller.play();
  }
}
```

## 10. Database Helper for LMS

```dart
class LMSDownloadDatabase {
  final Database db;

  Future<void> init() async {
    await db.execute('''
      CREATE TABLE content_downloads (
        content_id TEXT PRIMARY KEY,
        download_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        is_downloaded INTEGER DEFAULT 0,
        local_path TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (download_id) REFERENCES downloads(id)
      )
    ''');
  }

  Future<void> saveCourseContentDownload({
    required String contentId,
    required String downloadId,
    required String courseId,
  }) async {
    await db.insert('content_downloads', {
      'content_id': contentId,
      'download_id': downloadId,
      'course_id': courseId,
      'is_downloaded': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<String?> getDownloadIdForContent(String contentId) async {
    final result = await db.query(
      'content_downloads',
      where: 'content_id = ?',
      whereArgs: [contentId],
    );

    if (result.isEmpty) return null;
    return result.first['download_id'] as String?;
  }

  Future<void> markAsDownloaded(String contentId, String localPath) async {
    await db.update(
      'content_downloads',
      {
        'is_downloaded': 1,
        'local_path': localPath,
      },
      where: 'content_id = ?',
      whereArgs: [contentId],
    );
  }
}
```

These examples demonstrate how to integrate the media downloader package into a comprehensive LMS platform with features for students, teachers, and administrators.
