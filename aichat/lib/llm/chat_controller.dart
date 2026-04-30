import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart' hide MediaKind;

import '../data/models/conversation.dart';
import '../data/models/message.dart';
import '../data/models/persona.dart';
import '../data/repos/conversations_repo.dart';
import 'engine_holder.dart';
import 'prompt_render.dart';

enum ChatPhase { idle, generating, error }

/// Drives one conversation: streams an assistant reply, persists it to
/// SQLite, and exposes the running message list as a [ChangeNotifier].
class ChatController extends ChangeNotifier {
  ChatController({
    required Conversation conversation,
    required this.persona,
    required ConversationsRepo repo,
    required EngineHolder engine,
  })  : _conversation = conversation,
        _repo = repo,
        _engine = engine;

  Conversation _conversation;
  Conversation get conversation => _conversation;
  final Persona persona;
  final ConversationsRepo _repo;
  final EngineHolder _engine;

  /// Update the per-conversation sampler params. Persists to DB and
  /// applies to the next generation.
  Future<void> updateSampler({
    required double temperature,
    required double topP,
    required int maxTokens,
  }) async {
    await _repo.updateSampler(
      _conversation.id,
      temp: temperature,
      topP: topP,
      maxTokens: maxTokens,
    );
    _conversation = _conversation.copyWith(
      samplerTemp: temperature,
      samplerTopP: topP,
      samplerMaxTokens: maxTokens,
    );
    notifyListeners();
  }

  final List<Message> _messages = [];
  List<Message> get messages => List.unmodifiable(_messages);

  ChatPhase _phase = ChatPhase.idle;
  ChatPhase get phase => _phase;

  /// Streaming text accumulated for the in-flight assistant message.
  /// Empty when not generating.
  final StringBuffer _streaming = StringBuffer();
  String get streamingText => _streaming.toString();

  /// Token count + timing for the in-flight generation.
  int _tokensGenerated = 0;
  int get tokensGenerated => _tokensGenerated;
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;
  double get tokensPerSecond {
    if (_elapsed.inMilliseconds == 0) return 0;
    return _tokensGenerated * 1000 / _elapsed.inMilliseconds;
  }

  Object? _error;
  Object? get error => _error;

  StreamSubscription<GenerationEvent>? _sub;
  EngineSession? _session;
  Stopwatch? _watch;
  Timer? _persistTimer;
  Message? _inFlight;

  /// Load existing messages from SQLite. Call once after construction.
  Future<void> load() async {
    final existing = await _repo.listMessages(_conversation.id);
    _messages
      ..clear()
      ..addAll(existing);
    notifyListeners();
  }

  /// Send a user turn. Optionally attach media (image or audio).
  Future<void> send(
    String text, {
    String? mediaPath,
    MediaKind? mediaKind,
  }) async {
    if (_phase == ChatPhase.generating) return;
    final eng = _engine.engine;
    if (eng == null) {
      _phase = ChatPhase.error;
      _error = StateError('no engine active');
      notifyListeners();
      return;
    }

    // 1. Append + persist the user message.
    final user = await _repo.addMessage(
      conversationId: _conversation.id,
      role: MessageRole.user,
      text: text,
      mediaPath: mediaPath,
      mediaKind: mediaKind,
    );
    _messages.add(user);

    // 2. Create + persist the (empty) assistant message we'll stream into.
    final assistant = await _repo.addMessage(
      conversationId: _conversation.id,
      role: MessageRole.assistant,
      text: '',
    );
    _messages.add(assistant);
    _inFlight = assistant;
    _streaming.clear();
    _tokensGenerated = 0;
    _elapsed = Duration.zero;
    _phase = ChatPhase.generating;
    _error = null;
    notifyListeners();

    // 3. Build the prompt and start generating.
    final prompt = renderGemma4(
      _messages.where((m) => m.id != assistant.id).toList(),
      systemOverride: persona.systemPrompt.isEmpty ? null : persona.systemPrompt,
    );

    final media = <LlamaMedia>[];
    if (user.hasMedia && user.mediaKind == MediaKind.image) {
      media.add(LlamaMedia.imageFile(user.mediaPath!));
    } else if (user.hasMedia && user.mediaKind == MediaKind.audio) {
      media.add(LlamaMedia.audioFile(user.mediaPath!));
    }

    final sampler = SamplerParams(
      temperature: _conversation.samplerTemp,
      topP: _conversation.samplerTopP,
    );
    final maxTokens = _conversation.samplerMaxTokens;

    _session = await eng.createSession();
    _watch = Stopwatch()..start();
    _persistTimer = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _flushStreaming());

    final stream = _session!.generate(
      prompt: prompt,
      addSpecial: true,
      parseSpecial: true,
      sampler: sampler,
      maxTokens: maxTokens,
      media: media,
    );

    _sub = stream.listen(
      _onEvent,
      onDone: _onStreamDone,
      onError: _onStreamError,
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _finalizeGeneration();
  }

  void _onEvent(GenerationEvent ev) {
    switch (ev) {
      case TokenEvent():
        _tokensGenerated += 1;
        _streaming.write(ev.text);
        _elapsed = _watch?.elapsed ?? Duration.zero;
        notifyListeners();
      case ShiftEvent():
        // KV shifted; nothing UI-side to do.
        break;
      case DoneEvent():
        if (ev.trailingText.isNotEmpty) _streaming.write(ev.trailingText);
        _elapsed = _watch?.elapsed ?? Duration.zero;
    }
  }

  Future<void> _onStreamDone() async {
    await _finalizeGeneration();
  }

  void _onStreamError(Object e, StackTrace st) async {
    _error = e;
    _phase = ChatPhase.error;
    await _finalizeGeneration();
  }

  Future<void> _finalizeGeneration() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    _watch?.stop();
    await _flushStreaming();
    final session = _session;
    _session = null;
    _sub = null;
    _inFlight = null;
    if (_phase == ChatPhase.generating) _phase = ChatPhase.idle;
    notifyListeners();
    await session?.dispose();
  }

  /// Persist whatever's accumulated for the in-flight assistant message.
  /// Called every 500 ms during streaming, plus once at generation end.
  Future<void> _flushStreaming() async {
    final m = _inFlight;
    if (m == null) return;
    final text = _streaming.toString();
    if (text.isEmpty) return;
    // Update both the in-memory message and the DB row.
    final idx = _messages.indexWhere((x) => x.id == m.id);
    if (idx >= 0) {
      _messages[idx] = Message(
        id: m.id,
        conversationId: m.conversationId,
        role: m.role,
        text: text,
        mediaPath: m.mediaPath,
        mediaKind: m.mediaKind,
        createdAt: m.createdAt,
        position: m.position,
      );
    }
    await _repo.updateMessageText(m.id, text);
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _persistTimer?.cancel();
    _watch?.stop();
    await _session?.dispose();
    super.dispose();
  }
}
