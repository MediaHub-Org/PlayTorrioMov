import 'focus_highlight.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_units.dart';
import 'section_chips.dart';
import 'sidebar_logo.dart';
import '../../services/theme/app_colors.dart';

/// The slim global top bar shown above the hub's content, on every tier --
/// mobile included, as of the fix described below. Holds the PlayTorrio
/// logo and a Search + Settings button pair; on tablet and desktop the
/// hub's sections sit between them as chips (see [SectionChips]), all in
/// one row. Phones show the sections in the bottom tab bar instead (see
/// [AdaptiveNavShell]).
///
/// Search used to be a separate button embedded in each catalog page's own
/// header (Films, Series, Anime, Live TV), repeating the same icon four
/// times. One button here means one place to reach it regardless of which
/// section is active; [HubPage] still decides where it opens to (the
/// unified [SearchPage], or Live TV's own keyword search), same as each
/// page's button used to.
///
/// The sections used to be a second bar underneath. Merging them takes back
/// that bar's whole height and moves nothing: they were always at the top.
///
/// Mobile and tablet/desktop used to be two separate widgets with
/// independently-picked heights, padding, and button sizing, which drifted
/// the Settings icon a few px between tiers despite looking almost the
/// same. Rather than keep two copies in sync by hand, there is now exactly
/// one definition, built mobile-first (a `Row` with the logo in a
/// `Flexible` so it can actually shrink/ellipsize under a real phone
/// width, `Spacer()`, then the button) and reused unchanged on every tier
/// — not just visually matched, but the same widget, so it cannot drift
/// again. The previous tablet/desktop version used `Stack` + `Align`
/// instead, which doesn't bound the logo's width at all; that happened to
/// be safe as long as desktop always had room to spare, but was never a
/// definition mobile could have reused.
class TopBar extends StatelessWidget {
  /// The height available to the bar, or null for the standard one,
  /// [AppRem.bar] at the current text size. Callers should inset their content
  /// by this amount so nothing sits beneath the bar.
  final double? height;

  /// Invoked when the settings (gear) button is tapped.
  final VoidCallback? onSettingsTap;

  /// Invoked when the search button is tapped.
  final VoidCallback? onSearchTap;

  /// The standard bar's height at the default text size; it grows with the
  /// text (see [AppRem.bar]).
  static const double sharedHeight = AppRem.bar * AppUnits.remPixels;

  const TopBar({
    super.key,
    this.height,
    this.onSettingsTap,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    // AdaptiveNavShell passes `onSettingsTap`, so this one is not const --
    // but its parent is reached through a const HubPage, so the chain above
    // it does not rebuild either.
    AppColors.dependOn(context);
    final tier = AppBreakpoints.of(context);
    final hasSections = tier != ScreenTier.mobile;
    return Container(
      height: height ?? context.rem(AppRem.bar),
      decoration: BoxDecoration(
        color: AppColors.bar,
        border: Border(
          bottom: BorderSide(color: AppColors.inkAlpha(0.14)),
        ),
        boxShadow: [
          BoxShadow(
            // Tied to the ink, not to black: a 35%-black drop shadow under a
            // white bar reads as a smudge, where the same alpha under a dark
            // one is the lift this bar was designed with.
            color: AppColors.inkAlpha(0.35),
            blurRadius: context.rem(AppRem.blur),
            offset: Offset(0, context.rem(AppRem.xs)),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md)),
      // spaceBetween, not a Spacer() alongside Flexible: both default to
      // flex 1, so a Spacer sibling splits the remaining width evenly with
      // the logo's Flexible allocation instead of yielding it all -- since
      // Flexible only shrinks to content (FlexFit.loose) and Flutter's Flex
      // layout doesn't reclaim an undersized flex child's unused
      // allocation for its sibling, that leftover became a growing gap
      // between the logo and the button as the bar got wider. spaceBetween
      // has no such competition: the Flexible logo (alone, no competing
      // flex sibling) shrinks to its own content, and spaceBetween pushes
      // whatever's actually left to the far right.
      child: hasSections
          ? Row(
              children: [
                // The wordmark gives way on a tablet: logo, five chips and
                // Search + Settings do not fit 600px with it.
                SidebarLogo(showWordmark: tier == ScreenTier.desktop),
                const Expanded(child: SectionChips()),
                if (onSearchTap != null) ...[
                  SearchIconButton(onTap: onSearchTap!),
                  SizedBox(width: context.rem(AppRem.sm)),
                ],
                if (onSettingsTap != null)
                  SettingsIconButton(onTap: onSettingsTap!),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(child: SidebarLogo()),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onSearchTap != null) ...[
                      SearchIconButton(onTap: onSearchTap!),
                      SizedBox(width: context.rem(AppRem.sm)),
                    ],
                    if (onSettingsTap != null)
                      SettingsIconButton(onTap: onSettingsTap!),
                  ],
                ),
              ],
            ),
    );
  }
}

/// The Settings (gear) button, identical wherever it appears -- currently
/// [TopBar] (tablet/desktop) and [AdaptiveNavShell]'s mobile top bar -- so
/// its exact size and icon inset never drift between them.
class SettingsIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const SettingsIconButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return FocusHighlight(
      child: IconButton(
        onPressed: onTap,
        tooltip: context.l10n.commonSettings,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
        width: context.rem(AppRem.target),
        height: context.rem(AppRem.target),
      ),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.inkAlpha(0.04),
          foregroundColor: AppColors.inkMuted,
        ),
        icon: Icon(Icons.settings_rounded, size: context.rem(AppRem.icon)),
      ),
    );
  }
}

/// The Search button, styled to match [SettingsIconButton] since the two
/// now sit side by side in [TopBar].
class SearchIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const SearchIconButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return FocusHighlight(
      child: IconButton(
        onPressed: onTap,
        tooltip: context.l10n.commonSearch,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
        width: context.rem(AppRem.target),
        height: context.rem(AppRem.target),
      ),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.inkAlpha(0.04),
          foregroundColor: AppColors.inkMuted,
        ),
        icon: Icon(Icons.search_rounded, size: context.rem(AppRem.icon)),
      ),
    );
  }
}
