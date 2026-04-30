import 'package:flutter/material.dart';

/// Shown when the model registry is empty. P2 will turn this into a real
/// "Add your first model" wizard with local-file picker + URL download.
class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 56, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 24),
                Text('No models yet',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'aichat needs at least one GGUF model registered before '
                  'you can chat. Model management UI lands in P2.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
