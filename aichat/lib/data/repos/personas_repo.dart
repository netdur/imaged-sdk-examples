import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../models/persona.dart';

class PersonasRepo extends ChangeNotifier {
  PersonasRepo(this._db);
  final AppDb _db;
  static const _uuid = Uuid();

  Future<List<Persona>> listAll() async {
    final rows = await _db.database.query('personas', orderBy: 'created_at ASC');
    return rows.map(Persona.fromRow).toList();
  }

  Future<Persona?> getById(String id) async {
    final rows = await _db.database
        .query('personas', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Persona.fromRow(rows.first);
  }

  Future<Persona> create({
    required String name,
    String? emoji,
    required String systemPrompt,
  }) async {
    final p = Persona(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      systemPrompt: systemPrompt,
      createdAt: DateTime.now(),
    );
    await _db.database.insert('personas', p.toRow());
    notifyListeners();
    return p;
  }

  Future<void> update(Persona p) async {
    await _db.database
        .update('personas', p.toRow(), where: 'id = ?', whereArgs: [p.id]);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _db.database.delete('personas', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<Persona> ensureDefault() async {
    final existing = await listAll();
    if (existing.isNotEmpty) return existing.first;
    return create(
      name: 'Default',
      emoji: '💬',
      systemPrompt: '',
    );
  }
}
