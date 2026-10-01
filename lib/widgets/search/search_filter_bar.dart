import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_spacing.dart';
import '../../services/app_units.dart';
import '../../services/theme/app_colors.dart';
import '../../utils/search_scope.dart';
import '../common/filter_dropdown.dart';
import '../common/hover_button.dart';

/// The decades the search offers, newest first. A fixed list, not "whatever
/// came back": the menu should not change shape under the finger as results
/// load, and results older than 1980 are rare enough to leave unfilterable.
const List<int> kSearchDecades = [2020, 2010, 2000, 1990, 1980];

/// The minimum ratings offered, on the 0-10 scale.
const List<int> kSearchMinRatings = [6, 7, 8];

/// Icon for a content type, for when the row has no room for its name.
IconData searchFilterIcon(SearchFilter filter) => switch (filter) {
  SearchFilter.all => Icons.apps_rounded,
  SearchFilter.movie => Icons.movie_outlined,
  SearchFilter.series => Icons.tv_rounded,
  SearchFilter.anime => Icons.animation_rounded,
};

/// The search page's filters: what to search (All, Films, Series, Anime), and
/// two narrowing menus every one of those can answer -- a decade and a
/// minimum rating. The same three on every tab, so switching the type never
/// changes what you can ask.
///
/// The row keeps to one line. It measures the words first and takes the
/// widest of three layouts that fits: everything in words; the type in words
/// with the two menus as icons; everything as icons (each with its name as a
/// tooltip and semantics label). Six icon-sized controls fit a 320 px phone,
/// so the icons are the floor; a horizontal scroll underneath catches only the
/// extreme case of a very large text size.
class SearchFilterBar extends StatelessWidget {
  final SearchFilter type;
  final ValueChanged<SearchFilter> onTypeChanged;
  final int? decade;
  final ValueChanged<int?> onDecadeChanged;
  final int? minRating;
  final ValueChanged<int?> onMinRatingChanged;

  const SearchFilterBar({
    super.key,
    required this.type,
    required this.onTypeChanged,
    required this.decade,
    required this.onDecadeChanged,
    required this.minRating,
    required this.onMinRatingChanged,
  });

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// How wide the four type chips are with their words showing.
  double _chipsWidth(BuildContext context, List<String> labels) {
    const style = TextStyle(
      fontSize: AppType.tinyPlus,
      fontWeight: FontWeight.w700,
    );
    final gap = context.rem(AppRem.snug);
    var total = 0.0;
    for (final label in labels) {
      total += _textWidth(context, label, style) + context.rem(1.25) + gap;
    }
    return total;
  }

  /// How wide one menu is with its words showing.
  double _menuWidth(BuildContext context, String label) {
    const style = TextStyle(
      fontSize: AppType.caption,
      fontWeight: FontWeight.w600,
    );
    // Padding either side, the icon and its gap, the menu arrow, the gap.
    return _textWidth(context, label, style) +
        context.rem(AppRem.ms) * 2 +
        context.rem(AppRem.iconXs) +
        context.rem(AppRem.snug) +
        context.rem(1.5) +
        context.rem(AppRem.snug);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    final decadeLabel = decade == null ? l10n.catalogAllDecades : '${decade}s';
    final ratingLabel = minRating == null
        ? l10n.searchAnyRating
        : '★ $minRating+';
    final chipLabels = [for (final f in SearchFilter.values) f.label(l10n)];
    final inset = AppSpacing.pageInset(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - inset * 2;
        // The widest the labels can ever be, not just what is selected now:
        // the row must not reflow between icons and words as a menu changes.
        // Three steps, widest first, and the first that fits wins: everything
        // in words; the type in words and the two menus as icons; everything
        // as icons. Measured against the widest label each can ever show, so
        // the row does not reflow as a menu changes.
        final chips = _chipsWidth(context, chipLabels);
        final menus = _menuWidth(
              context,
              _longest([
                l10n.catalogAllDecades,
                for (final d in kSearchDecades) '${d}s',
              ]),
            ) +
            _menuWidth(
              context,
              _longest([
                l10n.searchAnyRating,
                for (final r in kSearchMinRatings) '\u2605 $r+',
              ]),
            );
        final iconMenus = (context.rem(AppRem.target) + context.rem(AppRem.snug)) * 2;
        final showChipLabels = chips + iconMenus <= room;
        final showMenuLabels = chips + menus <= room;
        final gap = SizedBox(width: context.rem(AppRem.snug));

        return SizedBox(
          // The tap target plus the row's own padding, in rem, so it grows with
          // the text like everything inside it.
          height: context.rem(AppRem.target + AppRem.snug * 2),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: inset,
              vertical: context.rem(AppRem.snug),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: room),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final filter in SearchFilter.values) ...[
                    _TypeChip(
                      filter: filter,
                      selected: filter == type,
                      showLabel: showChipLabels,
                      onTap: () => onTypeChanged(filter),
                    ),
                    gap,
                  ],
                  FilterDropdown<int?>(
                    label: decadeLabel,
                    icon: Icons.calendar_today_rounded,
                    showLabel: showMenuLabels,
                    items: [
                      PopupMenuItem(
                        value: -1,
                        child: Text(l10n.catalogAllDecades),
                      ),
                      for (final d in kSearchDecades)
                        PopupMenuItem(value: d, child: Text('${d}s')),
                    ],
                    // A menu tap never delivers null (the framework reads
                    // that as a dismissal), so reset is a sentinel.
                    onSelected: (v) =>
                        onDecadeChanged(v == null || v < 0 ? null : v),
                  ),
                  gap,
                  FilterDropdown<int?>(
                    label: ratingLabel,
                    icon: Icons.star_rounded,
                    showLabel: showMenuLabels,
                    items: [
                      PopupMenuItem(
                        value: 0,
                        child: Text(l10n.searchAnyRating),
                      ),
                      for (final r in kSearchMinRatings)
                        PopupMenuItem(value: r, child: Text('★ $r+')),
                    ],
                    onSelected: (v) =>
                        onMinRatingChanged(v == null || v <= 0 ? null : v),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _longest(List<String> options) =>
      options.reduce((a, b) => b.length > a.length ? b : a);
}

class _TypeChip extends StatelessWidget {
  final SearchFilter filter;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  const _TypeChip({
    required this.filter,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final label = filter.label(context.l10n);
    final foreground = selected ? AppColors.ink : AppColors.inkAlpha(0.60);
    final radius = context.rem(AppRem.radiusSm);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        // The words are the tooltip when they are not on the chip.
        message: showLabel ? '' : label,
        child: HoverButton(
          scaleAmount: 1.05,
          focusFillRadius: radius,
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            constraints: BoxConstraints(minHeight: context.rem(AppRem.target)),
            padding: EdgeInsets.symmetric(
              horizontal: context.rem(showLabel ? 0.625 : AppRem.sm),
              vertical: context.rem(AppRem.snug),
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.raised,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: showLabel
                ? Text(
                    label,
                    style: TextStyle(
                      fontSize: AppType.tinyPlus,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: foreground,
                    ),
                  )
                : Icon(
                    searchFilterIcon(filter),
                    size: context.rem(AppRem.iconSm),
                    color: foreground,
                  ),
          ),
        ),
      ),
    );
  }
}
