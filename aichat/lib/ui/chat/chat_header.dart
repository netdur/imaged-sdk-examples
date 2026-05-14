import 'package:flutter/material.dart';

import '../../data/models/model_bundle.dart';
import '../../llm/chat_controller.dart';
import '../common/design.dart';

/// Chat header. Carries persona + model identity, live tok/s while
/// generating, and an anchor for the sampler popover.
class ChatHeader extends StatefulWidget {
  const ChatHeader({
    super.key,
    required this.chat,
    required this.model,
    required this.onRename,
    required this.onAdjust,
    this.onOpenSidebar,
  });

  final ChatController chat;
  final ModelBundle model;
  final Future<void> Function(String) onRename;
  final VoidCallback onAdjust;
  final VoidCallback? onOpenSidebar;

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  Future<void> _renameFlow() async {
    final controller = TextEditingController(
      text: widget.chat.conversation.title,
    );
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Chat title'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (next != null &&
        next.isNotEmpty &&
        next != widget.chat.conversation.title) {
      await widget.onRename(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chat = widget.chat;
    final isGenerating = chat.phase == ChatPhase.generating;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Container(
          padding: EdgeInsets.fromLTRB(
            widget.onOpenSidebar == null ? Insets.lg : Insets.sm,
            Insets.sm,
            Insets.sm,
            Insets.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Row(
            children: [
              if (widget.onOpenSidebar != null) ...[
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Chats',
                  onPressed: widget.onOpenSidebar,
                ),
                const SizedBox(width: Insets.xs),
              ],
              if (!compact)
                _PersonaChip(
                  emoji: chat.persona.emoji ?? '✨',
                  name: chat.persona.name,
                ),
              if (!compact) const SizedBox(width: Insets.md),
              Expanded(
                child: InkWell(
                  onTap: _renameFlow,
                  borderRadius: BorderRadius.circular(Corners.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                      vertical: Insets.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chat.conversation.title,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (compact)
                          Text(
                            chat.persona.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!compact)
                AnimatedSize(
                  duration: motionFor(context, Motion.quick),
                  curve: Motion.standard,
                  alignment: Alignment.centerRight,
                  child: isGenerating
                      ? _StreamingStat(
                          tokensPerSecond: chat.tokensPerSecond,
                          tokensGenerated: chat.tokensGenerated,
                        )
                      : const SizedBox(width: 0, height: 0),
                ),
              if (!compact) const SizedBox(width: Insets.sm),
              if (!compact) _ModelBadge(model: widget.model),
              const SizedBox(width: Insets.xs),
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20),
                tooltip: 'Adjust generation',
                onPressed: widget.onAdjust,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PersonaChip extends StatelessWidget {
  const _PersonaChip({required this.emoji, required this.name});
  final String emoji;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.xs,
        Insets.xs,
        Insets.md,
        Insets.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(Corners.pill),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface,
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: Insets.sm),
          Text(
            name,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBadge extends StatelessWidget {
  const _ModelBadge({required this.model});
  final ModelBundle model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: 'Model: ${model.name} · ctx ${model.nCtx}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Corners.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.memory_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Insets.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                model.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamingStat extends StatelessWidget {
  const _StreamingStat({
    required this.tokensPerSecond,
    required this.tokensGenerated,
  });
  final double tokensPerSecond;
  final int tokensGenerated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(Corners.sm),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.tertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Insets.xs),
          Text(
            '${tokensPerSecond.toStringAsFixed(1)} tok/s · $tokensGenerated',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
