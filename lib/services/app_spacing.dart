/// 8pt-grid spacing scale shared across the app's chrome. Replaces magic
/// numbers (12, 16, ...) repeated per widget.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner-radius scale matching the values already in use across the
/// app's cards and panels.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}
