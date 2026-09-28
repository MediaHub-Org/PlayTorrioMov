import 'package:flutter/material.dart';

import '../../services/tv_mode_service.dart';
import 'route_transitions.dart';

/// Shows [builder]'s content as a modal bottom sheet -- or, on an actual
/// Android TV, pushes it as a full-screen page instead.
///
/// A bottom sheet dismisses by a drag gesture or a tap outside it, neither
/// of which a D-pad/remote can produce. The system Back button a remote
/// does have already works against a normally pushed route the same way it
/// works against every other page in the app, so that is what a TV gets
/// instead. The sheet's own content and interaction logic (what it shows,
/// what it pops with) are unchanged either way -- only the presentation
/// swaps. See phase 3 of #80 in docs/ROADMAP.md.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
  ShapeBorder? shape,
}) {
  if (TvModeService.isTv.value) {
    return pushPage<T>(context, Builder(builder: builder));
  }
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    isScrollControlled: isScrollControlled,
    shape: shape,
    builder: builder,
  );
}
