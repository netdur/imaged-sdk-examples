import 'package:flutter/material.dart';

/// Spacing scale in 4px steps. Use these instead of arbitrary numbers.
class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radius scale.
class Corners {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 28;
}

/// Animation durations. Always pair with [Curves.easeOutCubic] unless noted.
class Motion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0, 1.0);
}

/// Brand gradient — used sparingly for primary CTAs, focus rings, the
/// streaming indicator, and the boot mark. Never as a background fill.
class Brand {
  static const Color seed = Color(0xFF4A154B);
  static const Color magenta = Color(0xFF8B2D8E);
  static const Color sunset = Color(0xFFD55E89);

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [seed, magenta, sunset],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x334A154B),
      Color(0x228B2D8E),
      Color(0x11D55E89),
    ],
  );
}

/// Honour reduced-motion preferences and shorten or disable animations.
Duration motionFor(BuildContext context, Duration d) {
  final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return disable ? const Duration(milliseconds: 1) : d;
}
