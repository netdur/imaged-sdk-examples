import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Application-wide SQLite handle. Initialised once at boot.
class AppDb {
  AppDb._(this.database);

  final Database database;

  static AppDb? _instance;
  static AppDb get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('AppDb.open() must be called before AppDb.instance');
    }
    return i;
  }

  /// Idempotent. Initialises the FFI factory on desktop, opens the DB,
  /// runs migrations.
  static Future<AppDb> open() async {
    if (_instance != null) return _instance!;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, 'aichat.db');

    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    final inst = AppDb._(db);
    _instance = inst;
    return inst;
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    batch.execute('''
      CREATE TABLE personas (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT,
        system_prompt TEXT NOT NULL,
        sampler_temp REAL,
        sampler_top_p REAL,
        sampler_max_tokens INTEGER,
        created_at INTEGER NOT NULL
      );
    ''');
    batch.execute('''
      CREATE TABLE models (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        model_path TEXT NOT NULL,
        mmproj_path TEXT,
        template_mode TEXT NOT NULL,
        size_bytes INTEGER,
        source_url TEXT,
        added_at INTEGER NOT NULL,
        n_ctx INTEGER NOT NULL DEFAULT 2048,
        n_batch INTEGER NOT NULL DEFAULT 512,
        n_ubatch INTEGER NOT NULL DEFAULT 512,
        flash_attn TEXT NOT NULL DEFAULT 'auto'
      );
    ''');
    batch.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        persona_id TEXT NOT NULL REFERENCES personas(id),
        model_id TEXT NOT NULL REFERENCES models(id),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sampler_temp REAL NOT NULL DEFAULT 0.7,
        sampler_top_p REAL NOT NULL DEFAULT 0.9,
        sampler_max_tokens INTEGER NOT NULL DEFAULT 512
      );
    ''');
    batch.execute(
        'CREATE INDEX idx_conversations_updated ON conversations(updated_at DESC);');
    batch.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        text TEXT NOT NULL,
        media_path TEXT,
        media_kind TEXT,
        created_at INTEGER NOT NULL,
        position INTEGER NOT NULL
      );
    ''');
    batch.execute(
        'CREATE INDEX idx_messages_conv_pos ON messages(conversation_id, position);');
    batch.execute(
        'CREATE INDEX idx_messages_created ON messages(created_at DESC);');
    batch.execute('''
      CREATE VIRTUAL TABLE messages_fts USING fts5(
        text,
        content='messages',
        content_rowid='rowid',
        tokenize='porter unicode61'
      );
    ''');
    batch.execute('''
      CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN
        INSERT INTO messages_fts(rowid, text) VALUES (new.rowid, new.text);
      END;
    ''');
    batch.execute('''
      CREATE TRIGGER messages_ad AFTER DELETE ON messages BEGIN
        INSERT INTO messages_fts(messages_fts, rowid, text)
          VALUES ('delete', old.rowid, old.text);
      END;
    ''');
    batch.execute('''
      CREATE TRIGGER messages_au AFTER UPDATE OF text ON messages BEGIN
        INSERT INTO messages_fts(messages_fts, rowid, text)
          VALUES ('delete', old.rowid, old.text);
        INSERT INTO messages_fts(rowid, text) VALUES (new.rowid, new.text);
      END;
    ''');
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      batch.execute(
          "ALTER TABLE models ADD COLUMN n_ctx INTEGER NOT NULL DEFAULT 2048;");
      batch.execute(
          "ALTER TABLE models ADD COLUMN n_batch INTEGER NOT NULL DEFAULT 512;");
      batch.execute(
          "ALTER TABLE models ADD COLUMN n_ubatch INTEGER NOT NULL DEFAULT 512;");
      batch.execute(
          "ALTER TABLE models ADD COLUMN flash_attn TEXT NOT NULL DEFAULT 'auto';");
      batch.execute(
          "ALTER TABLE conversations ADD COLUMN sampler_temp REAL NOT NULL DEFAULT 0.7;");
      batch.execute(
          "ALTER TABLE conversations ADD COLUMN sampler_top_p REAL NOT NULL DEFAULT 0.9;");
      batch.execute(
          "ALTER TABLE conversations ADD COLUMN sampler_max_tokens INTEGER NOT NULL DEFAULT 512;");
      await batch.commit(noResult: true);
    }
  }
}
