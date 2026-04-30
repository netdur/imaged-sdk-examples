import 'package:flutter/material.dart';

import '../../data/app_services.dart';
import '../../data/models/persona.dart';

Future<void> showPersonaEditSheet(BuildContext context,
    {required Persona? persona}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PersonaEditSheet(persona: persona),
  );
}

class _PersonaEditSheet extends StatefulWidget {
  const _PersonaEditSheet({required this.persona});
  final Persona? persona;

  @override
  State<_PersonaEditSheet> createState() => _PersonaEditSheetState();
}

class _PersonaEditSheetState extends State<_PersonaEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _emoji;
  late final TextEditingController _prompt;

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _name = TextEditingController(text: p?.name ?? '');
    _emoji = TextEditingController(text: p?.emoji ?? '');
    _prompt = TextEditingController(text: p?.systemPrompt ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final emoji = _emoji.text.trim().isEmpty ? null : _emoji.text.trim();
    final repo = AppServices.instance.personas;
    if (widget.persona == null) {
      await repo.create(
        name: name,
        emoji: emoji,
        systemPrompt: _prompt.text,
      );
    } else {
      final p = widget.persona!;
      await repo.update(Persona(
        id: p.id,
        name: name,
        emoji: emoji,
        systemPrompt: _prompt.text,
        createdAt: p.createdAt,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNew = widget.persona == null;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Row(
              children: [
                Text(isNew ? 'New persona' : 'Edit persona',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'A persona pins a system prompt + identity to a chat — how the '
              'model should act. Sampler knobs (temperature etc.) live on the '
              'chat itself and can be tuned mid-conversation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _emoji,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(
                      labelText: 'Emoji',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _prompt,
              decoration: const InputDecoration(
                labelText: 'System prompt',
                border: OutlineInputBorder(),
                helperText:
                    'Sent verbatim as the system message. Describe the role, tone, constraints — whatever defines this persona.',
              ),
              maxLines: 12,
              minLines: 6,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(isNew ? 'Create' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
