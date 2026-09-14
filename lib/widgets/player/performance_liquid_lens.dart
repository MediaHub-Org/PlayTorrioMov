import 'package:flutter/material.dart';

/// A translucent panel decoration, used behind the player's menu buttons and
/// sheets.
///
/// Lives under `widgets/player/` rather than `widgets/common/`, where it used
/// to sit despite the player being its only caller: player chrome is the one
/// surface deliberately excluded from the theme tokens (it sits over video
/// and stays dark whatever the app is set to), and a file in `common/` looks
/// like a shared widget somebody should migrate. Its gradient is a fixed dark
/// for exactly that reason.
class PerformanceLiquidLens extends StatelessWidget {
  final Widget child;

  const PerformanceLiquidLens({
    super.key,
    required this.child,
  });

  static const BoxDecoration _decoration = BoxDecoration(
    borderRadius: BorderRadius.all(Radius.circular(24)),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xF01A1D27), Color(0xF012151E)],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _decoration,
      child: child,
    );
  }
}
