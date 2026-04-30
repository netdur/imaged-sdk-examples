import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/app_services.dart';
import '../../data/models/model_bundle.dart';
import '../../llm/download_client.dart';
import '../../llm/platform_paths.dart';
import '../common/inline_error.dart';
import 'context_params_form.dart';

Future<void> showAddModelSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AddModelSheet(),
  );
}

class _AddModelSheet extends StatefulWidget {
  const _AddModelSheet();

  @override
  State<_AddModelSheet> createState() => _AddModelSheetState();
}

class _AddModelSheetState extends State<_AddModelSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Row(
                children: [
                  Text('Add a model',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'From file', icon: Icon(Icons.folder_open, size: 18)),
                Tab(text: 'From URL', icon: Icon(Icons.cloud_download, size: 18)),
              ],
            ),
            Flexible(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _LocalFileTab(),
                  _UrlTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalFileTab extends StatefulWidget {
  const _LocalFileTab();

  @override
  State<_LocalFileTab> createState() => _LocalFileTabState();
}

class _LocalFileTabState extends State<_LocalFileTab> {
  String? _modelPath;
  String? _mmprojPath;
  bool _copyIntoApp = true;
  TemplateMode _template = TemplateMode.gemma4Manual;
  ContextParamsValue _ctx = ContextParamsValue.defaults();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pick a GGUF model',
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _modelPath = path;
      if (_name.text.isEmpty) {
        _name.text = p.basenameWithoutExtension(path);
      }
    });
  }

  Future<void> _pickMmproj() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pick an mmproj (optional)',
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _mmprojPath = path);
  }

  Future<void> _add() async {
    if (_modelPath == null || _name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var modelPath = _modelPath!;
      var mmprojPath = _mmprojPath;
      if (_copyIntoApp) {
        final modelsDir = await getModelsDir();
        final modelDest = p.join(modelsDir, p.basename(modelPath));
        await File(modelPath).copy(modelDest);
        modelPath = modelDest;
        if (mmprojPath != null) {
          final mmDest = p.join(modelsDir, p.basename(mmprojPath));
          await File(mmprojPath).copy(mmDest);
          mmprojPath = mmDest;
        }
      }
      final size = File(modelPath).statSync().size;
      await AppServices.instance.models.add(
        name: _name.text.trim(),
        modelPath: modelPath,
        mmprojPath: mmprojPath,
        templateMode: _template,
        sizeBytes: size,
        nCtx: _ctx.nCtx,
        nBatch: _ctx.nBatch,
        nUbatch: _ctx.nUbatch,
        flashAttn: _ctx.flashAttn,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _modelPath != null && _name.text.trim().isNotEmpty && !_busy;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _PathRow(
          label: 'Model file (.gguf)',
          path: _modelPath,
          onPick: _pickModel,
        ),
        const SizedBox(height: 16),
        _PathRow(
          label: 'Multimodal projector (.gguf, optional)',
          path: _mmprojPath,
          onPick: _pickMmproj,
          onClear: _mmprojPath == null
              ? null
              : () => setState(() => _mmprojPath = null),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Display name',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
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
        Text('Engine spawn parameters',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ContextParamsForm(
          value: _ctx,
          onChanged: (v) => setState(() => _ctx = v),
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Copy file into app'),
          subtitle: const Text(
              'Recommended. Otherwise the registry holds an absolute '
              'path that may break if you move the file.'),
          value: _copyIntoApp,
          onChanged: (v) => setState(() => _copyIntoApp = v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          InlineError(message: _error!),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: canSubmit ? _add : null,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add model'),
        ),
      ],
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.label,
    required this.path,
    required this.onPick,
    this.onClear,
  });
  final String label;
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
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  path == null ? 'No file selected' : path!.split('/').last,
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

class _UrlTab extends StatefulWidget {
  const _UrlTab();

  @override
  State<_UrlTab> createState() => _UrlTabState();
}

class _UrlTabState extends State<_UrlTab> {
  final _url = TextEditingController(
    text:
        'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_0.gguf',
  );
  final _mmprojUrl = TextEditingController();
  final _name = TextEditingController(text: 'Gemma-4-E2B Q4_0');
  TemplateMode _template = TemplateMode.gemma4Manual;
  ContextParamsValue _ctx = ContextParamsValue.defaults();
  bool _busy = false;
  DownloadProgress? _progress;
  String? _error;
  FileDownload? _modelDl;
  FileDownload? _mmprojDl;

  @override
  void dispose() {
    _url.dispose();
    _mmprojUrl.dispose();
    _name.dispose();
    _modelDl?.cancel();
    _mmprojDl?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final urlStr = _url.text.trim();
    final name = _name.text.trim();
    if (urlStr.isEmpty || name.isEmpty) return;
    Uri url;
    try {
      url = Uri.parse(urlStr);
    } catch (_) {
      setState(() => _error = 'Invalid URL');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });

    try {
      final modelsDir = await getModelsDir();
      final modelFile = p.basename(url.path).isEmpty
          ? '${name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), "_")}.gguf'
          : p.basename(url.path);
      final modelDest = p.join(modelsDir, modelFile);

      _modelDl = FileDownload(url: url, destPath: modelDest);
      final modelSub = _modelDl!.progress.listen((pr) {
        if (mounted) setState(() => _progress = pr);
      });
      await _modelDl!.run();
      await modelSub.cancel();

      String? mmprojDest;
      if (_mmprojUrl.text.trim().isNotEmpty) {
        final mUrl = Uri.parse(_mmprojUrl.text.trim());
        final mFile = p.basename(mUrl.path).isEmpty
            ? 'mmproj.gguf'
            : p.basename(mUrl.path);
        mmprojDest = p.join(modelsDir, mFile);
        _mmprojDl = FileDownload(url: mUrl, destPath: mmprojDest);
        final mSub = _mmprojDl!.progress.listen((pr) {
          if (mounted) setState(() => _progress = pr);
        });
        await _mmprojDl!.run();
        await mSub.cancel();
      }

      final size = File(modelDest).statSync().size;
      await AppServices.instance.models.add(
        name: name,
        modelPath: modelDest,
        mmprojPath: mmprojDest,
        templateMode: _template,
        sizeBytes: size,
        sourceUrl: urlStr,
        nCtx: _ctx.nCtx,
        nBatch: _ctx.nBatch,
        nUbatch: _ctx.nUbatch,
        flashAttn: _ctx.flashAttn,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _modelDl = null;
          _mmprojDl = null;
        });
      }
    }
  }

  void _cancel() {
    _modelDl?.cancel();
    _mmprojDl?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final pr = _progress;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _url,
          decoration: const InputDecoration(
            labelText: 'Model URL',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _mmprojUrl,
          decoration: const InputDecoration(
            labelText: 'mmproj URL (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Display name',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TemplateMode>(
          initialValue: _template,
          decoration: const InputDecoration(
            labelText: 'Chat template',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
                value: TemplateMode.gemma4Manual,
                child: Text('Gemma-4 manual')),
            DropdownMenuItem(
                value: TemplateMode.engineChatBuiltin,
                child: Text('Built-in')),
          ],
          onChanged: (v) =>
              setState(() => _template = v ?? TemplateMode.gemma4Manual),
        ),
        const SizedBox(height: 16),
        Text('Engine spawn parameters',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ContextParamsForm(
          value: _ctx,
          onChanged: (v) => setState(() => _ctx = v),
        ),
        if (pr != null) ...[
          const SizedBox(height: 24),
          LinearProgressIndicator(value: pr.fraction),
          const SizedBox(height: 6),
          Text(_progressLabel(pr),
              style: Theme.of(context).textTheme.bodySmall),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          InlineError(message: _error!),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _start,
                child: _busy
                    ? const Text('Downloading…')
                    : const Text('Download & add'),
              ),
            ),
            if (_busy) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
            ],
          ],
        ),
      ],
    );
  }

  String _progressLabel(DownloadProgress p) {
    final mb = p.bytesDownloaded / 1024 / 1024;
    final tot = p.bytesTotal == null
        ? '?'
        : '${(p.bytesTotal! / 1024 / 1024).toStringAsFixed(0)} MB';
    final rate = p.bytesPerSecond / 1024 / 1024;
    final pct = p.fraction == null
        ? '?'
        : '${(p.fraction! * 100).toStringAsFixed(0)}%';
    return '$pct · ${mb.toStringAsFixed(0)} / $tot · ${rate.toStringAsFixed(1)} MB/s';
  }
}
