import '../data/models/message.dart';

/// Render a list of messages in Gemma-4-Unsloth's `<|turn>{role}\n...<turn|>`
/// style. The trailing `<|turn>model\n` cues the model to generate.
///
/// If any user message has [Message.hasMedia], a `<__media__>` placeholder
/// is injected at the start of that turn's content — the multimodal context
/// replaces it with the actual media tokens during decode.
String renderGemma4(List<Message> messages, {String? systemOverride}) {
  final buf = StringBuffer();

  if (systemOverride != null && systemOverride.isNotEmpty) {
    buf
      ..write('<|turn>')
      ..writeln('system')
      ..write(systemOverride)
      ..writeln('<turn|>');
  }

  for (final m in messages) {
    final role = switch (m.role) {
      MessageRole.system => 'system',
      MessageRole.user => 'user',
      MessageRole.assistant => 'model',
    };
    if (systemOverride != null && m.role == MessageRole.system) {
      // Avoid double-system if both an override and a stored system message exist.
      continue;
    }
    buf
      ..write('<|turn>')
      ..writeln(role);
    if (m.hasMedia && m.role == MessageRole.user) {
      buf
        ..writeln('<__media__>')
        ..write(m.text);
    } else {
      buf.write(m.text);
    }
    buf.writeln('<turn|>');
  }

  buf
    ..write('<|turn>')
    ..writeln('model');
  return buf.toString();
}
