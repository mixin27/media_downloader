import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_downloader/media_downloader.dart';

import '../providers/download_providers.dart';
import '../widgets/add_download_dialog.dart';
import '../widgets/download_item.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Refresh on tab change
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _refreshCurrentTab();
      }
    });
  }

  void _refreshCurrentTab() {
    switch (_tabController.index) {
      case 0:
        ref.read(downloadListProvider.notifier).refresh();
        break;
      case 1:
        ref.read(activeDownloadsProvider.notifier).refresh();
        break;
      case 2:
        ref.read(completedDownloadsProvider.notifier).refresh();
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Downloader'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All', icon: Icon(Icons.list)),
            Tab(text: 'Active', icon: Icon(Icons.download)),
            Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
          ],
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pause_all',
                child: Row(
                  children: [
                    Icon(Icons.pause),
                    SizedBox(width: 8),
                    Text('Pause All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'resume_all',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow),
                    SizedBox(width: 8),
                    Text('Resume All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel_all',
                child: Row(
                  children: [
                    Icon(Icons.cancel),
                    SizedBox(width: 8),
                    Text('Cancel All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Completed'),
                  ],
                ),
              ),
            ],
            onSelected: _handleMenuAction,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllDownloads(),
          _buildActiveDownloads(),
          _buildCompletedDownloads(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDownloadDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllDownloads() {
    final downloadsAsync = ref.watch(downloadListProvider);

    return downloadsAsync.when(
      data: (downloads) {
        if (downloads.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No downloads yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap + to add a new download',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(downloadListProvider.notifier).refresh();
          },
          child: ListView.builder(
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              return DownloadItem(task: downloads[index]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(downloadListProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDownloads() {
    final downloadsAsync = ref.watch(activeDownloadsProvider);

    return downloadsAsync.when(
      data: (downloads) {
        if (downloads.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_done, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No active downloads',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: downloads.length,
          itemBuilder: (context, index) {
            return DownloadItem(task: downloads[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildCompletedDownloads() {
    final downloadsAsync = ref.watch(completedDownloadsProvider);

    return downloadsAsync.when(
      data: (downloads) {
        if (downloads.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No completed downloads',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: downloads.length,
          itemBuilder: (context, index) {
            return DownloadItem(task: downloads[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'pause_all':
        await ref.read(downloadListProvider.notifier).pauseAll();
        break;
      case 'resume_all':
        await ref.read(downloadListProvider.notifier).resumeAll();
        break;
      case 'cancel_all':
        final confirmed = await _showConfirmDialog(
          'Cancel All Downloads',
          'Are you sure you want to cancel all downloads?',
        );
        if (confirmed) {
          await ref.read(downloadListProvider.notifier).cancelAll();
        }
        break;
      case 'clear_completed':
        await ref.read(downloadListProvider.notifier).clearCompleted();
        break;
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
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

  Future<void> _showAddDownloadDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddDownloadDialog(),
    );

    if (result != null) {
      await ref
          .read(downloadListProvider.notifier)
          .addDownload(
            url: result['url'] as String,
            fileName: result['fileName'] as String?,
            priority: result['priority'] as DownloadPriority,
            requiresWifi: result['requiresWifi'] as bool,
          );
    }
  }
}
