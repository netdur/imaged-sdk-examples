import 'package:flutter/material.dart';

import '../../llm/chat_controller.dart';
import '../common/design.dart';

/// Shows the sampler popover anchored as a centered dialog with a soft
/// scale + fade entry. Edits commit live to the conversation.
Future<void> showSamplerPopover(
  BuildContext context, {
  required ChatController chat,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Adjust generation',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: motionFor(context, Motion.quick),
    pageBuilder: (_, _, _) => _SamplerDialog(chat: chat),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Motion.standard,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SamplerDialog extends StatefulWidget {
  const _SamplerDialog({required this.chat});
  final ChatController chat;

  @override
  State<_SamplerDialog> createState() => _SamplerDialogState();
}

class _SamplerDialogState extends State<_SamplerDialog> {
  late double _temp;
  late double _topP;
  late TextEditingController _maxTokens;

  @override
  void initState() {
    super.initState();
    _temp = widget.chat.conversation.samplerTemp;
    _topP = widget.chat.conversation.samplerTopP;
    _maxTokens = TextEditingController(
        text: widget.chat.conversation.samplerMaxTokens.toString());
  }

  @override
  void dispose() {
    _maxTokens.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final mx = int.tryParse(_maxTokens.text.trim()) ??
        widget.chat.conversation.samplerMaxTokens;
    await widget.chat.updateSampler(
      temperature: _temp,
      topP: _topP,
      maxTokens: mx,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            margin: const EdgeInsets.all(Insets.lg),
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(Corners.xl),
              border: Border.all(
                color: theme.colorScheme.outlineVariant
                    .withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: Insets.sm),
                    Text('Sampler',
                        style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  'Tunable mid-chat. Applied to the next reply.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Insets.lg),
                _SliderRow(
                  label: 'Temperature',
                  value: _temp,
                  min: 0,
                  max: 2,
                  decimals: 2,
                  onChanged: (v) => setState(() => _temp = v),
                  onChangeEnd: (_) => _commit(),
                ),
                const SizedBox(height: Insets.md),
                _SliderRow(
                  label: 'Top-p',
                  value: _topP,
                  min: 0,
                  max: 1,
                  decimals: 2,
                  onChanged: (v) => setState(() => _topP = v),
                  onChangeEnd: (_) => _commit(),
                ),
                const SizedBox(height: Insets.lg),
                TextField(
                  controller: _maxTokens,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max tokens per reply',
                  ),
                  onSubmitted: (_) => _commit(),
                  onTapOutside: (_) => _commit(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.decimals,
    required this.onChanged,
    required this.onChangeEnd,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final void Function(double) onChanged;
  final void Function(double) onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Text(value.toStringAsFixed(decimals),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
