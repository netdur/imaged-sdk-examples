import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/design.dart';

/// First-paint screen. Shows phase progress while bootstrapping; on
/// error, exposes a Retry. Decorated with the brand mark and a soft
/// radial highlight so it doesn't look like a crash screen.
class BootScreen extends StatefulWidget {
  const BootScreen({
    super.key,
    required this.phase,
    this.error,
    this.onRetry,
  });

  final String phase;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: Motion.slow,
    )..forward();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    if (widget.error != null) _shake.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entry.duration = motionFor(context, Motion.slow);
  }

  @override
  void didUpdateWidget(covariant BootScreen old) {
    super.didUpdateWidget(old);
    if (widget.error != null && old.error == null) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = widget.error != null;

    final entry = CurvedAnimation(parent: _entry, curve: Motion.standard);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -240,
            left: -200,
            width: 700,
            height: 700,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.12),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -240,
            right: -200,
            width: 700,
            height: 700,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.tertiary.withValues(alpha: 0.08),
                    scheme.tertiary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) {
                        final dx = isError
                            ? _shakeOffset(_shake.value) * 6
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1)
                            .animate(entry),
                        child: FadeTransition(
                          opacity: entry,
                          child: _BrandMark(error: isError),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    FadeTransition(
                      opacity: entry,
                      child: Text(
                        isError ? 'Something broke' : 'aichat',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    AnimatedSwitcher(
                      duration: motionFor(context, Motion.quick),
                      child: Text(
                        isError
                            ? widget.error.toString()
                            : widget.phase,
                        key: ValueKey(isError ? 'err' : widget.phase),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    if (!isError)
                      FadeTransition(
                        opacity: entry,
                        child: SizedBox(
                          width: 220,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(Corners.xs),
                            child: const LinearProgressIndicator(
                              minHeight: 3,
                            ),
                          ),
                        ),
                      )
                    else if (widget.onRetry != null)
                      FilledButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try again'),
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
}

/// Brand mark used during boot. Aubergine-magenta-sunset gradient orb
/// with a sparkle glyph inside; flips to error tone when [error] is true.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.error});
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: error
            ? null
            : Brand.gradient,
        color: error ? scheme.errorContainer : null,
        boxShadow: [
          BoxShadow(
            color: (error ? scheme.error : scheme.primary)
                .withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        error ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
        size: 36,
        color: error ? scheme.onErrorContainer : Colors.white,
      ),
    );
  }
}

/// Damped sinusoidal shake (one pass over t∈[0,1]).
double _shakeOffset(double t) {
  if (t <= 0 || t >= 1) return 0;
  final decay = 1 - t;
  return decay * math.sin(t * 28);
}
