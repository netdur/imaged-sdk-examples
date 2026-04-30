import 'package:flutter/material.dart';

import '../models/models_screen.dart';
import '../personas/personas_screen.dart';

/// Settings as a desktop-style modal dialog. Three sections in tabs:
/// Personas, Models, App. The dialog is sized to most of the window
/// without going full-screen.
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width.clamp(600.0, 960.0);
    final h = size.height.clamp(500.0, 760.0);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: w,
        height: h,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              _Header(onClose: () => Navigator.of(context).pop()),
              const TabBar(
                tabs: [
                  Tab(text: 'Personas', icon: Icon(Icons.theater_comedy_outlined, size: 18)),
                  Tab(text: 'Models', icon: Icon(Icons.memory, size: 18)),
                  Tab(text: 'App', icon: Icon(Icons.tune, size: 18)),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    PersonasScreen(embedded: true),
                    ModelsScreen(embedded: true),
                    _AppTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 8),
      child: Row(
        children: [
          Text('Settings', style: theme.textTheme.titleLarge),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _AppTab extends StatelessWidget {
  const _AppTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune,
                  size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('App settings', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Theme, default sampler defaults, and dev tools live here. '
                'Coming soon.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
