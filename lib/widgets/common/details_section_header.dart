import 'package:flutter/material.dart';
import '../../services/theme/app_colors.dart';

/// The heading above a section on a details page — Cast & Crew, Episodes,
/// Related, and so on.
///
/// One widget because the three details pages had already drifted: Movies
/// and Series used `FontWeight.bold` with `-0.3` letter spacing and 16px of
/// space beneath, Anime used `FontWeight.w800` with `-0.4` and none, and
/// Arabic anime had no headings at all — its Episodes and Related rails
/// simply began, with nothing naming them. Each choice was defensible on
/// its own; together they made the same page type read as three.
class DetailsSectionHeader extends StatelessWidget {
  final String title;

  /// Right-hand side of the heading row: a "See all", a count, a filter.
  /// Null on most headings.
  final Widget? trailing;

  const DetailsSectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final heading = Text(
      title,
      style: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: trailing == null
          ? heading
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: heading),
                // The trailing widget is a count or a "See all" -- text that
                // grows with the scale like the heading does. Flexible on the
                // heading alone let the pair still exceed the row: 195px at
                // 3x, because the heading shrank to its share and the count
                // beside it did not.
                Flexible(child: trailing!),
              ],
            ),
    );
  }
}
