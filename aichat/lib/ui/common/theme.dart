import 'package:flutter/material.dart';

import 'design.dart';

/// Builds the app's dark and light themes. Both share the aubergine
/// accent but layer surfaces differently so each feels native, not like
/// the dark theme tinted lighter.
class AppTheme {
  static ThemeData dark() {
    final scheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: Color(0xFFE5BFE7),
      onPrimary: Color(0xFF3D0A40),
      primaryContainer: Color(0xFF5A2860),
      onPrimaryContainer: Color(0xFFF5E1F8),
      secondary: Color(0xFFD0A8D6),
      onSecondary: Color(0xFF361937),
      secondaryContainer: Color(0xFF503051),
      onSecondaryContainer: Color(0xFFF1DBF4),
      tertiary: Color(0xFFD55E89),
      onTertiary: Color(0xFF3E0E25),
      tertiaryContainer: Color(0xFF6E2845),
      onTertiaryContainer: Color(0xFFFFD8E4),
      error: Color(0xFFE89BAA),
      onError: Color(0xFF400915),
      errorContainer: Color(0xFF6B1F2C),
      onErrorContainer: Color(0xFFFFD8DE),
      surface: Color(0xFF120E18),
      onSurface: Color(0xFFF1EAF3),
      surfaceContainerLowest: Color(0xFF0B0810),
      surfaceContainerLow: Color(0xFF181321),
      surfaceContainer: Color(0xFF1E1828),
      surfaceContainerHigh: Color(0xFF26202F),
      surfaceContainerHighest: Color(0xFF2E2738),
      onSurfaceVariant: Color(0xFFC9BFCF),
      outline: Color(0xFF6F6577),
      outlineVariant: Color(0xFF3D3543),
      inverseSurface: Color(0xFFF1EAF3),
      onInverseSurface: Color(0xFF1E1828),
      inversePrimary: Color(0xFF5A2860),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: Color(0xFFE5BFE7),
    );
    return _build(scheme);
  }

  static ThemeData light() {
    final scheme = const ColorScheme.light(
      brightness: Brightness.light,
      primary: Color(0xFF6A2A6E),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFF5DCF7),
      onPrimaryContainer: Color(0xFF2C0A2F),
      secondary: Color(0xFF6F4D72),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFF8DAFB),
      onSecondaryContainer: Color(0xFF290B2D),
      tertiary: Color(0xFFA63E6A),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFD8E4),
      onTertiaryContainer: Color(0xFF3E0E25),
      error: Color(0xFFB3294A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFD9DF),
      onErrorContainer: Color(0xFF400915),
      surface: Color(0xFFFBF7FB),
      onSurface: Color(0xFF1C1620),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF6F0F7),
      surfaceContainer: Color(0xFFF1EAF3),
      surfaceContainerHigh: Color(0xFFEAE2EC),
      surfaceContainerHighest: Color(0xFFE2D9E5),
      onSurfaceVariant: Color(0xFF5C5263),
      outline: Color(0xFF8C8294),
      outlineVariant: Color(0xFFCFC4D2),
      inverseSurface: Color(0xFF312938),
      onInverseSurface: Color(0xFFF6F0F7),
      inversePrimary: Color(0xFFE5BFE7),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      surfaceTint: Color(0xFF6A2A6E),
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.compact,
      splashFactory: InkSparkle.splashFactory,
    );
    final t = base.textTheme;
    final textTheme = t
        .copyWith(
          displayLarge: t.displayLarge?.copyWith(
              fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5),
          displayMedium: t.displayMedium?.copyWith(
              fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.4),
          displaySmall: t.displaySmall?.copyWith(
              fontWeight: FontWeight.w700, height: 1.18, letterSpacing: -0.3),
          headlineMedium: t.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700, height: 1.22),
          headlineSmall: t.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700, height: 1.25),
          titleLarge: t.titleLarge?.copyWith(
              fontWeight: FontWeight.w700, height: 1.30),
          titleMedium: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w600, height: 1.32),
          titleSmall: t.titleSmall?.copyWith(
              fontWeight: FontWeight.w600, height: 1.35),
          bodyLarge: t.bodyLarge?.copyWith(height: 1.55),
          bodyMedium: t.bodyMedium?.copyWith(fontSize: 14.5, height: 1.55),
          bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.45),
          labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          labelSmall: t.labelSmall?.copyWith(
              fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6),
        )
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    return base.copyWith(
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 20),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Corners.md)),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.md),
          textStyle: textTheme.labelLarge,
          animationDuration: Motion.quick,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Corners.sm)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Corners.sm)),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.lg)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(Corners.xl)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(Corners.sm),
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onInverseSurface,
          letterSpacing: 0.2,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.md, vertical: Insets.sm),
        waitDuration: const Duration(milliseconds: 350),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Insets.md, vertical: Insets.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.md),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corners.md)),
        textStyle: textTheme.bodyMedium,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2),
          insets: const EdgeInsets.symmetric(horizontal: Insets.xl),
        ),
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        dividerColor: scheme.outlineVariant.withValues(alpha: 0.4),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return scheme.onSurfaceVariant.withValues(alpha: 0.5);
          }
          return scheme.onSurfaceVariant.withValues(alpha: 0.2);
        }),
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(Corners.xs),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SharedAxisYTransitions(),
          TargetPlatform.iOS: _SharedAxisYTransitions(),
          TargetPlatform.macOS: _SharedAxisYTransitions(),
          TargetPlatform.windows: _SharedAxisYTransitions(),
          TargetPlatform.linux: _SharedAxisYTransitions(),
        },
      ),
    );
  }
}

/// Shared-axis-Y page transition (subtle 12px slide + fade).
class _SharedAxisYTransitions extends PageTransitionsBuilder {
  const _SharedAxisYTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
        parent: animation, curve: Motion.standard);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(fade);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
