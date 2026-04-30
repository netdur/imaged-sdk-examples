import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ConversationsRepo extends ChangeNotifier {
  ConversationsRepo(this._db);
  final AppDb _db;
  static const _uuid = Uuid();

  Future<List<Conversation>> listAll() async {
    final rows = await _db.database.query('conversations', orderBy: 'updated_at DESC');
    return rows.map(Conversation.fromRow).toList();
  }

  Future<Conversation?> getById(String id) async {
    final rows = await _db.database
        .query('conversations', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Conversation.fromRow(rows.first);
  }

  Future<Conversation> create({
    required String personaId,
    required String modelId,
    String title = 'New chat',
  }) async {
    final now = DateTime.now();
    final c = Conversation(
      id: _uuid.v4(),
      title: title,
      personaId: personaId,
      modelId: modelId,
      createdAt: now,
      updatedAt: now,
    );
    await _db.database.insert('conversations', c.toRow());
    notifyListeners();
    return c;
  }

  Future<void> rename(String id, String title) async {
    await _db.database.update(
      'conversations',
      {'title': title, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  Future<void> updateSampler(
    String id, {
    required double temp,
    required double topP,
    required int maxTokens,
  }) async {
    await _db.database.update(
      'conversations',
      {
        'sampler_temp': temp,
        'sampler_top_p': topP,
        'sampler_max_tokens': maxTokens,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  Future<void> touch(String id) async {
    await _db.database.update(
      'conversations',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _db.database.delete('conversations', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// Last message text + role for sidebar previews.
  Future<({MessageRole? role, String text, DateTime? at})> latestSnippet(
      String conversationId) async {
    final rows = await _db.database.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'position DESC',
      limit: 1,
    );
    if (rows.isEmpty) return (role: null, text: '', at: null);
    final r = rows.first;
    return (
      role: MessageRole.values
          .firstWhere((m) => m.name == r['role'], orElse: () => MessageRole.user),
      text: r['text'] as String,
      at: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    );
  }

  Future<List<Message>> listMessages(String conversationId) async {
    final rows = await _db.database.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'position ASC',
    );
    return rows.map(Message.fromRow).toList();
  }

  Future<Message> addMessage({
    required String conversationId,
    required MessageRole role,
    required String text,
    String? mediaPath,
    MediaKind? mediaKind,
  }) async {
    final pos = await _nextPosition(conversationId);
    final m = Message(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: role,
      text: text,
      mediaPath: mediaPath,
      mediaKind: mediaKind,
      createdAt: DateTime.now(),
      position: pos,
    );
    await _db.database.insert('messages', m.toRow());
    await touch(conversationId);
    return m;
  }

  Future<void> updateMessageText(String id, String text) async {
    await _db.database.update(
      'messages',
      {'text': text},
      where: 'id = ?',
      whereArgs: [id],
    );
    // Don't notify on each token write — would thrash the sidebar.
  }

  Future<int> _nextPosition(String conversationId) async {
    final result = await _db.database.rawQuery(
      'SELECT MAX(position) AS p FROM messages WHERE conversation_id = ?',
      [conversationId],
    );
    final p = result.first['p'] as int?;
    return (p ?? -1) + 1;
  }
}
