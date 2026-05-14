import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/message.dart';
import '../common/design.dart';

class ComposerAttachment {
  ComposerAttachment({required this.path, required this.kind});
  final String path;
  final MediaKind kind;
}

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.enabled,
    required this.generating,
    required this.onSend,
    required this.onStop,
    this.allowImage = true,
    this.placeholder,
  });

  final bool enabled;
  final bool generating;
  final void Function(String text, {ComposerAttachment? attachment}) onSend;
  final VoidCallback onStop;
  final bool allowImage;
  final String? placeholder;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;
  bool _focused = false;
  ComposerAttachment? _attachment;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focus.addListener(() {
      if (_focused != _focus.hasFocus) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Attach an image',
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(
      () => _attachment = ComposerAttachment(path: path, kind: MediaKind.image),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachment == null) return;
    widget.onSend(text, attachment: _attachment);
    _controller.clear();
    setState(() => _attachment = null);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSend =
        widget.enabled &&
        (_hasText || _attachment != null) &&
        !widget.generating;
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? Insets.sm : Insets.lg,
        Insets.sm,
        compact ? Insets.sm : Insets.lg,
        compact ? Insets.sm : Insets.lg,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: motionFor(context, Motion.quick),
            curve: Motion.standard,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(
                alpha: _focused ? 0.95 : 0.75,
              ),
              borderRadius: BorderRadius.circular(Corners.xl),
              border: Border.all(
                color: _focused
                    ? scheme.primary.withValues(alpha: 0.5)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
                width: _focused ? 1.4 : 1,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(
              Insets.sm,
              Insets.xs,
              Insets.sm,
              Insets.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: motionFor(context, Motion.quick),
                  curve: Motion.standard,
                  alignment: Alignment.topCenter,
                  child: _attachment == null
                      ? const SizedBox(width: double.infinity)
                      : _AttachmentPreview(
                          attachment: _attachment!,
                          onRemove: () => setState(() => _attachment = null),
                        ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.allowImage)
                      _PillIconButton(
                        icon: Icons.add_photo_alternate_outlined,
                        tooltip: 'Attach image',
                        onTap: widget.enabled && !widget.generating
                            ? _pickImage
                            : null,
                      ),
                    Expanded(
                      child: Shortcuts(
                        shortcuts: <LogicalKeySet, Intent>{
                          LogicalKeySet(
                            LogicalKeyboardKey.meta,
                            LogicalKeyboardKey.enter,
                          ): const _SubmitIntent(),
                          LogicalKeySet(
                            LogicalKeyboardKey.control,
                            LogicalKeyboardKey.enter,
                          ): const _SubmitIntent(),
                        },
                        child: Actions(
                          actions: <Type, Action<Intent>>{
                            _SubmitIntent: CallbackAction<_SubmitIntent>(
                              onInvoke: (_) {
                                if (canSend) _submit();
                                return null;
                              },
                            ),
                          },
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: 40,
                              maxHeight: compact ? 180 : 320,
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              autofocus: true,
                              enabled: widget.enabled && !widget.generating,
                              maxLines: null,
                              minLines: 1,
                              textInputAction: TextInputAction.newline,
                              style: theme.textTheme.bodyMedium,
                              decoration: InputDecoration(
                                hintText: widget.generating
                                    ? 'generating…'
                                    : (widget.placeholder ?? 'Message…'),
                                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: Insets.sm,
                                  vertical: Insets.md,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.xs),
                    _SendButton(
                      generating: widget.generating,
                      enabled: canSend,
                      onSend: _submit,
                      onStop: widget.onStop,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: motionFor(context, Motion.instant),
                  alignment: Alignment.topCenter,
                  child: _focused && !compact
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Insets.sm,
                            0,
                            Insets.sm,
                            Insets.xs,
                          ),
                          child: Row(
                            children: [
                              const Spacer(),
                              Text(
                                '⌘⏎ to send',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity, height: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillIconButton extends StatefulWidget {
  const _PillIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_PillIconButton> createState() => _PillIconButtonState();
}

class _PillIconButtonState extends State<_PillIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = widget.onTap == null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: motionFor(context, Motion.instant),
            width: 44,
            height: 44,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _hover && !disabled
                  ? scheme.onSurface.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Corners.md),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: disabled
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment, required this.onRemove});
  final ComposerAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.sm,
        Insets.sm,
        Insets.sm,
        Insets.xs,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Corners.md),
                child: attachment.kind == MediaKind.image
                    ? Image.file(
                        File(attachment.path),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.audio_file, size: 22),
                      ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.95,
                  ),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: theme.colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              attachment.path.split(Platform.pathSeparator).last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.generating,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final bool generating;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onTap = widget.generating
        ? widget.onStop
        : (widget.enabled ? widget.onSend : null);

    final Gradient? gradient = widget.generating
        ? null
        : (widget.enabled ? Brand.gradient : null);
    final Color? color = widget.generating
        ? scheme.errorContainer
        : (widget.enabled
              ? null
              : scheme.surfaceContainerHighest.withValues(alpha: 0.7));
    final Color fg = widget.generating
        ? scheme.onErrorContainer
        : (widget.enabled ? Colors.white : scheme.onSurfaceVariant);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: AnimatedScale(
        duration: motionFor(context, Motion.instant),
        scale: _hover && onTap != null ? 1.05 : 1.0,
        curve: Motion.standard,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: motionFor(context, Motion.quick),
            curve: Motion.standard,
            width: 44,
            height: 44,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: gradient,
              color: color,
              shape: BoxShape.circle,
              boxShadow: widget.enabled && !widget.generating
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: motionFor(context, Motion.quick),
              transitionBuilder: (c, a) => RotationTransition(
                turns: Tween<double>(begin: 0.92, end: 1).animate(a),
                child: ScaleTransition(scale: a, child: c),
              ),
              child: Icon(
                widget.generating
                    ? Icons.stop_rounded
                    : Icons.arrow_upward_rounded,
                key: ValueKey(widget.generating),
                color: fg,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}
