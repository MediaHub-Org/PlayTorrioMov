import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The scroll view every settings page sits in.
///
/// Settings pages used to be written as
/// `Center(child: ConstrainedBox(maxWidth: 800, child: ListView(...)))`,
/// which put the *scrollable* inside an 800px column in the middle of the
/// window. Two things followed from that on desktop, both of them wrong:
///
///  - The scrollbar was drawn on that column's right edge, so on a wide
///    window it floated in the middle of the screen right against the
///    cards instead of sitting at the window edge where a scrollbar
///    belongs.
///  - The wheel only scrolled while the pointer was over that column.
///    Everywhere else -- most of a maximized window -- there was no
///    scrollable under the cursor, so the wheel did nothing at all.
///
/// This inverts the nesting: the scroll view fills the window and the
/// *content* is constrained, by asking for a horizontal padding wide
/// enough to center it. Same thing on screen, but the scrollable is now
/// the whole window, so the wheel works wherever the pointer is and the
/// scrollbar rides the window's own edge.
class SettingsScrollView extends StatefulWidget {
  /// The rows, for the plain-list form.
  final List<Widget>? children;

  /// The builder form, for a page long enough to want one.
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;

  /// The narrowest gutter, used when the window is too narrow to center
  /// anything -- a phone, where this is just the page's side padding.
  final double minGutter;

  final double topPadding;
  final double bottomPadding;

  /// How wide the content is allowed to get before the gutters take the
  /// rest. Matches the ConstrainedBox this replaced.
  final double maxContentWidth;

  const SettingsScrollView({
    super.key,
    required List<Widget> this.children,
    this.minGutter = 16,
    this.topPadding = 20,
    this.bottomPadding = 32,
    this.maxContentWidth = 800,
  }) : itemCount = null,
       itemBuilder = null,
       separatorBuilder = null;

  const SettingsScrollView.separated({
    super.key,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    required IndexedWidgetBuilder this.separatorBuilder,
    this.minGutter = 16,
    this.topPadding = 20,
    this.bottomPadding = 32,
    this.maxContentWidth = 800,
  }) : children = null;

  /// The side padding that centres [maxContentWidth] in [windowWidth],
  /// never narrower than [minGutter].
  ///
  /// Exposed so a page that builds its own scrollable -- one with a pinned
  /// header above the list, say -- can line its content up with every
  /// other settings page instead of picking its own number.
  static double gutterFor(
    double windowWidth, {
    double maxContentWidth = 800,
    double minGutter = 16,
  }) => math.max(minGutter, (windowWidth - maxContentWidth) / 2);

  @override
  State<SettingsScrollView> createState() => _SettingsScrollViewState();
}

class _SettingsScrollViewState extends State<SettingsScrollView> {
  // Owned here rather than passed in: Scrollbar and the list it draws for
  // have to share one controller, and every caller supplying its own was
  // how half these pages ended up with no scrollbar at all.
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gutter = SettingsScrollView.gutterFor(
      MediaQuery.sizeOf(context).width,
      maxContentWidth: widget.maxContentWidth,
      minGutter: widget.minGutter,
    );

    final padding = EdgeInsets.fromLTRB(
      gutter,
      widget.topPadding,
      gutter,
      widget.bottomPadding,
    );

    final children = widget.children;

    return Scrollbar(
      controller: _controller,
      child: children != null
          ? ListView(
              controller: _controller,
              padding: padding,
              children: children,
            )
          : ListView.separated(
              controller: _controller,
              padding: padding,
              itemCount: widget.itemCount!,
              separatorBuilder: widget.separatorBuilder!,
              itemBuilder: widget.itemBuilder!,
            ),
    );
  }
}
