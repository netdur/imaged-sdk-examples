import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_services.dart';
import '../../data/models/conversation.dart';
import '../../data/models/model_bundle.dart';
import '../../llm/chat_controller.dart';
import '../../llm/engine_holder.dart';
import '../boot/boot_screen.dart';
import '../chat/chat_screen.dart';
import '../chat_list/chat_list_sidebar.dart';
import '../chat_list/new_chat_sheet.dart';
import '../common/design.dart';
import '../models/models_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_dialog.dart';

// Dev convenience: on macOS debug builds, auto-add a model from these paths
// if one is set. Override via:
//   flutter run -d macos \
//     --dart-define=AICHAT_DEV_MODEL=/abs/path/to/model.gguf \
//     --dart-define=AICHAT_DEV_MMPROJ=/abs/path/to/mmproj.gguf
const _devMacosModelPath =
    String.fromEnvironment('AICHAT_DEV_MODEL', defaultValue: '');
const _devMacosMmprojPath =
    String.fromEnvironment('AICHAT_DEV_MMPROJ', defaultValue: '');

enum _BootState { running, ready, empty, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _BootState _state = _BootState.running;
  String _phase = 'starting…';
  Object? _error;

  AppServices get svc => AppServices.instance;

  ModelBundle? _model;
  Conversation? _conversation;
  ChatController? _chat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _setPhase(String p) {
    if (!mounted) return;
    setState(() => _phase = p);
  }

  Future<void> _bootstrap() async {
    try {
      _setPhase('opening database');
      await AppServices.boot();

      _setPhase('ensuring default persona');
      await svc.personas.ensureDefault();

      _setPhase('locating model');
      _model = await _ensureSomeModel();
      if (_model == null) {
        if (mounted) setState(() => _state = _BootState.empty);
        return;
      }

      _setPhase('warming up engine');
      await EngineHolder.instance.activate(_model!);

      _setPhase('opening conversation');
      await _selectConversation(await _resumeOrCreateConversation());
      if (mounted) setState(() => _state = _BootState.ready);
    } catch (e, st) {
      debugPrint('bootstrap error: $e\n$st');
      if (mounted) {
        setState(() {
          _state = _BootState.error;
          _error = e;
        });
      }
    }
  }

  Future<ModelBundle?> _ensureSomeModel() async {
    final active = await svc.models.getActive();
    if (active != null) return active;
    final all = await svc.models.listAll();
    if (all.isNotEmpty) {
      await svc.models.setActive(all.first.id);
      return all.first;
    }
    if (kDebugMode && Platform.isMacOS) {
      final f = File(_devMacosModelPath);
      if (f.existsSync()) {
        return svc.models.add(
          name: 'Gemma-4-E2B-it-Q4_0 (dev)',
          modelPath: _devMacosModelPath,
          mmprojPath: File(_devMacosMmprojPath).existsSync()
              ? _devMacosMmprojPath
              : null,
          templateMode: TemplateMode.gemma4Manual,
          sizeBytes: f.lengthSync(),
        );
      }
    }
    return null;
  }

  Future<Conversation> _resumeOrCreateConversation() async {
    final all = await svc.conversations.listAll();
    for (final c in all) {
      if (c.modelId == _model!.id) return c;
    }
    final defaultPersona = (await svc.personas.listAll()).first;
    return svc.conversations.create(
      personaId: defaultPersona.id,
      modelId: _model!.id,
      title: 'New chat',
    );
  }

  Future<void> _selectConversation(Conversation c) async {
    if (_conversation?.id == c.id && _chat != null) return;
    final newPersona = await svc.personas.getById(c.personaId);
    final newModel = await svc.models.getById(c.modelId);
    if (newPersona == null || newModel == null) return;
    if (newModel.id != _model?.id) {
      _setPhase('switching model');
      await svc.models.setActive(newModel.id);
      await EngineHolder.instance.activate(newModel);
    }
    final old = _chat;
    final next = ChatController(
      conversation: c,
      persona: newPersona,
      repo: svc.conversations,
      engine: EngineHolder.instance,
    );
    await next.load();
    if (!mounted) return;
    setState(() {
      _conversation = c;
      _model = newModel;
      _chat = next;
    });
    await old?.dispose();
  }

  Future<void> _onNewChat() async {
    final convo = await showNewChatSheet(context);
    if (convo != null) await _selectConversation(convo);
  }

  void _onOpenSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          onPickConversation: (id) async {
            final c = await svc.conversations.getById(id);
            if (c != null) _selectConversation(c);
          },
        ),
      ),
    );
  }

  void _onOpenSettings() {
    showSettingsDialog(context);
  }

  void _onRetryBootstrap() {
    setState(() {
      _state = _BootState.running;
      _phase = 'retrying…';
      _error = null;
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _chat?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionFor(context, Motion.medium),
      switchInCurve: Motion.standard,
      child: switch (_state) {
        _BootState.running => BootScreen(
            key: const ValueKey('boot'),
            phase: _phase,
          ),
        _BootState.empty => _EmptyShell(
            key: const ValueKey('empty'),
            onSettings: _onOpenSettings,
          ),
        _BootState.error => BootScreen(
            key: const ValueKey('error'),
            phase: 'something broke',
            error: _error,
            onRetry: _onRetryBootstrap,
          ),
        _BootState.ready => _ReadyLayout(
            key: const ValueKey('ready'),
            activeId: _conversation?.id,
            chat: _chat,
            model: _model!,
            onSelect: (id) async {
              final c = await svc.conversations.getById(id);
              if (c != null) _selectConversation(c);
            },
            onNew: _onNewChat,
            onSearch: _onOpenSearch,
            onSettings: _onOpenSettings,
          ),
      },
    );
  }
}

class _ReadyLayout extends StatelessWidget {
  const _ReadyLayout({
    super.key,
    required this.activeId,
    required this.chat,
    required this.model,
    required this.onSelect,
    required this.onNew,
    required this.onSearch,
    required this.onSettings,
  });

  final String? activeId;
  final ChatController? chat;
  final ModelBundle model;
  final void Function(String) onSelect;
  final VoidCallback onNew;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          ChatListSidebar(
            activeConversationId: activeId,
            activeModel: model,
            onSelect: onSelect,
            onNew: onNew,
            onSearch: onSearch,
            onSettings: onSettings,
          ),
          Expanded(
            child: chat == null
                ? const Center(child: Text('No conversation selected'))
                : ChatScreen(chat: chat!, model: model),
          ),
        ],
      ),
    );
  }
}

class _EmptyShell extends StatelessWidget {
  const _EmptyShell({super.key, required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('aichat'),
        actions: [
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -200,
            left: -200,
            width: 600,
            height: 600,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.10),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(Insets.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: Brand.softGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(Icons.inventory_2_outlined,
                          size: 32, color: scheme.primary),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text('No models yet',
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: Insets.sm),
                    Text(
                      'Add a GGUF from disk or download from a URL to start chatting.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add a model'),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ModelsScreen(),
                        ));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
