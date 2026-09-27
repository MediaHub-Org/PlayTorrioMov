import 'package:flutter/widgets.dart';

/// Mirrors a physical [Alignment] for the reading direction in scope.
///
/// The right answer is almost always `AlignmentDirectional`, which resolves
/// itself and needs no `BuildContext`. This exists for the widgets that cannot
/// take one: `CachedNetworkImage.alignment` is declared `Alignment`, not
/// `AlignmentGeometry`, so an `AlignmentDirectional` there is a type error
/// rather than a fix. Three hero logos are in that position.
///
/// Mirroring is exact rather than a lookup, because an [Alignment] is just a
/// pair in -1..1 and the horizontal axis is the one that follows reading order.
Alignment mirroredIfRtl(BuildContext context, Alignment ltr) =>
    Directionality.of(context) == TextDirection.rtl
        ? Alignment(-ltr.x, ltr.y)
        : ltr;
