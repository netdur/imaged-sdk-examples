import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/message.dart';
import '../../data/models/persona.dart';
import '../common/design.dart';
import 'markdown_view.dart';

/// One chat message rendered into the conversation column.
///
/// - User: right-aligned, soft tinted fill (no border).
/// - Assistant: left-aligned with persona avatar; markdown rendered.
/// - On hover (assistant), a small toolbar slides in: copy / regenerate.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.persona,
    this.streaming = false,
    this.streamingText,
    this.waitingForFirstToken = false,
    this.onRegenerate,
  });

  final Message message;
  final Persona persona;
  final bool streaming;
  final String? streamingText;
  final bool waitingForFirstToken;
  final VoidCallback? onRegenerate;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: Motion.quick, value: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entry.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entry.duration = motionFor(context, Motion.quick);
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  String get _displayText => widget.streaming && widget.streamingText != null
      ? widget.streamingText!
      : widget.message.text;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    return FadeTransition(
      opacity: _entry,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _entry, curve: Motion.standard)),
        child: isUser ? _buildUser(context) : _buildAssistant(context),
      ),
    );
  }

  Widget _buildUser(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width < 640 ? width * 0.86 : 720.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.md,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(Corners.lg),
                      ),
                      child: _MessageContent(
                        text: _displayText,
                        message: widget.message,
                        renderMarkdown: false,
                        streaming: false,
                        waitingForFirstToken: false,
                        textColor: scheme.onSurface,
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      right: 8,
                      child: AnimatedSlide(
                        duration: motionFor(context, Motion.instant),
                        offset: _hover ? Offset.zero : const Offset(0, 0.2),
                        curve: Motion.standard,
                        child: AnimatedOpacity(
                          duration: motionFor(context, Motion.instant),
                          opacity: _hover ? 1 : 0,
                          child: _Toolbar(
                            children: [
                              _ToolbarAction(
                                icon: Icons.copy_rounded,
                                tooltip: 'Copy',
                                onTap: () => _copy(widget.message.text),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildAssistant(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.md),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AssistantAvatar(
              emoji: widget.persona.emoji ?? '✨',
              streaming: widget.streaming,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 2,
                      bottom: Insets.xs,
                      left: 0,
                    ),
                    child: Text(
                      widget.persona.name,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _MessageContent(
                    text: _displayText,
                    message: widget.message,
                    renderMarkdown: true,
                    streaming: widget.streaming,
                    waitingForFirstToken: widget.waitingForFirstToken,
                    textColor: theme.colorScheme.onSurface,
                  ),
                  if (!widget.streaming && widget.message.text.isNotEmpty)
                    AnimatedSlide(
                      duration: motionFor(context, Motion.instant),
                      offset: _hover ? Offset.zero : const Offset(0, 0.2),
                      curve: Motion.standard,
                      child: AnimatedOpacity(
                        duration: motionFor(context, Motion.instant),
                        opacity: _hover ? 1 : 0,
                        child: Padding(
                          padding: const EdgeInsets.only(top: Insets.sm),
                          child: _Toolbar(
                            children: [
                              _ToolbarAction(
                                icon: Icons.copy_rounded,
                                tooltip: 'Copy',
                                onTap: () => _copy(widget.message.text),
                              ),
                              if (widget.onRegenerate != null)
                                _ToolbarAction(
                                  icon: Icons.refresh_rounded,
                                  tooltip: 'Regenerate',
                                  onTap: widget.onRegenerate!,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied'),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.md),
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.text,
    required this.message,
    required this.renderMarkdown,
    required this.streaming,
    required this.waitingForFirstToken,
    required this.textColor,
  });

  final String text;
  final Message message;
  final bool renderMarkdown;
  final bool streaming;
  final bool waitingForFirstToken;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.hasMedia && message.mediaKind == MediaKind.image)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Corners.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 360,
                  maxHeight: 360,
                ),
                child: Image.file(
                  File(message.mediaPath!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        if (waitingForFirstToken && text.isEmpty)
          const _TypingDots()
        else if (renderMarkdown && !streaming)
          ChatMarkdown(text: text)
        else
          SelectableText.rich(
            TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor.withValues(alpha: 0.94),
              ),
              children: [
                TextSpan(text: text),
                if (streaming)
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _BlinkingCursor(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AssistantAvatar extends StatefulWidget {
  const _AssistantAvatar({required this.emoji, required this.streaming});
  final String emoji;
  final bool streaming;

  @override
  State<_AssistantAvatar> createState() => _AssistantAvatarState();
}

class _AssistantAvatarState extends State<_AssistantAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.streaming) _ctl.repeat();
  }

  @override
  void didUpdateWidget(covariant _AssistantAvatar old) {
    super.didUpdateWidget(old);
    if (widget.streaming && !_ctl.isAnimating) {
      _ctl.repeat();
    } else if (!widget.streaming && _ctl.isAnimating) {
      _ctl.stop();
      _ctl.value = 0;
    }
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
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) {
        final t = _ctl.value;
        return Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.streaming
                ? SweepGradient(
                    startAngle: 0,
                    endAngle: 6.2832,
                    transform: GradientRotation(t * 6.2832),
                    colors: [
                      scheme.primary.withValues(alpha: 0.0),
                      scheme.primary.withValues(alpha: 0.55),
                      scheme.tertiary.withValues(alpha: 0.55),
                      scheme.primary.withValues(alpha: 0.0),
                    ],
                  )
                : null,
            color: widget.streaming
                ? null
                : scheme.primaryContainer.withValues(alpha: 0.55),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerLow,
            ),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 15)),
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Corners.sm),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ToolbarAction extends StatefulWidget {
  const _ToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ToolbarAction> createState() => _ToolbarActionState();
}

class _ToolbarActionState extends State<_ToolbarAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: motionFor(context, Motion.instant),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hover
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Corners.xs),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctl.drive(Tween(begin: 0.2, end: 0.95)),
      child: const Text('▍', style: TextStyle(height: 1.2, fontSize: 14.5)),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    return SizedBox(
      height: 18,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          final t = _ctl.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = ((t + i / 3) % 1);
              final scale = 0.6 + 0.4 * (1 - (phase * 2 - 1).abs());
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
