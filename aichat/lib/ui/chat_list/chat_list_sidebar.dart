import 'package:flutter/material.dart';

import '../../data/app_services.dart';
import '../../data/models/conversation.dart';
import '../../data/models/model_bundle.dart';
import '../../data/models/persona.dart';
import '../common/confirm_dialog.dart';
import '../common/design.dart';
import '../common/theme_controller.dart';

/// Unified left pane: brand + new chat + search + grouped chat list +
/// model footer + settings/theme. Animates collapse to icon-only mode.
class ChatListSidebar extends StatefulWidget {
  const ChatListSidebar({
    super.key,
    required this.activeConversationId,
    required this.activeModel,
    required this.onSelect,
    required this.onNew,
    required this.onSearch,
    required this.onSettings,
  });

  final String? activeConversationId;
  final ModelBundle? activeModel;
  final void Function(String conversationId) onSelect;
  final VoidCallback onNew;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  State<ChatListSidebar> createState() => _ChatListSidebarState();
}

class _ChatListSidebarState extends State<ChatListSidebar> {
  final _searchCtl = TextEditingController();
  String _filter = '';
  bool _collapsed = false;

  AppServices get svc => AppServices.instance;

  @override
  void initState() {
    super.initState();
    svc.conversations.addListener(_onChange);
    svc.personas.addListener(_onChange);
    svc.models.addListener(_onChange);
    _searchCtl.addListener(() {
      setState(() => _filter = _searchCtl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    svc.conversations.removeListener(_onChange);
    svc.personas.removeListener(_onChange);
    svc.models.removeListener(_onChange);
    _searchCtl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _delete(Conversation c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete chat?',
      message:
          '"${c.title}" and all its messages will be deleted. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await svc.conversations.delete(c.id);
  }

  Future<void> _rename(Conversation c) async {
    final controller = TextEditingController(text: c.title);
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
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (next != null && next.isNotEmpty && next != c.title) {
      await svc.conversations.rename(c.id, next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: motionFor(context, Motion.quick),
      curve: Motion.standard,
      width: _collapsed ? 64 : 280,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: ClipRect(
        child: Column(
          children: [
            _BrandRow(
              collapsed: _collapsed,
              onToggle: () => setState(() => _collapsed = !_collapsed),
            ),
            const SizedBox(height: Insets.xs),
            _NewChatButton(
              collapsed: _collapsed,
              onTap: widget.onNew,
            ),
            if (!_collapsed) ...[
              const SizedBox(height: Insets.sm),
              _SearchField(
                controller: _searchCtl,
                onOpenFts: widget.onSearch,
              ),
            ] else ...[
              const SizedBox(height: Insets.xs),
              _CollapsedIcon(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onTap: widget.onSearch,
              ),
            ],
            const SizedBox(height: Insets.sm),
            Expanded(
              child: _collapsed
                  ? const SizedBox.shrink()
                  : _ChatList(
                      filter: _filter,
                      activeConversationId: widget.activeConversationId,
                      onSelect: widget.onSelect,
                      onRename: _rename,
                      onDelete: _delete,
                    ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            _Footer(
              collapsed: _collapsed,
              modelName: widget.activeModel?.name,
              onSettings: widget.onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.collapsed, required this.onToggle});
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (collapsed) {
      // Tap the brand mark itself to expand. Avoids fitting both a brand
      // mark and a separate button into a 64px column.
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            Insets.sm, Insets.md, Insets.sm, Insets.sm),
        child: Tooltip(
          message: 'Expand sidebar',
          child: InkWell(
            borderRadius: BorderRadius.circular(Corners.sm),
            onTap: onToggle,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: Brand.gradient,
                borderRadius: BorderRadius.circular(Corners.sm),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.md, Insets.md, Insets.sm, Insets.sm),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: Brand.gradient,
              borderRadius: BorderRadius.circular(Corners.sm),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              'aichat',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            onPressed: onToggle,
            tooltip: 'Collapse sidebar',
            visualDensity: VisualDensity.compact,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _NewChatButton extends StatefulWidget {
  const _NewChatButton({required this.collapsed, required this.onTap});
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.collapsed ? 'New chat' : '',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: motionFor(context, Motion.instant),
              height: 38,
              decoration: BoxDecoration(
                gradient: _hover ? Brand.gradient : null,
                color: _hover ? null : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Corners.md),
                border: Border.all(
                  color: _hover
                      ? Colors.transparent
                      : scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                boxShadow: _hover
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: _hover
                        ? Colors.white
                        : scheme.onSurfaceVariant,
                  ),
                  if (!widget.collapsed) ...[
                    const SizedBox(width: Insets.sm),
                    Text(
                      'New chat',
                      style: TextStyle(
                        color: _hover
                            ? Colors.white
                            : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedIcon extends StatefulWidget {
  const _CollapsedIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_CollapsedIcon> createState() => _CollapsedIconState();
}

class _CollapsedIconState extends State<_CollapsedIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: motionFor(context, Motion.instant),
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hover
                    ? scheme.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Corners.md),
              ),
              child: Icon(widget.icon,
                  size: 18, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onOpenFts,
  });
  final TextEditingController controller;
  final VoidCallback onOpenFts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: controller,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Filter chats',
            prefixIcon: Icon(Icons.search_rounded,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            suffixIcon: IconButton(
              icon: Icon(Icons.travel_explore_rounded,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              tooltip: 'Search messages',
              onPressed: onOpenFts,
              visualDensity: VisualDensity.compact,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: Insets.sm, vertical: Insets.xs),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHigh
                .withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Corners.sm),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Corners.sm),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({
    required this.filter,
    required this.activeConversationId,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final String filter;
  final String? activeConversationId;
  final void Function(String) onSelect;
  final void Function(Conversation) onRename;
  final void Function(Conversation) onDelete;

  Future<(List<Conversation>, Map<String, Persona>)> _load() async {
    final svc = AppServices.instance;
    final convos = await svc.conversations.listAll();
    final personas = await svc.personas.listAll();
    return (convos, {for (final p in personas) p.id: p});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (convos, personasById) = snap.data!;
        final filtered = filter.isEmpty
            ? convos
            : convos
                .where((c) => c.title.toLowerCase().contains(filter))
                .toList();
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Text(
                filter.isEmpty
                    ? 'No chats yet — start one above'
                    : 'No matches',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final groups = _groupByDate(filtered);
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: Insets.xs),
          children: [
            for (final entry in groups.entries) ...[
              _GroupLabel(label: entry.key),
              for (final c in entry.value)
                _ChatTile(
                  key: ValueKey(c.id),
                  conversation: c,
                  persona: personasById[c.personaId],
                  isActive: c.id == activeConversationId,
                  onTap: () => onSelect(c.id),
                  onRename: () => onRename(c),
                  onDelete: () => onDelete(c),
                ),
              const SizedBox(height: Insets.xs),
            ],
          ],
        );
      },
    );
  }
}

Map<String, List<Conversation>> _groupByDate(List<Conversation> convos) {
  final out = <String, List<Conversation>>{};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthAgo = today.subtract(const Duration(days: 30));
  for (final c in convos) {
    final d = c.updatedAt;
    final dDay = DateTime(d.year, d.month, d.day);
    final String key;
    if (!dDay.isBefore(today)) {
      key = 'Today';
    } else if (!dDay.isBefore(yesterday)) {
      key = 'Yesterday';
    } else if (!dDay.isBefore(weekAgo)) {
      key = 'This week';
    } else if (!dDay.isBefore(monthAgo)) {
      key = 'This month';
    } else {
      key = 'Older';
    }
    out.putIfAbsent(key, () => []).add(c);
  }
  return out;
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.md, Insets.lg, Insets.xs),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color:
              theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChatTile extends StatefulWidget {
  const _ChatTile({
    super.key,
    required this.conversation,
    required this.persona,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Conversation conversation;
  final Persona? persona;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color bg;
    if (widget.isActive) {
      bg = scheme.primaryContainer.withValues(alpha: 0.55);
    } else if (_hover) {
      bg = scheme.surfaceContainerHigh.withValues(alpha: 0.7);
    } else {
      bg = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: motionFor(context, Motion.instant),
          curve: Motion.standard,
          margin: const EdgeInsets.symmetric(
              horizontal: Insets.sm, vertical: 1),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.md, vertical: Insets.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Corners.sm),
          ),
          child: Row(
            children: [
              if (widget.isActive)
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: Insets.sm),
                  decoration: BoxDecoration(
                    gradient: Brand.gradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              else
                const SizedBox(width: 3 + Insets.sm),
              Text(widget.persona?.emoji ?? '💬',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  widget.conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: scheme.onSurface
                        .withValues(alpha: widget.isActive ? 1.0 : 0.85),
                  ),
                ),
              ),
              AnimatedSize(
                duration: motionFor(context, Motion.instant),
                child: (_hover || widget.isActive)
                    ? _MenuButton(
                        onRename: widget.onRename,
                        onDelete: widget.onDelete,
                      )
                    : const SizedBox(width: 0, height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onRename, required this.onDelete});
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded, size: 16),
        padding: EdgeInsets.zero,
        iconSize: 16,
        tooltip: 'Actions',
        onSelected: (v) {
          switch (v) {
            case 'rename':
              onRename();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'rename',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 14),
              SizedBox(width: 8),
              Text('Rename'),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded, size: 14),
              SizedBox(width: 8),
              Text('Delete'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.collapsed,
    required this.modelName,
    required this.onSettings,
  });

  final bool collapsed;
  final String? modelName;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final themeButton = IconButton(
      icon: AnimatedSwitcher(
        duration: motionFor(context, Motion.quick),
        transitionBuilder: (c, a) => ScaleTransition(
            scale: a, child: FadeTransition(opacity: a, child: c)),
        child: Icon(
          ThemeController.instance.mode == ThemeMode.dark
              ? Icons.dark_mode_outlined
              : ThemeController.instance.mode == ThemeMode.light
                  ? Icons.light_mode_outlined
                  : Icons.brightness_auto_outlined,
          key: ValueKey(ThemeController.instance.mode),
          size: 18,
        ),
      ),
      tooltip: 'Theme: ${ThemeController.instance.mode.name}',
      onPressed: () => ThemeController.instance.cycle(),
      visualDensity: VisualDensity.compact,
    );
    final settingsButton = IconButton(
      icon: const Icon(Icons.settings_outlined, size: 18),
      onPressed: onSettings,
      tooltip: 'Settings',
      visualDensity: VisualDensity.compact,
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            Insets.xs, Insets.xs, Insets.xs, Insets.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: modelName == null
                  ? 'No model selected'
                  : 'Active: $modelName',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                child: _StatusDot(active: modelName != null),
              ),
            ),
            themeButton,
            settingsButton,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.sm, Insets.sm, Insets.sm, Insets.md),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: modelName == null
                  ? 'No model selected'
                  : 'Active: $modelName',
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md, vertical: Insets.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(Corners.sm),
                ),
                child: Row(
                  children: [
                    _StatusDot(active: modelName != null),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        modelName ?? 'No model',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.xs),
          themeButton,
          settingsButton,
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.active});
  final bool active;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.active) _ctl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctl.isAnimating) {
      _ctl.repeat(reverse: true);
    } else if (!widget.active && _ctl.isAnimating) {
      _ctl.stop();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.active ? scheme.primary : scheme.error;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) {
        final t = widget.active ? 0.6 + 0.4 * _ctl.value : 1.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: t),
            shape: BoxShape.circle,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5 * t),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
