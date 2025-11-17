import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:media_downloader/media_downloader.dart';

part 'download_providers.g.dart';

@riverpod
class DownloadList extends _$DownloadList {
  Timer? _refreshTimer;

  @override
  Future<List<DownloadTask>> build() async {
    // Auto-refresh every 2 seconds when there are active downloads
    _startAutoRefresh();

    // Clean up timer on dispose
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    return await MediaDownloader.getAllDownloads();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      // Only refresh if there are active downloads
      final downloads = state.value ?? [];
      final hasActive = downloads.any(
        (d) =>
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.queued,
      );

      if (hasActive) {
        await refresh();
      }
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await MediaDownloader.getAllDownloads();
    });
  }

  Future<void> addDownload({
    required String url,
    String? fileName,
    DownloadPriority priority = DownloadPriority.medium,
    bool requiresWifi = false,
    bool useUniqueFileName = true,
  }) async {
    await MediaDownloader.download(
      url: url,
      fileName: fileName,
      priority: priority,
      requiresWifi: requiresWifi,
      useUniqueFileName: useUniqueFileName,
      metadata: {
        'originalFileName':
            fileName ??
            FileUtils.sanitizeFileName(url.split('/').last.split('?').first),
      },
    );
    await refresh();
  }

  Future<void> pauseDownload(String downloadId) async {
    await MediaDownloader.pause(downloadId);
    await refresh();
  }

  Future<void> resumeDownload(String downloadId) async {
    await MediaDownloader.resume(downloadId);
    await refresh();
  }

  Future<void> cancelDownload(String downloadId) async {
    await MediaDownloader.cancel(downloadId);
    await refresh();
  }

  Future<void> retryDownload(String downloadId) async {
    await MediaDownloader.retry(downloadId);
    await refresh();
  }

  Future<void> deleteDownload(String downloadId) async {
    await MediaDownloader.delete(downloadId);
    await refresh();
  }

  Future<void> clearCompleted() async {
    await MediaDownloader.clearCompleted();
    await refresh();
  }

  Future<void> pauseAll() async {
    await MediaDownloader.pauseAll();
    await refresh();
  }

  Future<void> resumeAll() async {
    await MediaDownloader.resumeAll();
    await refresh();
  }

  Future<void> cancelAll() async {
    await MediaDownloader.cancelAll();
    await refresh();
  }
}

@riverpod
Stream<DownloadProgress> downloadProgress(Ref ref, String downloadId) {
  final stream = MediaDownloader.getProgressStream(downloadId);
  if (stream == null) {
    return Stream.error('Download not found');
  }
  return stream;
}

@riverpod
class ActiveDownloads extends _$ActiveDownloads {
  Timer? _refreshTimer;

  @override
  Future<List<DownloadTask>> build() async {
    // Auto-refresh every 2 seconds
    _startAutoRefresh();

    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    return await MediaDownloader.getDownloadsByStatus(
      DownloadStatus.downloading,
    );
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await refresh();
    });
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      return await MediaDownloader.getDownloadsByStatus(
        DownloadStatus.downloading,
      );
    });
  }
}

@riverpod
class CompletedDownloads extends _$CompletedDownloads {
  @override
  Future<List<DownloadTask>> build() async {
    return await MediaDownloader.getDownloadsByStatus(DownloadStatus.completed);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      return await MediaDownloader.getDownloadsByStatus(
        DownloadStatus.completed,
      );
    });
  }
}
