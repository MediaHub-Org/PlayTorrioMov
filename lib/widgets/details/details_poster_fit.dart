import 'package:flutter/widgets.dart';

import '../../services/app_spacing.dart';
import '../../services/app_units.dart';
import 'details_metrics.dart';

/// Sizes the details page's poster so the Play button under it stays on
/// screen, centering it in the column the buttons share.
///
/// The poster column is a fixed 17.5 rem wide and the poster is 2:3, so it
/// is always 26 rem tall -- fine on a desktop window, but on a 960x540 TV
/// layout it took the whole screen and left Play, which sits under it, at or
/// past the bottom edge (#80, reported from a TV). The poster gives up width
/// instead, down to a floor: the buttons below it keep the full column, so
/// they stay as easy to hit, and nothing changes in a window tall enough to
/// show both.
class DetailsPosterFit extends StatelessWidget {
  final Widget child;

  const DetailsPosterFit({super.key, required this.child});

  /// The poster's width for this window: the column's width when the whole
  /// column fits, less when it would not.
  static double posterWidthOf(BuildContext context) {
    final column = context.rem(DetailsDim.desktopPoster);
    final topGap = AppSpacing.floatingTopInset(context) +
        context.rem(DetailsDim.backButton) +
        context.rem(DetailsSpace.md);
    final room = MediaQuery.sizeOf(context).height -
        topGap -
        context.rem(DetailsDim.belowPoster);
    // 2:3, so width is two thirds of the height it may take.
    return (room * 2 / 3).clamp(context.rem(DetailsDim.posterFloor), column);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(width: posterWidthOf(context), child: child),
    );
  }
}
