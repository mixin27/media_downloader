import 'package:flutter/material.dart';

import 'pages/download_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // final platform = Theme.of(context).platform;

    return MaterialApp(
      title: 'Media Downloader Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DownloadPage(),
    );
  }
}
