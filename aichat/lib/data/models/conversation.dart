/// A conversation is locked to one persona AND one model at creation. It
/// also carries its own runtime sampler settings (temperature, top_p, max
/// tokens) which the user can tweak mid-chat.
class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.personaId,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
    this.samplerTemp = 0.7,
    this.samplerTopP = 0.9,
    this.samplerMaxTokens = 512,
  });

  final String id;
  final String title;
  final String personaId;
  final String modelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Runtime sampler params, editable from the chat screen at any time.
  final double samplerTemp;
  final double samplerTopP;
  final int samplerMaxTokens;

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    double? samplerTemp,
    double? samplerTopP,
    int? samplerMaxTokens,
  }) =>
      Conversation(
        id: id,
        title: title ?? this.title,
        personaId: personaId,
        modelId: modelId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        samplerTemp: samplerTemp ?? this.samplerTemp,
        samplerTopP: samplerTopP ?? this.samplerTopP,
        samplerMaxTokens: samplerMaxTokens ?? this.samplerMaxTokens,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'persona_id': personaId,
        'model_id': modelId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'sampler_temp': samplerTemp,
        'sampler_top_p': samplerTopP,
        'sampler_max_tokens': samplerMaxTokens,
      };

  factory Conversation.fromRow(Map<String, Object?> row) => Conversation(
        id: row['id'] as String,
        title: row['title'] as String,
        personaId: row['persona_id'] as String,
        modelId: row['model_id'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        samplerTemp: (row['sampler_temp'] as num?)?.toDouble() ?? 0.7,
        samplerTopP: (row['sampler_top_p'] as num?)?.toDouble() ?? 0.9,
        samplerMaxTokens: (row['sampler_max_tokens'] as int?) ?? 512,
      );
}
