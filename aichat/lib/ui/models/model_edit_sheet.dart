import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/models/model_bundle.dart';
import 'context_params_form.dart';

/// Edit an existing model. Returns the updated bundle (caller persists)
/// or null if cancelled.
Future<ModelBundle?> showModelEditSheet(
  BuildContext context, {
  required ModelBundle model,
}) {
  return showModalBottomSheet<ModelBundle?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ModelEditSheet(model: model),
  );
}

class _ModelEditSheet extends StatefulWidget {
  const _ModelEditSheet({required this.model});
  final ModelBundle model;

  @override
  State<_ModelEditSheet> createState() => _ModelEditSheetState();
}

class _ModelEditSheetState extends State<_ModelEditSheet> {
  late final TextEditingController _name;
  late TemplateMode _template;
  late String? _mmproj;
  late ContextParamsValue _ctxParams;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _name = TextEditingController(text: m.name);
    _template = m.templateMode;
    _mmproj = m.mmprojPath;
    _ctxParams = ContextParamsValue.fromBundle(m);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickMmproj() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pick an mmproj (optional)',
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _mmproj = path);
  }

  void _save() {
    final updated = widget.model.copyWith(
      name: _name.text.trim().isEmpty ? widget.model.name : _name.text.trim(),
      templateMode: _template,
      mmprojPath: _mmproj,
      nCtx: _ctxParams.nCtx,
      nBatch: _ctxParams.nBatch,
      nUbatch: _ctxParams.nUbatch,
      flashAttn: _ctxParams.flashAttn,
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Row(
              children: [
                Text('Edit model', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Engine-spawn-time params (context size, batch, FlashAttention) '
              'live on the model. Changes re-spawn the engine if this is the '
              'active model. Sampler knobs (temperature etc.) are per-chat.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TemplateMode>(
              initialValue: _template,
              decoration: const InputDecoration(
                labelText: 'Chat template',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: TemplateMode.gemma4Manual,
                    child: Text('Gemma-4 manual (<|turn> markers)')),
                DropdownMenuItem(
                    value: TemplateMode.engineChatBuiltin,
                    child: Text("Built-in (model's embedded Jinja)")),
              ],
              onChanged: (v) =>
                  setState(() => _template = v ?? TemplateMode.gemma4Manual),
            ),
            const SizedBox(height: 16),
            _MmprojRow(
              path: _mmproj,
              onPick: _pickMmproj,
              onClear:
                  _mmproj == null ? null : () => setState(() => _mmproj = null),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Engine spawn parameters',
                  style: theme.textTheme.titleSmall),
            ),
            ContextParamsForm(
              value: _ctxParams,
              onChanged: (v) => setState(() => _ctxParams = v),
            ),
            const SizedBox(height: 24),
            Text(
              'Read-only',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            _ReadOnlyRow(label: 'Path', value: widget.model.modelPath),
            if (widget.model.sourceUrl != null)
              _ReadOnlyRow(label: 'Source URL', value: widget.model.sourceUrl!),
            if (widget.model.sizeBytes != null)
              _ReadOnlyRow(
                label: 'Size',
                value:
                    '${(widget.model.sizeBytes! / 1024 / 1024).toStringAsFixed(0)} MB',
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save changes')),
          ],
        ),
      ),
    );
  }
}

class _MmprojRow extends StatelessWidget {
  const _MmprojRow({required this.path, required this.onPick, this.onClear});
  final String? path;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Multimodal projector (.gguf, optional)',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  path == null
                      ? 'No mmproj attached'
                      : path!.split(Platform.pathSeparator).last,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(icon: const Icon(Icons.close), onPressed: onClear),
          TextButton(onPressed: onPick, child: const Text('Pick')),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
