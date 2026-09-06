import 'package:flutter/material.dart';

/// A translucent panel decoration, used behind player menu buttons/sheets.
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
