enum TemplateMode {
  /// Manual `<|turn>{role}\n...<turn|>` rendering via EngineSession.
  /// Used for Gemma-4 family whose Jinja `llama_chat_apply_template` can't parse.
  gemma4Manual,

  /// Use EngineChat with the model's embedded Jinja template.
  engineChatBuiltin,
}

enum FlashAttnMode { auto, on, off }

/// A registered .gguf bundle. Carries the **engine-spawn-time** parameters
/// (context size, batch size, FlashAttention) — these are immutable for a
/// chat once the engine is spawned, so they live on the model registration.
///
/// Per-conversation runtime knobs (temperature etc.) live on Conversation,
/// not here.
class ModelBundle {
  ModelBundle({
    required this.id,
    required this.name,
    required this.modelPath,
    this.mmprojPath,
    required this.templateMode,
    this.sizeBytes,
    this.sourceUrl,
    required this.addedAt,
    this.nCtx = 2048,
    this.nBatch = 512,
    this.nUbatch = 512,
    this.flashAttn = FlashAttnMode.auto,
  });

  final String id;
  final String name;
  final String modelPath;
  final String? mmprojPath;
  final TemplateMode templateMode;
  final int? sizeBytes;
  final String? sourceUrl;
  final DateTime addedAt;

  // Engine-spawn-time params (per model, not per chat).
  final int nCtx;
  final int nBatch;
  final int nUbatch;
  final FlashAttnMode flashAttn;

  bool get hasMmproj => mmprojPath != null;

  ModelBundle copyWith({
    String? name,
    String? mmprojPath,
    TemplateMode? templateMode,
    int? nCtx,
    int? nBatch,
    int? nUbatch,
    FlashAttnMode? flashAttn,
  }) =>
      ModelBundle(
        id: id,
        name: name ?? this.name,
        modelPath: modelPath,
        mmprojPath: mmprojPath ?? this.mmprojPath,
        templateMode: templateMode ?? this.templateMode,
        sizeBytes: sizeBytes,
        sourceUrl: sourceUrl,
        addedAt: addedAt,
        nCtx: nCtx ?? this.nCtx,
        nBatch: nBatch ?? this.nBatch,
        nUbatch: nUbatch ?? this.nUbatch,
        flashAttn: flashAttn ?? this.flashAttn,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'model_path': modelPath,
        'mmproj_path': mmprojPath,
        'template_mode': templateMode.name,
        'size_bytes': sizeBytes,
        'source_url': sourceUrl,
        'added_at': addedAt.millisecondsSinceEpoch,
        'n_ctx': nCtx,
        'n_batch': nBatch,
        'n_ubatch': nUbatch,
        'flash_attn': flashAttn.name,
      };

  factory ModelBundle.fromRow(Map<String, Object?> row) => ModelBundle(
        id: row['id'] as String,
        name: row['name'] as String,
        modelPath: row['model_path'] as String,
        mmprojPath: row['mmproj_path'] as String?,
        templateMode: TemplateMode.values.firstWhere(
          (m) => m.name == row['template_mode'],
          orElse: () => TemplateMode.gemma4Manual,
        ),
        sizeBytes: row['size_bytes'] as int?,
        sourceUrl: row['source_url'] as String?,
        addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at'] as int),
        nCtx: (row['n_ctx'] as int?) ?? 2048,
        nBatch: (row['n_batch'] as int?) ?? 512,
        nUbatch: (row['n_ubatch'] as int?) ?? 512,
        flashAttn: FlashAttnMode.values.firstWhere(
          (m) => m.name == row['flash_attn'],
          orElse: () => FlashAttnMode.auto,
        ),
      );
}
