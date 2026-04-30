import '../db.dart';

class SearchHit {
  SearchHit({
    required this.messageId,
    required this.conversationId,
    required this.conversationTitle,
    required this.snippet,
    required this.createdAt,
  });

  final String messageId;
  final String conversationId;
  final String conversationTitle;
  final String snippet;
  final DateTime createdAt;
}

class SearchRepo {
  SearchRepo(this._db);
  final AppDb _db;

  /// FTS5 search across all messages. Returns at most [limit] hits, ranked.
  /// Snippet uses bold markers (`<b>`/`</b>`) — render with a simple parser.
  Future<List<SearchHit>> search(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    // Quote each term to avoid syntax errors on punctuation.
    final ftsQuery = q
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"')
        .join(' ');
    final rows = await _db.database.rawQuery('''
      SELECT m.id AS id,
             m.conversation_id AS cid,
             c.title AS title,
             m.created_at AS created_at,
             snippet(messages_fts, 0, '<b>', '</b>', '...', 16) AS snippet
      FROM messages_fts
        JOIN messages m ON m.rowid = messages_fts.rowid
        JOIN conversations c ON c.id = m.conversation_id
      WHERE messages_fts MATCH ?
      ORDER BY rank
      LIMIT ?;
    ''', [ftsQuery, limit]);
    return rows
        .map((r) => SearchHit(
              messageId: r['id'] as String,
              conversationId: r['cid'] as String,
              conversationTitle: r['title'] as String,
              snippet: r['snippet'] as String,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            ))
        .toList();
  }
}
