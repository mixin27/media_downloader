import 'package:flutter/material.dart';
import 'package:media_downloader/media_downloader.dart';

class AddDownloadDialog extends StatefulWidget {
  const AddDownloadDialog({super.key});

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _fileNameController = TextEditingController();

  DownloadPriority _priority = DownloadPriority.medium;
  bool _requiresWifi = false;

  // Sample URLs for testing
  final List<String> sampleUrls = [
    'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    'https://assets.openstax.org/oscms-prodcms/media/documents/Introduction_To_Computer_Science_-_WEB.pdf',
  ];

  @override
  void dispose() {
    _urlController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Download'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'Enter file URL',
                  border: const OutlineInputBorder(),
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.link),
                    tooltip: 'Sample URLs',
                    itemBuilder: (context) => sampleUrls
                        .map(
                          (url) => PopupMenuItem(
                            value: url,
                            child: Text(
                              url.split('/').last.substring(0, 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onSelected: (url) {
                      _urlController.text = url;
                      _fileNameController.text = url
                          .split('/')
                          .last
                          .split('?')
                          .first;
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a URL';
                  }
                  if (!Uri.tryParse(value)!.isAbsolute) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fileNameController,
                decoration: const InputDecoration(
                  labelText: 'File Name (Optional)',
                  hintText: 'Leave empty to auto-detect',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Priority',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<DownloadPriority>(
                segments: const [
                  ButtonSegment(
                    value: DownloadPriority.low,
                    label: Text('Low'),
                    icon: Icon(Icons.low_priority),
                  ),
                  ButtonSegment(
                    value: DownloadPriority.medium,
                    label: Text('Medium'),
                    icon: Icon(Icons.remove),
                  ),
                  ButtonSegment(
                    value: DownloadPriority.high,
                    label: Text('High'),
                    icon: Icon(Icons.priority_high),
                  ),
                ],
                selected: {_priority},
                onSelectionChanged: (Set<DownloadPriority> newSelection) {
                  setState(() {
                    _priority = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Requires WiFi'),
                subtitle: const Text('Download only when connected to WiFi'),
                value: _requiresWifi,
                onChanged: (value) {
                  setState(() {
                    _requiresWifi = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _addDownload, child: const Text('Download')),
      ],
    );
  }

  void _addDownload() {
    if (_formKey.currentState!.validate()) {
      final result = {
        'url': _urlController.text.trim(),
        'fileName': _fileNameController.text.trim().isEmpty
            ? null
            : _fileNameController.text.trim(),
        'priority': _priority,
        'requiresWifi': _requiresWifi,
      };
      Navigator.pop(context, result);
    }
  }
}
