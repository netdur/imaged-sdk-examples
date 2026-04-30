import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/app_services.dart';
import '../../data/models/model_bundle.dart';
import '../../llm/engine_holder.dart';
import '../common/confirm_dialog.dart';
import '../common/inline_error.dart';
import 'add_model_sheet.dart';
import 'model_edit_sheet.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  String? _error;
  bool _switching = false;

  AppServices get svc => AppServices.instance;

  @override
  void initState() {
    super.initState();
    svc.models.addListener(_onChange);
  }

  @override
  void dispose() {
    svc.models.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _setActive(ModelBundle m) async {
    final current = await svc.models.getActive();
    if (current?.id == m.id) return;
    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      await svc.models.setActive(m.id);
      await EngineHolder.instance.activate(m);
    } catch (e) {
      setState(() => _error = 'Switch failed: $e');
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _delete(ModelBundle m) async {
    final inUse = await svc.models.conversationCountForModel(m.id);
    if (!mounted) return;
    if (inUse > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Model in use'),
          content: Text(
              '${m.name} is used by $inUse conversation${inUse == 1 ? "" : "s"}. '
              'Delete those conversations first.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Delete model?',
      message:
          '${m.name} will be removed from the registry. The .gguf file '
          '${_isInsideAppDocs(m.modelPath) ? "will also be deleted" : "will not be deleted (it lives outside the app)"}.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await svc.models.remove(m.id);
      if (_isInsideAppDocs(m.modelPath)) {
        await File(m.modelPath).delete().catchError((_) => File(m.modelPath));
      }
    } catch (e) {
      setState(() => _error = 'Delete failed: $e');
    }
  }

  bool _isInsideAppDocs(String path) {
    return path.contains('/Documents/models/');
  }

  Future<void> _edit(ModelBundle m) async {
    final updated = await showModelEditSheet(context, model: m);
    if (updated == null) return;
    await svc.models.update(updated);
    final activeId = await svc.models.getActiveId();
    if (activeId == m.id) {
      // Re-spawn engine with new context params.
      try {
        await EngineHolder.instance.activate(updated);
      } catch (e) {
        if (mounted) setState(() => _error = 'Re-activate failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) {
      return Column(
        children: [
          _ToolbarRow(onAdd: () => showAddModelSheet(context)),
          if (_switching) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InlineError(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
            ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add model',
            onPressed: () => showAddModelSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: InlineError(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
            ),
          if (_switching) const LinearProgressIndicator(),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder(
      future: svc.models.listAll(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final models = snap.data!;
        if (models.isEmpty) return const _Empty();
        return FutureBuilder<String?>(
          future: svc.models.getActiveId(),
          builder: (context, idSnap) {
            final activeId = idSnap.data;
            return ListView.separated(
              itemCount: models.length,
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, i) {
                final m = models[i];
                return _ModelTile(
                  model: m,
                  isActive: m.id == activeId,
                  enabled: !_switching,
                  onActivate: () => _setActive(m),
                  onEdit: () => _edit(m),
                  onDelete: () => _delete(m),
                );
              },
            );
          },
        );
      },
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
            label: const Text('Add model'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.isActive,
    required this.enabled,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
  });

  final ModelBundle model;
  final bool isActive;
  final bool enabled;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = model.sizeBytes;
    return ListTile(
      onTap: onEdit,
      leading: Icon(
        Icons.memory,
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(model.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  )),
            ),
        ],
      ),
      subtitle: Text(
        [
          if (size != null) _formatBytes(size),
          if (model.hasMmproj) 'mmproj',
          'ctx ${model.nCtx}',
          model.templateMode.name,
        ].join(' · '),
        style: theme.textTheme.bodySmall,
      ),
      trailing: PopupMenuButton<String>(
        enabled: enabled,
        onSelected: (v) {
          switch (v) {
            case 'activate':
              onActivate();
            case 'edit':
              onEdit();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (_) => [
          if (!isActive)
            const PopupMenuItem(
                value: 'activate', child: Text('Make active')),
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
              Icon(Icons.inventory_2_outlined,
                  size: 56, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No models yet', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Add a GGUF from disk or download from a URL to start chatting.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add a model'),
                onPressed: () => showAddModelSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / 1024 / 1024).toStringAsFixed(0)} MB';
  }
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
