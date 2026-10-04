import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../common/focus_ring.dart';
import '../../services/app_units.dart';
import '../../services/tv_mode_service.dart';
import 'player_panel.dart';

export '../common/focus_ring.dart';

/// Design tokens and glass styling for the modern video player UI.
class PlayerTheme {
  /// The width every player popover is built at.
  ///
  /// One number rather than one per menu. They were 280, 320 and 330, which
  /// meant the panel jumped sideways as a viewer moved between them, and it
  /// made grouping any two of them under a single icon a layout change
  /// rather than a wiring change. A menu that needs more room than this
  /// should say why in its own file.
  static const double menuWidthRem = 20;

  /// The width a popover clamps to on a narrow screen, leaving a gutter.
  static double menuWidthFor(BuildContext context) =>
      context.rem(menuWidthRem).clamp(
        context.rem(15),
        MediaQuery.sizeOf(context).width - context.rem(AppRem.xl),
      );

  // Backgrounds & Surfaces
  static const Color canvas = Color(0xFF080C12);
  static const Color elevated = Color(0xF0101622);
  static const Color raised = Color(0x1AFFFFFF); // 10% white
  static const Color surfaceHover = Color(0x22FFFFFF); // 13% white

  // Borders
  static const Color edge = Color(0x1FFFFFFF); // 12% white
  static const Color edgeSoft = Color(0x12FFFFFF); // 7% white

  // Accents
  // Getters, not variables: a top-level or static variable is initialized
  // lazily, once, on its first read -- which would freeze whichever theme
  // happened to be active when this screen was first opened, and leave it
  // there through every later theme change.
  static Color get accent => AppColors.accent;
  static const Color accentSoft = Color(0x337C5CFF);
  static const Color accentGlow = Color(0x667C5CFF);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // Typography / Text Colors
  static const Color ink = Colors.white;
  static const Color inkMuted = Color(0xB3FFFFFF); // 70% white
  static const Color inkSubtle = Color(0x66FFFFFF); // 40% white
  static const Color inkDisabled = Color(0x33FFFFFF); // 20% white

  // Shadows
  // Functions, not constants: the offsets and blurs are in rem, so they follow
  // the text size like everything else the menus are built from.
  static List<BoxShadow> menuShadowOf(BuildContext context) => [
    BoxShadow(
      color: const Color(0xCC000000),
      offset: Offset(0, context.rem(AppRem.lg)),
      blurRadius: context.rem(3.75),
      spreadRadius: -context.rem(1.125),
    ),
    BoxShadow(
      color: const Color(0x40000000),
      offset: Offset(0, context.rem(AppRem.pillGap)),
      blurRadius: context.rem(1.875),
      spreadRadius: -context.rem(0.3125),
    ),
  ];

  static List<BoxShadow> buttonShadowOf(BuildContext context) => [
    BoxShadow(
      color: const Color(0x4D000000),
      offset: Offset(0, context.rem(AppRem.xs)),
      blurRadius: context.rem(AppRem.md),
    ),
  ];
}

/// Floating Frosted Glass Card for menus, dialogs, and popovers.
class PlayerGlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Border? border;
  final List<BoxShadow>? shadows;
  final Color? backgroundColor;

  const PlayerGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20,
    this.padding = EdgeInsets.zero,
    this.border,
    this.shadows,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // In a sheet the sheet is the card: it draws the surface, the edge and the
    // shadow, and is as wide as it is, so a menu's own chrome and fixed width
    // would be a card inside a card. A menu that asked for a height (the
    // subtitle panel, whose rows share it) keeps asking, of the room the
    // sheet has.
    final scope = PlayerPanelScope.maybeOf(context);
    if (scope != null && scope.style != PlayerPanelStyle.popover) {
      return SizedBox(
        width: double.infinity,
        height: height == null ? null : scope.contentHeight,
        child: Padding(padding: padding, child: child),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? PlayerTheme.menuShadowOf(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? PlayerTheme.elevated,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(color: PlayerTheme.edge, width: 1), // px: a hairline, not a layout size
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Where every player popover sits: pinned above the transport bar, inset
/// from the screen edge, and never taller than the space it has.
///
/// This replaced six hand-tuned `Positioned` blocks in player_screen.dart
/// that each carried their own breakpoint ladder. They had drifted -- only
/// the subtitle menu handled a narrow screen by spanning both edges, and
/// none of them bounded their own height, so the speed menu (seven presets,
/// a divider and a sleep-timer row, about 430px of card) simply ran off the
/// top of a landscape phone: the card is bottom-anchored, so height it does
/// not have goes upward, out of the viewport, with nothing to clip or
/// scroll it.
///
/// Must be a direct child of a [Stack] -- it builds a [Positioned].
class PlayerMenuAnchor extends StatelessWidget {
  final Widget child;

  /// Closes the menu, for the ways a sheet can be sent away: the scrim, the
  /// close button, a swipe. Null leaves those off; the popover never uses it
  /// (it is dismissed by the barrier behind it and by Back).
  final VoidCallback? onClose;

  const PlayerMenuAnchor({super.key, required this.child, this.onClose});

  /// Clearance for the transport bar the popover sits above, plus whatever
  /// the system puts below it (gesture bar, home indicator).
  ///
  /// Measured against the bar itself rather than guessed: the menu sits just
  /// above the playback line, so the seek bar stays visible and scrubbable
  /// while a menu is open. The figure mirrors the transport bar's own build
  /// (its top padding, the 2.25 rem seek row, the gap, the buttons row and
  /// the bottom padding) plus air you can see -- a tight gap read as the
  /// card touching the bar and the seek row's end time with it -- in rem so
  /// it grows with the text size exactly as the bar does.
  static double bottomInset(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 680;
    final bar =
        (isCompact ? AppRem.xl : 3.0) +
        2.25 +
        (isCompact ? AppRem.xs : AppRem.sm) +
        (isCompact ? 2.25 : 2.625) +
        (isCompact ? 0.875 : AppRem.lg);
    return context.rem(bar + 0.75) + MediaQuery.paddingOf(context).bottom;
  }

  /// Clearance for the title bar above. Being bounded at the top is the
  /// whole point: it is what turns "too tall" into a scroll instead of an
  /// overflow off-screen.
  static double topInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      (MediaQuery.sizeOf(context).height < 500 ? 8.0 : 12.0);

  static double sideInset(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 560) return 8.0;
    if (width < 680) return 12.0;
    return 28.0;
  }

  /// How tall a popover can be before it has to scroll.
  ///
  /// A menu that sets its own fixed height -- the subtitle panel does, so
  /// its two columns can share one [Expanded] -- should clamp to this
  /// rather than to a number of its own, or it picks a height the anchor
  /// cannot give it and scrolls for the difference.
  static double availableHeight(BuildContext context) {
    // In a sheet the room is the sheet's, not the popover's gap above the bar.
    final scope = PlayerPanelScope.maybeOf(context);
    if (scope != null && scope.style != PlayerPanelStyle.popover) {
      return scope.contentHeight;
    }
    return (MediaQuery.sizeOf(context).height -
            topInset(context) -
            bottomInset(context))
        .clamp(160.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final style = playerPanelStyleFor(
      size: MediaQuery.sizeOf(context),
      isTv: TvModeService.isTv.value,
      isTouch: playerPanelIsTouch(),
    );
    if (style != PlayerPanelStyle.popover) {
      return PlayerSheet(style: style, onClose: onClose, child: child);
    }
    final isNarrow = MediaQuery.sizeOf(context).width < 560;
    final top = topInset(context);
    final bottom = bottomInset(context);
    final side = sideInset(context);

    return Positioned(
      top: top,
      bottom: bottom,
      // Both edges, always: pinning only `right` leaves the child with an
      // unbounded width, which is how a Row inside one of these overflows
      // instead of laying out.
      left: side,
      right: side,
      child: Align(
        // Wide enough to have a corner to sit in, it sits in it; a narrow
        // screen has no spare width, so the card centers over the full span.
        alignment: isNarrow
            ? AlignmentDirectional.bottomCenter
            : AlignmentDirectional.bottomEnd,
        // A scope of its own that takes focus when the menu opens. Without
        // it focus stayed on the button that opened the menu, and a remote's
        // arrows went to whatever was nearest that button -- the seek bar, not
        // the rows -- so the audio, speed, sleep timer and aspect menus
        // opened and could not be used (#80). Inside a scope the arrows stay
        // on the menu's own rows; closing it hands focus back to the button.
        child: PlayerFocusOnOpen(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A focus scope that takes focus when it is first built. Public so the
/// sheets in `player_panel.dart` can use it as the popover does.
///
/// `FocusScope(autofocus: true)` is not enough: autofocus does nothing when
/// the enclosing scope already has a focused child, and in the player it always
/// does -- the button that opened the menu. So the request is made by hand,
/// after the first frame, once the rows exist for it to land on.
class PlayerFocusOnOpen extends StatefulWidget {
  final Widget child;

  const PlayerFocusOnOpen({super.key, required this.child});

  @override
  State<PlayerFocusOnOpen> createState() => _PlayerFocusOnOpenState();
}

class _PlayerFocusOnOpenState extends State<PlayerFocusOnOpen> {
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'PlayerMenu');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Asking the scope honors a child that asked for focus (a slider that is
      // the menu's main control); but it can also leave the scope itself as
      // the focused node, with nothing in it focused, so then the first row
      // has to be asked for by name.
      _scope.requestFocus();
      // Focus changes apply a microtask later, so the answer is read then.
      Future.microtask(() {
        if (!mounted || FocusManager.instance.primaryFocus != _scope) return;
        final policy = FocusTraversalGroup.maybeOf(context) ??
            ReadingOrderTraversalPolicy();
        policy.findFirstFocus(_scope, ignoreCurrentFocus: true)?.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FocusScope(node: _scope, child: widget.child);
}

/// Interactive button with smooth hover effects, tooltips, and badges.
/// The header every player menu wears: a label and, below the root, a way
/// back.
///
/// The menus are one panel that swaps contents, not a stack of popovers --
/// but without [onBack] they read as the latter: opening Settings, stepping
/// into Subtitles, then wanting Aspect ratio meant closing and reopening the
/// gear, because nothing on the panel led back. The arrow makes the panel
/// navigable, so the deepest thing in it is two taps from the gear and one
/// tap from anywhere else.
///
/// There is deliberately no close button *in the header*. Tapping off the panel
/// dismisses it (a scrim or a barrier sits behind every open menu), so an X
/// here was a third way to do what the barrier and the back arrow already
/// did -- and it cost the header's whole right end, which on a narrow card is
/// the room the title needed. A side sheet on a touch screen does carry an X,
/// but in a strip of its own above the menu, and a bottom sheet a grabber;
/// see `PlayerSheet` in `player_panel.dart` for who gets what and why.
class PlayerMenuHeader extends StatelessWidget {
  final String title;

  /// Shown as a back arrow to the left of the title. Null on a root menu,
  /// which has nowhere to go back to.
  final VoidCallback? onBack;

  /// Sits at the trailing end of the header, for a menu that has a real
  /// action to put there. Not a close button.
  final Widget? trailing;

  const PlayerMenuHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    final end = trailing;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (back != null)
                PlayerIconButton(
                  size: context.rem(1.75),
                  iconSize: context.rem(0.875),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  tooltip: context.l10n.playerBackToSettings,
                  onPressed: back,
                ),
              Flexible(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: context.rem(back != null ? AppRem.xs : AppRem.sm),
                    end: context.rem(AppRem.sm),
                    top: context.rem(AppRem.xs),
                    bottom: context.rem(AppRem.xs),
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PlayerTheme.inkSubtle,
                      fontSize: TvType.scale(AppType.microPlus),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (end != null) end,
      ],
    );
  }
}

class PlayerIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool active;
  final Color? activeColor;
  final bool showActiveBadge;
  final Color? badgeColor;
  final Color? backgroundColor;
  final double borderRadius;

  /// Whether this button takes focus as soon as it is built. Off by
  /// default, for the same reason as [PlayerStepSlider]'s own autofocus is
  /// on: only the menu's primary control should claim it, and most icon
  /// buttons sit in a row where nothing should jump ahead of the others.
  final bool autofocus;

  /// The button's own focus node, for a neighbor that names it as where an
  /// arrow goes (the seek bar's Down is the volume button).
  final FocusNode? focusNode;

  const PlayerIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 44,
    this.iconSize = 22,
    this.active = false,
    this.activeColor,
    this.showActiveBadge = false,
    this.badgeColor,
    this.backgroundColor,
    this.borderRadius = 9999,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<PlayerIconButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? (widget.activeColor ?? Colors.white.withValues(alpha: 0.22))
        : ((_hovered || _focused)
            ? (widget.backgroundColor ?? Colors.white.withValues(alpha: 0.12))
            : (widget.backgroundColor ?? Colors.transparent));

    final iconContent = Stack(
      alignment: Alignment.center,
      children: [
        IconTheme(
          data: IconThemeData(
            color: widget.active ? Colors.white : ((_hovered || _focused) ? Colors.white : PlayerTheme.inkMuted),
            size: widget.iconSize,
          ),
          child: widget.icon,
        ),
        if (widget.showActiveBadge)
          Positioned(
            top: widget.size * 0.2,
            right: widget.size * 0.2,
            child: Container(
              width: context.rem(AppRem.snug),
              height: context.rem(AppRem.snug),
              decoration: BoxDecoration(
                color: widget.badgeColor ?? PlayerTheme.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.badgeColor ?? PlayerTheme.accent).withValues(alpha: 0.8),
                    blurRadius: context.rem(AppRem.xs),
                    spreadRadius: context.rem(0.0625),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final buttonBody = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: iconContent,
    );

    Widget button = Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.select &&
            event.logicalKey != LogicalKeyboardKey.enter) {
          return KeyEventResult.ignored;
        }
        if (widget.onPressed == null) return KeyEventResult.ignored;
        widget.onPressed!();
        return KeyEventResult.handled;
      },
      child: FocusRing(
        visible: _focused,
        borderRadius: widget.borderRadius,
        child: MouseRegion(
          cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: buttonBody,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: const Color(0xE6080C12),
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
          border: Border.all(color: PlayerTheme.edgeSoft),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: AppType.caption,
          fontWeight: FontWeight.w500,
        ),
        child: button,
      );
    }

    return button;
  }
}

/// Rounded pill toggle chip for filters and options.
class PlayerToggleChip extends StatefulWidget {
  final bool active;
  final String label;
  final String? count;
  final VoidCallback onClick;
  final bool disabled;

  const PlayerToggleChip({
    super.key,
    required this.active,
    required this.label,
    this.count,
    required this.onClick,
    this.disabled = false,
  });

  @override
  State<PlayerToggleChip> createState() => _PlayerToggleChipState();
}

class _PlayerToggleChipState extends State<PlayerToggleChip> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          if (!widget.disabled) widget.onClick();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusRing(
        visible: _focused,
        child: MouseRegion(
        // Hover feedback on a chip: without it the sleep timer presets and
        // the subtitle filters read as labels rather than buttons, and the
        // only way to learn they press is to press them.
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        // The tap lives here. Only the D-pad's select key called onClick, so a
        // mouse or a finger on the CC / Forced filters did nothing at all.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled ? null : widget.onClick,
          child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.disabled ? 0.35 : 1.0,
          child: AnimatedContainer(
            height: context.rem(1.75),
            padding: EdgeInsets.symmetric(horizontal: context.rem(0.625)),
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: widget.active
                  ? PlayerTheme.raised
                  : ((_hovered || _focused)
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(9999), // px: a hairline, not a layout size
              border: Border.all(
                color: widget.active
                    ? PlayerTheme.edge
                    : ((_hovered || _focused)
                          ? PlayerTheme.edgeSoft
                          : Colors.transparent),
                width: 1, // px: a hairline, not a layout size
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flexible, not bare: a chip is sized by its label, and at a
                // large text scale the label can want more than the row it
                // sits in has -- 13px past the settings card on the sleep
                // timer presets. Ellipsizing a chip label beats painting it
                // over the neighbouring one.
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.active
                          ? PlayerTheme.ink
                          : PlayerTheme.inkMuted,
                      fontSize: AppType.tinyPlus,
                      fontWeight: widget.active
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.count != null) ...[
                  SizedBox(width: context.rem(AppRem.xs)),
                  Text(
                    widget.count!,
                    style: const TextStyle(
                      color: PlayerTheme.inkSubtle,
                      fontSize: AppType.tiny,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
      ),
    );
  }
}

/// A discrete slider that a D-pad can actually drive.
///
/// Material's [Slider] is pointer-only: a remote's left/right keys do
/// nothing to it, so on a TV the speed and sleep-timer sliders would be
/// visible but unreachable. This wraps one in a [Focus] that moves the
/// value one step per arrow press and shows the same [FocusRing] the
/// buttons use, so the control reads as selected from across the room.
///
/// [onChanged] fires on every step (live feedback); [onChangeEnd] fires
/// once the user stops, which is where the menus commit and close.
class PlayerStepSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? label;

  const PlayerStepSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.label,
  });

  @override
  State<PlayerStepSlider> createState() => _PlayerStepSliderState();
}

class _PlayerStepSliderState extends State<PlayerStepSlider> {
  bool _focused = false;

  double get _step => (widget.max - widget.min) / widget.divisions;

  void _nudge(int direction) {
    final next = (widget.value + _step * direction)
        .clamp(widget.min, widget.max);
    if (next == widget.value) return;
    widget.onChanged(next);
    widget.onChangeEnd?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // The slider is the primary control of the menu it lives in, so it
      // takes focus on open: a remote's arrows then work immediately
      // instead of needing a Tab press first.
      autofocus: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _nudge(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _nudge(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusRing(
        visible: _focused,
        borderRadius: context.rem(AppRem.radiusMd),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: PlayerTheme.accent,
            inactiveTrackColor: PlayerTheme.edgeSoft,
            thumbColor: PlayerTheme.accent,
            activeTickMarkColor: PlayerTheme.accent,
            inactiveTickMarkColor: PlayerTheme.inkSubtle,
          ),
          child: Slider(
            value: widget.value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: widget.label,
            onChanged: widget.onChanged,
            onChangeEnd: widget.onChangeEnd,
          ),
        ),
      ),
    );
  }
}

