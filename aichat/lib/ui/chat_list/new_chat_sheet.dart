import 'package:flutter/material.dart';

import '../../data/app_services.dart';
import '../../data/models/conversation.dart';
import '../../data/models/model_bundle.dart';
import '../../data/models/persona.dart';

/// Returns the newly created [Conversation], or null if cancelled.
Future<Conversation?> showNewChatSheet(BuildContext context) {
  return showModalBottomSheet<Conversation?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _NewChatSheet(),
  );
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  Persona? _persona;
  ModelBundle? _model;
  bool _busy = false;

  AppServices get svc => AppServices.instance;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    final personas = await svc.personas.listAll();
    final activeModel = await svc.models.getActive();
    if (!mounted) return;
    setState(() {
      _persona = personas.isEmpty ? null : personas.first;
      _model = activeModel;
    });
  }

  Future<void> _create() async {
    if (_persona == null || _model == null) return;
    setState(() => _busy = true);
    final convo = await svc.conversations.create(
      personaId: _persona!.id,
      modelId: _model!.id,
      title: 'New chat',
    );
    if (mounted) Navigator.of(context).pop(convo);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: FutureBuilder(
          future: _load(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final (personas, models) = snap.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('New chat',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _PersonaPicker(
                  personas: personas,
                  selected: _persona,
                  onSelect: (p) => setState(() => _persona = p),
                ),
                const SizedBox(height: 16),
                if (models.length > 1)
                  _ModelPicker(
                    models: models,
                    selected: _model,
                    onSelect: (m) => setState(() => _model = m),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (_persona == null || _model == null || _busy)
                      ? null
                      : _create,
                  child: _busy
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Start chat'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<(List<Persona>, List<ModelBundle>)> _load() async {
    final ps = await svc.personas.listAll();
    final ms = await svc.models.listAll();
    return (ps, ms);
  }
}

class _PersonaPicker extends StatelessWidget {
  const _PersonaPicker({
    required this.personas,
    required this.selected,
    required this.onSelect,
  });

  final List<Persona> personas;
  final Persona? selected;
  final void Function(Persona) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Persona', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in personas)
              ChoiceChip(
                avatar: Text(p.emoji ?? '💬'),
                label: Text(p.name),
                selected: p.id == selected?.id,
                onSelected: (_) => onSelect(p),
              ),
          ],
        ),
      ],
    );
  }
}

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.models,
    required this.selected,
    required this.onSelect,
  });

  final List<ModelBundle> models;
  final ModelBundle? selected;
  final void Function(ModelBundle) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Model', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final m in models)
              DropdownMenuItem(
                value: m.id,
                child: Text(m.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            if (id == null) return;
            final m = models.firstWhere((x) => x.id == id);
            onSelect(m);
          },
        ),
      ],
    );
  }
}
