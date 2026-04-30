/// A persona pins a system prompt + identity (name, emoji) to a chat.
/// It captures *how* the model should act — its role, tone, personality.
/// Sampler knobs (temperature etc.) are NOT part of a persona; those are
/// per-conversation runtime settings.
class Persona {
  Persona({
    required this.id,
    required this.name,
    this.emoji,
    required this.systemPrompt,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? emoji;
  final String systemPrompt;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'system_prompt': systemPrompt,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Persona.fromRow(Map<String, Object?> row) => Persona(
        id: row['id'] as String,
        name: row['name'] as String,
        emoji: row['emoji'] as String?,
        systemPrompt: row['system_prompt'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );
}
