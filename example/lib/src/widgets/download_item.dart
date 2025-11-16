import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_downloader/media_downloader.dart';

import '../providers/download_providers.dart';

class DownloadItem extends ConsumerWidget {
  final DownloadTask task;

  const DownloadItem({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(downloadProgressProvider(task.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: _buildStatusIcon(task.status),
            title: Text(
              task.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: progressAsync.when(
              data: (progress) => _buildProgressInfo(progress),
              loading: () => _buildStaticInfo(task),
              error: (_, _) => _buildStaticInfo(task),
            ),
            trailing: _buildActionButtons(context, ref),
          ),
          progressAsync.when(
            data: (progress) {
              if (progress.status == DownloadStatus.downloading ||
                  progress.status == DownloadStatus.queued) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: progress.progress,
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${progress.downloadedFormatted} / ${progress.totalFormatted}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            progress.speedFormatted,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          if (task.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Error: ${task.error}',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.download, color: Colors.white, size: 20),
        );
      case DownloadStatus.paused:
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.pause, color: Colors.white, size: 20),
        );
      case DownloadStatus.completed:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white, size: 20),
        );
      case DownloadStatus.failed:
        return const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.error, color: Colors.white, size: 20),
        );
      case DownloadStatus.cancelled:
        return const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.cancel, color: Colors.white, size: 20),
        );
      case DownloadStatus.queued:
        return const CircleAvatar(
          backgroundColor: Colors.purple,
          child: Icon(Icons.schedule, color: Colors.white, size: 20),
        );
    }
  }

  Widget _buildProgressInfo(DownloadProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_getStatusText(progress.status)),
        if (progress.status == DownloadStatus.downloading)
          Text(
            '${progress.progressPercentage} • ${progress.timeRemainingFormatted} remaining',
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildStaticInfo(DownloadTask task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_getStatusText(task.status)),
        if (task.fileSize != null)
          Text(
            _formatBytes(task.fileSize!),
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
      case DownloadStatus.queued:
        return 'Queued';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.status.canPause)
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () => _pauseDownload(ref),
          ),
        if (task.status.canResume)
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _resumeDownload(ref),
          ),
        if (task.status.canRetry)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _retryDownload(ref),
          ),
        PopupMenuButton(
          itemBuilder: (context) => [
            if (task.status != DownloadStatus.cancelled)
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel),
                    SizedBox(width: 8),
                    Text('Cancel'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
            if (task.filePath != null && task.status.isCompleted)
              const PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new),
                    SizedBox(width: 8),
                    Text('Open'),
                  ],
                ),
              ),
          ],
          onSelected: (value) => _handleMenuAction(context, ref, value),
        ),
      ],
    );
  }

  Future<void> _pauseDownload(WidgetRef ref) async {
    await ref.read(downloadListProvider.notifier).pauseDownload(task.id);
  }

  Future<void> _resumeDownload(WidgetRef ref) async {
    await ref.read(downloadListProvider.notifier).resumeDownload(task.id);
  }

  Future<void> _retryDownload(WidgetRef ref) async {
    await ref.read(downloadListProvider.notifier).retryDownload(task.id);
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'cancel':
        await ref.read(downloadListProvider.notifier).cancelDownload(task.id);
        break;
      case 'delete':
        final confirmed = await _showConfirmDialog(
          context,
          'Delete Download',
          'Are you sure you want to delete this download?',
        );
        if (confirmed) {
          await ref.read(downloadListProvider.notifier).deleteDownload(task.id);
        }
        break;
      case 'open':
        if (task.filePath != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File: ${task.filePath}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        break;
    }
  }

  Future<bool> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
