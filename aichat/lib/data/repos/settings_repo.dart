import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db.dart';

class SettingsRepo {
  SettingsRepo(this._db);
  final AppDb _db;

  Future<String?> get(String key) async {
    final rows = await _db.database.query('settings',
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String key) async {
    await _db.database.delete('settings', where: 'key = ?', whereArgs: [key]);
  }
}
