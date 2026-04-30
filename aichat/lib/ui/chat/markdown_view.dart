import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../common/design.dart';

/// Markdown renderer tuned for chat messages.
/// - Code blocks have a header bar (language + Copy).
/// - Inline code gets a tinted pill.
/// - Tables, lists, blockquotes inherit calm Material 3 styling.
class ChatMarkdown extends StatelessWidget {
  const ChatMarkdown({
    super.key,
    required this.text,
    this.selectable = true,
  });

  final String text;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.94),
    );
    final code = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
      color: scheme.onSurface,
    );
    return MarkdownBody(
      data: text,
      selectable: selectable,
      softLineBreak: true,
      onTapLink: (_, _, _) {},
      styleSheet: MarkdownStyleSheet(
        p: body,
        a: body?.copyWith(
          color: scheme.tertiary,
          decoration: TextDecoration.underline,
        ),
        h1: theme.textTheme.headlineSmall?.copyWith(height: 1.25),
        h2: theme.textTheme.titleLarge?.copyWith(height: 1.30),
        h3: theme.textTheme.titleMedium,
        h4: theme.textTheme.titleSmall,
        h5: theme.textTheme.titleSmall,
        h6: theme.textTheme.titleSmall,
        em: body?.copyWith(fontStyle: FontStyle.italic),
        strong: body?.copyWith(fontWeight: FontWeight.w700),
        blockquote: body?.copyWith(
          color: scheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: scheme.surfaceContainer.withValues(alpha: 0.5),
          border: Border(
            left: BorderSide(color: scheme.primary, width: 3),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(Corners.sm),
            bottomRight: Radius.circular(Corners.sm),
          ),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(
            Insets.md, Insets.sm, Insets.md, Insets.sm),
        listBullet: body,
        listIndent: 20,
        code: code.copyWith(
          backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        ),
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(),
        tableHead: theme.textTheme.titleSmall,
        tableBody: body,
        tableBorder: TableBorder(
          horizontalInside:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: scheme.outlineVariant, width: 1),
          ),
        ),
      ),
      builders: {'pre': _PreBuilder(theme)},
    );
  }
}

class _PreBuilder extends MarkdownElementBuilder {
  _PreBuilder(this.theme);
  final ThemeData theme;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    String language = '';
    String source = element.textContent;
    final codeChild = element.children?.whereType<md.Element>().firstWhere(
          (e) => e.tag == 'code',
          orElse: () => md.Element('code', null),
        );
    final cls = codeChild?.attributes['class'] ?? '';
    if (cls.startsWith('language-')) {
      language = cls.substring('language-'.length);
    }
    if (source.endsWith('\n')) {
      source = source.substring(0, source.length - 1);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: _CodeBlock(language: language, source: source, theme: theme),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.language,
    required this.source,
    required this.theme,
  });
  final String language;
  final String source;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
                Insets.md, Insets.xs, Insets.xs, Insets.xs),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? 'code' : language,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _CopyButton(text: source),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(Insets.md),
            child: SelectableText(
              source,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});
  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: _copy,
      style: TextButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 0),
        minimumSize: const Size(0, 28),
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        textStyle: theme.textTheme.labelSmall,
      ),
      icon: AnimatedSwitcher(
        duration: Motion.quick,
        transitionBuilder: (c, a) => ScaleTransition(
            scale: a, child: FadeTransition(opacity: a, child: c)),
        child: Icon(
          _copied ? Icons.check_rounded : Icons.copy_rounded,
          key: ValueKey(_copied),
          size: 14,
        ),
      ),
      label: Text(_copied ? 'Copied' : 'Copy'),
    );
  }
}
