import 'package:flutter/material.dart';

import '../../data/models/message.dart';
import '../../data/models/model_bundle.dart';
import '../../data/app_services.dart';
import '../../llm/chat_controller.dart';
import '../common/design.dart';
import 'chat_header.dart';
import 'composer.dart';
import 'message_bubble.dart';
import 'sampler_popover.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    required this.model,
    this.onOpenSidebar,
  });

  final ChatController chat;
  final ModelBundle model;
  final VoidCallback? onOpenSidebar;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant ChatScreen old) {
    super.didUpdateWidget(old);
    if (old.chat != widget.chat) {
      old.chat.removeListener(_onChange);
      widget.chat.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.chat.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.pixels > pos.maxScrollExtent - 160) {
        _scroll.jumpTo(pos.maxScrollExtent);
      }
    });
    setState(() {});
  }

  Future<void> _renameChat(String next) async {
    await AppServices.instance.conversations.rename(
      widget.chat.conversation.id,
      next,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chat = widget.chat;
    final messages = chat.messages;
    final isGenerating = chat.phase == ChatPhase.generating;
    final lastAssistantId = _lastAssistantId(messages);

    return Stack(
      fit: StackFit.expand,
      children: [
        const _ChatBackground(),
        SafeArea(
          child: Column(
          children: [
            ChatHeader(
              chat: chat,
              model: widget.model,
              onOpenSidebar: widget.onOpenSidebar,
              onRename: _renameChat,
              onAdjust: () => showSamplerPopover(context, chat: chat),
            ),
            if (chat.error != null)
              _ErrorBanner(
                message: chat.error.toString(),
                onDismiss: () => setState(() {}),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: motionFor(context, Motion.medium),
                switchInCurve: Motion.standard,
                switchOutCurve: Motion.standard,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: messages.isEmpty
                    ? _EmptyChat(
                        key: ValueKey('empty-${chat.conversation.id}'),
                        personaName: chat.persona.name,
                        personaEmoji: chat.persona.emoji ?? '✨',
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        key: ValueKey('list-${chat.conversation.id}'),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Scrollbar(
                            controller: _scroll,
                            child: ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(
                                Insets.lg,
                                Insets.lg,
                                Insets.lg,
                                Insets.xl,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, i) {
                                final m = messages[i];
                                final isLast = m.id == lastAssistantId;
                                final isStreamingThis = isGenerating && isLast;
                                final waiting =
                                    isStreamingThis &&
                                    chat.tokensGenerated == 0 &&
                                    m.text.isEmpty;
                                return MessageBubble(
                                  key: ValueKey(m.id),
                                  message: m,
                                  persona: chat.persona,
                                  streaming: isStreamingThis,
                                  streamingText: isStreamingThis
                                      ? chat.streamingText
                                      : null,
                                  waitingForFirstToken: waiting,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            if (isGenerating)
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Composer(
                  enabled: chat.phase != ChatPhase.error,
                  generating: isGenerating,
                  placeholder: 'Message ${chat.persona.name}…',
                  onSend: (text, {attachment}) => chat.send(
                    text,
                    mediaPath: attachment?.path,
                    mediaKind: attachment?.kind,
                  ),
                  onStop: () => chat.stop(),
                ),
              ),
            ),
          ],
        ),
        ),
      ],
    );
  }

  String? _lastAssistantId(List<Message> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == MessageRole.assistant) return messages[i].id;
    }
    return null;
  }
}

/// Soft brand-tinted radial highlight in the top-left, plus the surface
/// colour. Gives the chat surface a quiet sense of depth.
class _ChatBackground extends StatelessWidget {
  const _ChatBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface),
      child: Stack(
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
                    scheme.primary.withValues(alpha: isDark ? 0.10 : 0.05),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -300,
            right: -200,
            width: 700,
            height: 700,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.tertiary.withValues(alpha: isDark ? 0.06 : 0.03),
                    scheme.tertiary.withValues(alpha: 0),
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

class _EmptyChat extends StatefulWidget {
  const _EmptyChat({
    super.key,
    required this.personaName,
    required this.personaEmoji,
  });
  final String personaName;
  final String personaEmoji;

  @override
  State<_EmptyChat> createState() => _EmptyChatState();
}

class _EmptyChatState extends State<_EmptyChat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  static const _starters = [
    'Explain something I\'m curious about',
    'Help me write a short note',
    'Brainstorm ideas with me',
    'Summarize a piece of text',
  ];

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(Insets.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1).animate(
                  CurvedAnimation(
                    parent: _ctl,
                    curve: const Interval(0, 0.6, curve: Motion.standard),
                  ),
                ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _ctl,
                    curve: const Interval(0, 0.5),
                  ),
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Brand.softGradient,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      widget.personaEmoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _ctl,
                  curve: const Interval(0.1, 0.6),
                ),
                child: Text(
                  widget.personaName,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: Insets.sm),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _ctl,
                  curve: const Interval(0.15, 0.7),
                ),
                child: Text(
                  'Pick a starter or type anything below.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: Insets.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  for (var i = 0; i < _starters.length; i++)
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _ctl,
                        curve: Interval(
                          0.25 + i * 0.08,
                          (0.45 + i * 0.08).clamp(0.0, 1.0),
                          curve: Motion.standard,
                        ),
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _ctl,
                                curve: Interval(
                                  0.25 + i * 0.08,
                                  (0.45 + i * 0.08).clamp(0.0, 1.0),
                                  curve: Motion.standard,
                                ),
                              ),
                            ),
                        child: _StarterChip(label: _starters[i]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarterChip extends StatefulWidget {
  const _StarterChip({required this.label});
  final String label;

  @override
  State<_StarterChip> createState() => _StarterChipState();
}

class _StarterChipState extends State<_StarterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: motionFor(context, Motion.instant),
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        decoration: BoxDecoration(
          color: _hover
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(Corners.pill),
          border: Border.all(
            color: _hover
                ? scheme.primary.withValues(alpha: 0.4)
                : scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          widget.label,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: motionFor(context, Motion.quick),
      curve: Motion.standard,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, 0),
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.md,
          Insets.sm,
          Insets.md,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(Corners.md),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
