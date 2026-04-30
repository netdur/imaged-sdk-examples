import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../models/model_bundle.dart';
import 'settings_repo.dart';

class ModelsRepo extends ChangeNotifier {
  ModelsRepo(this._db, this._settings);
  final AppDb _db;
  final SettingsRepo _settings;
  static const _uuid = Uuid();
  static const _activeKey = 'active_model_id';

  Future<List<ModelBundle>> listAll() async {
    final rows = await _db.database.query('models', orderBy: 'added_at ASC');
    return rows.map(ModelBundle.fromRow).toList();
  }

  Future<ModelBundle?> getById(String id) async {
    final rows = await _db.database
        .query('models', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ModelBundle.fromRow(rows.first);
  }

  Future<ModelBundle> add({
    required String name,
    required String modelPath,
    String? mmprojPath,
    required TemplateMode templateMode,
    int? sizeBytes,
    String? sourceUrl,
    int nCtx = 2048,
    int nBatch = 512,
    int nUbatch = 512,
    FlashAttnMode flashAttn = FlashAttnMode.auto,
  }) async {
    final m = ModelBundle(
      id: _uuid.v4(),
      name: name,
      modelPath: modelPath,
      mmprojPath: mmprojPath,
      templateMode: templateMode,
      sizeBytes: sizeBytes,
      sourceUrl: sourceUrl,
      addedAt: DateTime.now(),
      nCtx: nCtx,
      nBatch: nBatch,
      nUbatch: nUbatch,
      flashAttn: flashAttn,
    );
    await _db.database.insert('models', m.toRow());
    if (await getActiveId() == null) {
      await setActive(m.id);
    }
    notifyListeners();
    return m;
  }

  Future<void> update(ModelBundle m) async {
    await _db.database
        .update('models', m.toRow(), where: 'id = ?', whereArgs: [m.id]);
    notifyListeners();
  }

  Future<int> conversationCountForModel(String modelId) async {
    final rows = await _db.database.rawQuery(
      'SELECT COUNT(*) AS n FROM conversations WHERE model_id = ?',
      [modelId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<void> remove(String id) async {
    await _db.database.delete('models', where: 'id = ?', whereArgs: [id]);
    if (await getActiveId() == id) {
      final remaining = await listAll();
      await setActive(remaining.isEmpty ? null : remaining.first.id);
    }
    notifyListeners();
  }

  Future<String?> getActiveId() => _settings.get(_activeKey);

  Future<void> setActive(String? id) async {
    if (id == null) {
      await _settings.delete(_activeKey);
    } else {
      await _settings.set(_activeKey, id);
    }
    notifyListeners();
  }

  Future<ModelBundle?> getActive() async {
    final id = await getActiveId();
    if (id == null) return null;
    return getById(id);
  }
}
