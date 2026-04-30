enum MessageRole { system, user, assistant }

enum MediaKind { image, audio }

class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.text,
    this.mediaPath,
    this.mediaKind,
    required this.createdAt,
    required this.position,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String text;
  final String? mediaPath;
  final MediaKind? mediaKind;
  final DateTime createdAt;
  final int position;

  bool get hasMedia => mediaPath != null;

  Map<String, Object?> toRow() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'text': text,
        'media_path': mediaPath,
        'media_kind': mediaKind?.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'position': position,
      };

  factory Message.fromRow(Map<String, Object?> row) => Message(
        id: row['id'] as String,
        conversationId: row['conversation_id'] as String,
        role: MessageRole.values.firstWhere(
          (r) => r.name == row['role'],
          orElse: () => MessageRole.user,
        ),
        text: row['text'] as String,
        mediaPath: row['media_path'] as String?,
        mediaKind: row['media_kind'] == null
            ? null
            : MediaKind.values.firstWhere(
                (k) => k.name == row['media_kind'],
                orElse: () => MediaKind.image,
              ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int),
        position: row['position'] as int,
      );
}
