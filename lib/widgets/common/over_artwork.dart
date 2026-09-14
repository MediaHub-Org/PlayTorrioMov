import 'package:flutter/material.dart';
import '../../services/theme/app_colors.dart';

/// Marks a subtree as drawn over artwork rather than over the page.
///
/// The same control appears in both places in this app. A genre chip sits on
/// a hero slide's backdrop on the browse pages and on the page background on
/// a details page; the header pill row floats over the hero carousel on some
/// of a page's states and sits in its own band on the others. Over a
/// photograph the right foreground is white in either theme — a photograph
/// does not change with the theme — and over the page it is the theme's ink.
///
/// The widgets cannot be told through a constructor: they are built by
/// callers and passed in already-constructed ([BrowseScaffold]'s header), or
/// they are shared widgets used from both kinds of place ([GenreTagRow]).
/// So the answer travels down the tree. Absent an ancestor it is "no", which
/// is right everywhere outside a hero.
class OverArtwork extends InheritedWidget {
  final bool value;

  const OverArtwork({super.key, required this.value, required super.child});

  /// Wraps [child] as being over artwork. Reads better at the call site than
  /// `OverArtwork(value: true, child: ...)` where that is the whole point.
  const OverArtwork.yes({super.key, required super.child}) : value = true;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OverArtwork>()?.value ?? false;

  /// The foreground colour for this subtree: fixed white over artwork, the
  /// theme's ink otherwise. Everything a control draws — its glyph, its
  /// label, its border, its background wash — should come from this one
  /// value at different opacities, so a control cannot end up with a light
  /// border and a dark glyph.
  static Color tint(BuildContext context) =>
      of(context) ? AppColors.onAccent : AppColors.ink;

  @override
  bool updateShouldNotify(OverArtwork oldWidget) => oldWidget.value != value;
}
