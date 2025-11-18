import 'package:flutter/material.dart';
import 'package:media_downloader/media_downloader.dart';

import '../widgets/add_download_dialog.dart';
import '../widgets/download_tile.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final _downloader = MediaDownloader.instance;
  final _urlController = TextEditingController(
    text:
        'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  );

  List<MediaDownloadTask> _downloads = [];
  final Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    final downloads = await _downloader.getAllDownloads();
    setState(() {
      _downloads = downloads;
    });
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showMessage('Please enter a URL');
      return;
    }

    try {
      final downloadId = await _downloader.download(
        url: url,
        requiresWifi: false,
        showNotification: true,
        openFileFromNotification: true,
        metadata: {'type': 'video', 'category': 'course_material'},
      );

      // Listen to progress
      _downloader.getProgressStream(downloadId)?.listen((progress) {
        setState(() {
          _progress[downloadId] = progress.progress;
        });
      });

      await _loadDownloads();
      _showMessage('Download started');
    } catch (e) {
      _showMessage('Error: $e');
    }
  }

  Future<void> _pauseDownload(String id) async {
    try {
      await _downloader.pause(id);
      await _loadDownloads();
    } catch (e) {
      _showMessage('Error pausing: $e');
    }
  }

  Future<void> _resumeDownload(String id) async {
    try {
      await _downloader.resume(id);
      await _loadDownloads();
    } catch (e) {
      _showMessage('Error resuming: $e');
    }
  }

  Future<void> _cancelDownload(String id) async {
    try {
      await _downloader.cancel(id);
      await _loadDownloads();
    } catch (e) {
      _showMessage('Error cancelling: $e');
    }
  }

  Future<void> _retryDownload(String id) async {
    try {
      await _downloader.retry(id);
      await _loadDownloads();
    } catch (e) {
      _showMessage('Error retrying: $e');
    }
  }

  Future<void> _deleteDownload(String id) async {
    try {
      await _downloader.delete(id);
      await _loadDownloads();
      _showMessage('Download deleted');
    } catch (e) {
      _showMessage('Error deleting: $e');
    }
  }

  Future<void> _openFile(String id) async {
    try {
      final success = await _downloader.open(id);
      if (!success) {
        _showMessage('Could not open file');
      }
    } catch (e) {
      _showMessage('Error opening: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Downloader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloads,
          ),
          IconButton(
            icon: const Icon(Icons.pause_circle),
            onPressed: () => _downloader.pauseAll(),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle),
            onPressed: () => _downloader.resumeAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Download URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _startDownload,
                  child: const Text('Download'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _downloads.isEmpty
                ? const Center(child: Text('No downloads'))
                : ListView.builder(
                    itemCount: _downloads.length,
                    itemBuilder: (context, index) {
                      final download = _downloads[index];
                      return DownloadTile(
                        download: download,
                        progress: _progress[download.id] ?? 0.0,
                        onPause: () => _pauseDownload(download.id),
                        onResume: () => _resumeDownload(download.id),
                        onCancel: () => _cancelDownload(download.id),
                        onRetry: () => _retryDownload(download.id),
                        onDelete: () => _deleteDownload(download.id),
                        onOpen: () => _openFile(download.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDownloadDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDownloadDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddDownloadDialog(),
    );

    if (result != null) {
      _urlController.text = result['url'];
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
