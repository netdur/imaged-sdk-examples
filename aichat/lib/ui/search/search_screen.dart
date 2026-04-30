import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_services.dart';
import '../../data/repos/search_repo.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onPickConversation});

  final void Function(String conversationId) onPickConversation;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _results = [];
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _busy = true);
    try {
      final hits = await AppServices.instance.search.search(q);
      if (!mounted) return;
      setState(() => _results = hits);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search messages…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: _results.isEmpty
          ? Center(
              child: Text(
                _controller.text.isEmpty
                    ? 'Type to search across all messages'
                    : 'No matches',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, i) {
                final h = _results[i];
                return ListTile(
                  title: Text(h.conversationTitle,
                      style: theme.textTheme.titleSmall),
                  subtitle: _SnippetText(snippet: h.snippet),
                  trailing: Text(_relTime(h.createdAt),
                      style: theme.textTheme.bodySmall),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onPickConversation(h.conversationId);
                  },
                );
              },
            ),
    );
  }
}

class _SnippetText extends StatelessWidget {
  const _SnippetText({required this.snippet});
  final String snippet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    var s = snippet;
    while (true) {
      final i = s.indexOf('<b>');
      if (i < 0) {
        spans.add(TextSpan(text: s));
        break;
      }
      if (i > 0) spans.add(TextSpan(text: s.substring(0, i)));
      s = s.substring(i + 3);
      final j = s.indexOf('</b>');
      if (j < 0) {
        spans.add(TextSpan(text: s));
        break;
      }
      spans.add(TextSpan(
        text: s.substring(0, j),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ));
      s = s.substring(j + 4);
    }
    return Text.rich(
      TextSpan(children: spans, style: theme.textTheme.bodySmall),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String _relTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}
