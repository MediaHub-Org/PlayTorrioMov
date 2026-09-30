import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_spacing.dart';
import '../../services/app_units.dart';
import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';
import '../../utils/hub_controller.dart';
import 'hover_button.dart';

/// The hub's navigation on a TV: the sections, Search and Settings as a
/// vertical rail on the left, in place of the top bar.
///
/// It rests as a narrow rail of icons and opens into a labelled panel while
/// the remote has focus in it -- the pattern Android TV's own navigation
/// drawer and the big streaming apps use. A permanently wide menu took a
/// tenth of a 1080p screen from the posters for something used a few times a
/// session; a menu hidden behind a button needs a first press just to find it.
/// The icons are always there to find, and the labels come to whoever reaches
/// for them.
///
/// The panel opens *over* the content and does not move it, and only the
/// icon pills take focus: the labels hang outside their pill's box. Directional
/// traversal works off the focused box, and a label-wide item would sit over
/// the first card's column, which is enough to make Right skip that card.
///
/// It is built inside the content's own route (see [TvHubFrame]), not next to
/// it. The top bar sits outside `NestedNavigator`'s `Navigator`, and each
/// route has its own focus scope, which directional traversal cannot cross:
/// the remote could move through the rows but never up to the bar, through
/// two attempts to bridge the gap by hand. Here the rail and the rows are in
/// one scope, so pressing Left from the first card of any row reaches it with
/// nothing but ordinary traversal -- the one thing known to work on the
/// device.
class TvSideMenu extends StatefulWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;

  const TvSideMenu({
    super.key,
    required this.onSearchTap,
    required this.onSettingsTap,
  });

  /// The resting width, which is the room [TvHubFrame] leaves for it.
  static double railWidthFor(BuildContext context) =>
      context.rem(AppRem.menuRail);

  /// The open panel's width. Proportional to the window like the poster
  /// cards, not a fixed number: wide enough for "Live TV" and its icon at
  /// couch distance, never more than a tenth-odd of the screen.
  static double widthFor(BuildContext context) =>
      AppSpacing.cardWidthForScreenWidth(
        MediaQuery.sizeOf(context).width,
        min: context.rem(AppRem.menuMin),
        max: context.rem(AppRem.menuMax),
        factor: 0.11,
      );

  @override
  State<TvSideMenu> createState() => _TvSideMenuState();
}

class _TvSideMenuState extends State<TvSideMenu> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final rail = TvSideMenu.railWidthFor(context);
    final panel = TvSideMenu.widthFor(context);
    final item = context.rem(AppRem.railItem);
    final gap = context.rem(AppRem.sm);
    // The label starts one gap past its pill and stops one gap short of the
    // panel's edge.
    final labelWidth = panel - (rail + item) / 2 - gap - gap;

    return Focus(
      // Not a stop of its own: it only hears that focus is somewhere inside.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (hasFocus != _open) setState(() => _open = hasFocus);
      },
      child: SizedBox(
        width: rail,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: _open ? panel : rail,
                  decoration: BoxDecoration(
                    color: AppColors.bar,
                    border: Border(
                      right: BorderSide(color: AppColors.inkAlpha(0.14)),
                    ),
                    boxShadow: [
                      if (_open)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: context.rem(AppRem.blur),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + context.rem(AppRem.md),
                  bottom: context.rem(AppRem.md),
                ),
                child: ListenableBuilder(
                  listenable: HubController.instance,
                  builder: (context, _) {
                    final sections = HubController.instance.currentSections;
                    final activeId = HubController.instance.currentSectionId;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (final section in sections)
                          _MenuItem(
                            icon: section.icon,
                            label: section.localizedLabel(context),
                            selected: section.id == activeId,
                            open: _open,
                            labelWidth: labelWidth,
                            onTap: () => HubController.instance
                                .setCurrentSection(section.id),
                          ),
                        const Spacer(),
                        _MenuItem(
                          icon: Icons.search_rounded,
                          label: context.l10n.commonSearch,
                          selected: false,
                          open: _open,
                          labelWidth: labelWidth,
                          onTap: widget.onSearchTap,
                        ),
                        _MenuItem(
                          icon: Icons.settings_rounded,
                          label: context.l10n.commonSettings,
                          selected: false,
                          open: _open,
                          labelWidth: labelWidth,
                          onTap: widget.onSettingsTap,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool open;
  final double labelWidth;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.open,
    required this.labelWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final accent = AppThemeService.currentPalette.value.primaryColor;
    final foreground = selected ? AppColors.onAccent : AppColors.inkSubtle;
    final radius = context.rem(AppRem.radiusMd);
    final pill = context.rem(AppRem.railItem);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.xxs)),
      child: HoverButton(
        scaleAmount: 1.03,
        showFocusRing: true,
        focusRingBorderRadius: radius + context.rem(AppRem.xs),
        onTap: onTap,
        // The pill is the whole of what takes focus; the label is laid out
        // past its edge (see the class doc of [TvSideMenu]).
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: pill,
              height: pill,
              decoration: BoxDecoration(
                color: selected ? accent : AppColors.inkAlpha(0.05),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Icon(icon, size: context.rem(AppRem.icon), color: foreground),
            ),
            Positioned(
              left: pill + context.rem(AppRem.sm),
              top: 0,
              bottom: 0,
              width: labelWidth,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: open ? 1 : 0,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? AppColors.ink : AppColors.inkSubtle,
                        fontSize: AppType.body,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The content route on a TV: [menu] beside [child], in one focus scope.
///
/// The content is laid out next to the menu's resting rail, and the menu
/// paints on top so that opening it covers the content instead of pushing it.
class TvHubFrame extends StatelessWidget {
  final Widget menu;
  final Widget child;

  const TvHubFrame({super.key, required this.menu, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          left: TvSideMenu.railWidthFor(context),
          child: child,
        ),
        Positioned(left: 0, top: 0, bottom: 0, child: menu),
      ],
    );
  }
}
