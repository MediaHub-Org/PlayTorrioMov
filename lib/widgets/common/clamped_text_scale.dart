// lib/widgets/common/clamped_text_scale.dart
import 'package:flutter/material.dart';

/// Caps how far text inside [child] grows with the system text scale.
///
/// For content in a box whose size is fixed by something other than its own
/// text — a grid cell with a `childAspectRatio`, a pinned header height, a
/// tab bar. Those boxes cannot grow, so past some scale the text is painted
/// outside them and Flutter reports an overflow. Capping keeps the element
/// responsive to a larger setting without letting it leave the box.
///
/// This is a compromise and worth naming as one: a viewer who has asked the
/// system for 3x text does not get 3x here. The alternative is a layout that
/// grows, and where that is possible it is the better answer — see
/// `CollectionCard`, whose grid reserves label space from
/// `MediaQuery.textScalerOf` instead of clamping. Use this where the box
/// genuinely cannot move, as with `ContinueWatchingSlider.bandHeight`, which
/// `BrowseScaffold` has to derive from width alone without building the
/// widget.
///
/// [max] defaults to the ceiling the app already settled on across the nav
/// bar, the sidebar logo, the pill rows and the home row, so callers get the
/// house value by saying nothing.
class ClampedTextScale extends StatelessWidget {
  final double max;
  final Widget child;

  const ClampedTextScale({super.key, this.max = 1.3, required this.child});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: max),
      ),
      child: child,
    );
  }
}
