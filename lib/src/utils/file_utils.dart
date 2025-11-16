import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/download_config.dart';

class FileUtils {
  static Future<String> getStoragePath(
    StorageLocation location, {
    String? customPath,
  }) async {
    switch (location) {
      case StorageLocation.appDocuments:
        final dir = await getApplicationDocumentsDirectory();
        return dir.path;
      case StorageLocation.appSupport:
        final dir = await getApplicationSupportDirectory();
        return dir.path;
      case StorageLocation.externalStorage:
        if (Platform.isAndroid) {
          final dir = await getExternalStorageDirectory();
          return dir?.path ?? (await getApplicationDocumentsDirectory()).path;
        }
        return (await getApplicationDocumentsDirectory()).path;
      case StorageLocation.downloads:
        if (Platform.isAndroid) {
          final dir = await getExternalStorageDirectory();
          if (dir != null) {
            final downloadPath = path.join(
              dir.path.split('/Android')[0],
              'Download',
              'MediaDownloader',
            );
            return downloadPath;
          }
        }
        return (await getApplicationDocumentsDirectory()).path;
      case StorageLocation.custom:
        if (customPath == null) {
          throw ArgumentError(
            'Custom path must be provided for custom storage location',
          );
        }
        return customPath;
    }
  }

  static Future<String> getFullFilePath(
    String fileName,
    StorageLocation location, {
    String? customPath,
    String? subDirectory,
  }) async {
    final basePath = await getStoragePath(location, customPath: customPath);
    String finalPath = basePath;

    if (subDirectory != null) {
      finalPath = path.join(basePath, subDirectory);
    }

    final dir = Directory(finalPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return path.join(finalPath, fileName);
  }

  static String sanitizeFileName(String fileName) {
    // Remove invalid characters
    String sanitized = fileName.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );

    // Limit length (keep extension)
    if (sanitized.length > 255) {
      final ext = path.extension(sanitized);
      final name = path.basenameWithoutExtension(sanitized);
      sanitized = '${name.substring(0, 255 - ext.length)}$ext';
    }

    return sanitized;
  }

  static String generateUniqueFileName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = path.extension(originalName);
    final name = path.basenameWithoutExtension(originalName);
    return '${name}_$timestamp$ext';
  }

  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  static Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> deleteDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<String> calculateChecksum(
    String filePath, {
    ChecksumType type = ChecksumType.md5,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final bytes = await file.readAsBytes();

    switch (type) {
      case ChecksumType.md5:
        return md5.convert(bytes).toString();
      case ChecksumType.sha256:
        return sha256.convert(bytes).toString();
      case ChecksumType.sha1:
        return sha1.convert(bytes).toString();
    }
  }

  static Future<bool> verifyChecksum(
    String filePath,
    String expectedChecksum, {
    ChecksumType type = ChecksumType.md5,
  }) async {
    try {
      final actualChecksum = await calculateChecksum(filePath, type: type);
      return actualChecksum.toLowerCase() == expectedChecksum.toLowerCase();
    } catch (e) {
      return false;
    }
  }

  static String getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();

    final mimeTypes = {
      // Video
      '.mp4': 'video/mp4',
      '.avi': 'video/x-msvideo',
      '.mov': 'video/quicktime',
      '.mkv': 'video/x-matroska',
      '.webm': 'video/webm',
      '.flv': 'video/x-flv',
      '.wmv': 'video/x-ms-wmv',

      // Audio
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.ogg': 'audio/ogg',
      '.m4a': 'audio/mp4',
      '.aac': 'audio/aac',
      '.flac': 'audio/flac',

      // Documents
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',

      // Archives
      '.zip': 'application/zip',
      '.rar': 'application/x-rar-compressed',
      '.7z': 'application/x-7z-compressed',
      '.tar': 'application/x-tar',
      '.gz': 'application/gzip',

      // Images
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.bmp': 'image/bmp',
      '.svg': 'image/svg+xml',
      '.webp': 'image/webp',
    };

    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  static Future<void> ensureDirectoryExists(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<int> getAvailableSpace(String path) async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Note: This is a simplified version. For production, consider using a plugin
      // that provides accurate disk space information
      return 1024 * 1024 * 1024 * 5; // Return 5GB as placeholder
    }
    return 1024 * 1024 * 1024 * 5;
  }
}

enum ChecksumType { md5, sha256, sha1 }
