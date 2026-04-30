import 'package:flutter/material.dart';

import '../../data/app_services.dart';
import '../../data/models/persona.dart';
import '../common/confirm_dialog.dart';
import 'persona_edit_sheet.dart';

class PersonasScreen extends StatefulWidget {
  const PersonasScreen({super.key, this.embedded = false});

  /// When true, the screen renders without its own Scaffold/AppBar so it
  /// can be embedded inside the settings dialog.
  final bool embedded;

  @override
  State<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends State<PersonasScreen> {
  AppServices get svc => AppServices.instance;

  @override
  void initState() {
    super.initState();
    svc.personas.addListener(_onChange);
  }

  @override
  void dispose() {
    svc.personas.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _delete(Persona p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete persona?',
      message:
          '"${p.name}" will be removed. Existing conversations using this '
          'persona will keep their messages but the persona name will read as "(deleted)".',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await svc.personas.delete(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final body = _Body(onDelete: _delete);
    if (widget.embedded) {
      return Column(
        children: [
          _ToolbarRow(
            onAdd: () => showPersonaEditSheet(context, persona: null),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New persona',
            onPressed: () => showPersonaEditSheet(context, persona: null),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New persona'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.onDelete});
  final void Function(Persona) onDelete;

  @override
  Widget build(BuildContext context) {
    final svc = AppServices.instance;
    return FutureBuilder(
      future: svc.personas.listAll(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final personas = snap.data!;
        if (personas.isEmpty) return const _Empty();
        return ListView.separated(
          itemCount: personas.length,
          separatorBuilder: (_, _) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final p = personas[i];
            return _PersonaTile(
              persona: p,
              onEdit: () => showPersonaEditSheet(context, persona: p),
              onDelete: () => onDelete(p),
            );
          },
        );
      },
    );
  }
}

class _PersonaTile extends StatelessWidget {
  const _PersonaTile({
    required this.persona,
    required this.onEdit,
    required this.onDelete,
  });
  final Persona persona;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        child: Text(persona.emoji ?? '💬'),
      ),
      title: Text(persona.name),
      subtitle: Text(
        persona.systemPrompt.isEmpty ? '(no system prompt)' : persona.systemPrompt,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onEdit,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          switch (v) {
            case 'edit':
              onEdit();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.theater_comedy_outlined,
                  size: 56, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No personas yet', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'A persona is a system prompt + identity (name, emoji) — how '
                'the model should act in a conversation.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New persona'),
                onPressed: () => showPersonaEditSheet(context, persona: null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
