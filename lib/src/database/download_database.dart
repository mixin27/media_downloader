import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/download_status.dart';
import '../models/download_task.dart';

class DownloadDatabase {
  static final DownloadDatabase instance = DownloadDatabase._init();
  static Database? _database;

  DownloadDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('meder_downloads.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT';
    const integerType = 'INTEGER';

    await db.execute('''
      CREATE TABLE downloads (
        id $idType,
        url $textType NOT NULL,
        fileName $textType NOT NULL,
        filePath $textType,
        fileSize $integerType,
        downloadedBytes $integerType DEFAULT 0,
        status $textType NOT NULL,
        mimeType $textType,
        createdAt $integerType NOT NULL,
        updatedAt $integerType NOT NULL,
        metadata $textType,
        headers $textType,
        priority $textType DEFAULT 'medium',
        error $textType,
        retryCount $integerType DEFAULT 0,
        checksum $textType,
        requiresWifi $integerType DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_status ON downloads(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_created_at ON downloads(createdAt)
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades in future versions
  }

  Future<String> insert(DownloadTask task) async {
    final db = await database;
    await db.insert(
      'downloads',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return task.id;
  }

  Future<DownloadTask?> getById(String id) async {
    final db = await database;
    final maps = await db.query('downloads', where: 'id = ?', whereArgs: [id]);

    if (maps.isEmpty) return null;
    return DownloadTask.fromMap(maps.first);
  }

  Future<List<DownloadTask>> getAll() async {
    final db = await database;
    final maps = await db.query('downloads', orderBy: 'createdAt DESC');

    return maps.map((map) => DownloadTask.fromMap(map)).toList();
  }

  Future<List<DownloadTask>> getByStatus(DownloadStatus status) async {
    final db = await database;
    final maps = await db.query(
      'downloads',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'priority DESC, createdAt ASC',
    );

    return maps.map((map) => DownloadTask.fromMap(map)).toList();
  }

  Future<List<DownloadTask>> getActiveDownloads() async {
    final db = await database;
    final maps = await db.query(
      'downloads',
      where: 'status IN (?, ?)',
      whereArgs: [DownloadStatus.downloading.name, DownloadStatus.queued.name],
      orderBy: 'priority DESC, createdAt ASC',
    );

    return maps.map((map) => DownloadTask.fromMap(map)).toList();
  }

  Future<List<DownloadTask>> getIncompleteDownloads() async {
    final db = await database;
    final maps = await db.query(
      'downloads',
      where: 'status IN (?, ?, ?)',
      whereArgs: [
        DownloadStatus.downloading.name,
        DownloadStatus.queued.name,
        DownloadStatus.paused.name,
      ],
      orderBy: 'priority DESC, createdAt ASC',
    );

    return maps.map((map) => DownloadTask.fromMap(map)).toList();
  }

  Future<int> update(DownloadTask task) async {
    final db = await database;
    return await db.update(
      'downloads',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> updateStatus(
    String id,
    DownloadStatus status, {
    String? error,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final data = <String, dynamic>{'status': status.name, 'updatedAt': now};

    if (error != null) {
      data['error'] = error;
    }

    return await db.update('downloads', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateProgress(String id, int downloadedBytes) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.update(
      'downloads',
      {'downloadedBytes': downloadedBytes, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateFilePath(String id, String filePath) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.update(
      'downloads',
      {'filePath': filePath, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> incrementRetryCount(String id) async {
    final db = await database;
    final task = await getById(id);
    if (task == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'downloads',
      {'retryCount': task.retryCount + 1, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String id) async {
    final db = await database;
    return await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCompleted() async {
    final db = await database;
    return await db.delete(
      'downloads',
      where: 'status = ?',
      whereArgs: [DownloadStatus.completed.name],
    );
  }

  Future<int> deleteAll() async {
    final db = await database;
    return await db.delete('downloads');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
