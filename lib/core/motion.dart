import 'package:flutter/widgets.dart';

/// NOVA motion system: consistent curves and short, non-blocking durations.
class NovaMotion {
  NovaMotion._();

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve emphasized = Cubic(0.3, 0, 0, 1);
  static const Curve springy = Cubic(0.34, 1.3, 0.64, 1);

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration med = Duration(milliseconds: 240);
  static const Duration page = Duration(milliseconds: 300);

  /// Global reduced-motion flag (user setting + accessibility).
  static bool reduced = false;

  static Duration scale(Duration d) =>
      reduced ? Duration.zero : d;
}
