import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import '../../services/theme/app_colors.dart';

/// Design tokens and glass styling for the modern video player UI.
class PlayerTheme {
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
  static const List<BoxShadow> menuShadow = [
    BoxShadow(
      color: Color(0xCC000000),
      offset: Offset(0, 24),
      blurRadius: 60,
      spreadRadius: -18,
    ),
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 10),
      blurRadius: 30,
      spreadRadius: -5,
    ),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x4D000000),
      offset: Offset(0, 4),
      blurRadius: 16,
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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? PlayerTheme.menuShadow,
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
              border: border ?? Border.all(color: PlayerTheme.edge, width: 1),
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

  const PlayerMenuAnchor({super.key, required this.child});

  /// Clearance for the transport bar the popover sits above, plus whatever
  /// the system puts below it (gesture bar, home indicator).
  ///
  /// Measured against the bar itself rather than guessed: on a compact
  /// (phone) screen the bar is 32px top padding + 36px seek row + 8px gap +
  /// 36px buttons + 14px bottom padding -- about 126px. The old 76 left the
  /// bottom of a menu card sitting on top of the subtitle and settings
  /// buttons, so the icons were hidden while the menu was open and the
  /// first tap "missed" what the user could see. The wide-screen figure is
  /// the same bar at its larger sizes.
  static double bottomInset(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isShort = size.height < 500;
    final isCompact = size.width < 680;
    // The menu sits just above the transport bar's buttons -- close enough
    // that the row it belongs to is visibly the row it floats over. The
    // figure is the buttons row (36/42) plus the bar's bottom padding and a
    // few px of air, not the whole bar: clearing everything put the card a
    // hand's width above the icons, floating mid-screen.
    return (isShort ? 46.0 : (isCompact ? 62.0 : 78.0)) +
        MediaQuery.paddingOf(context).bottom;
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
  static double availableHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).height -
              topInset(context) -
              bottomInset(context))
          .clamp(160.0, double.infinity);

  @override
  Widget build(BuildContext context) {
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
        // screen has no spare width, so the card centres over the full span.
        alignment: isNarrow ? Alignment.bottomCenter : Alignment.bottomRight,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
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
/// There is deliberately no close button. Tapping anywhere off the panel
/// dismisses it (player_screen.dart puts a full-screen barrier behind every
/// open menu), so an X was a third way to do what the barrier and the back
/// arrow already did -- and it cost the header's whole right end, which on a
/// narrow card is the room the title needed.
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
                  size: 28,
                  iconSize: 14,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  tooltip: context.l10n.playerBackToSettings,
                  onPressed: back,
                ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: back != null ? 4 : 8,
                    right: 8,
                    top: 4,
                    bottom: 4,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PlayerTheme.inkSubtle,
                      fontSize: 10.5,
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

/// A focus indicator for D-pad/keyboard navigation: a rounded ring drawn
/// just outside the widget it wraps.
///
/// The player's controls were built pointer-first -- GestureDetector, no
/// Focus -- so a remote's directional pad could not reach them at all, and
/// a keyboard's Tab key moved focus invisibly. This is the visible half of
/// fixing that; the interactive widgets wrap themselves in a [Focus] and
/// show this ring when they have it.
class FocusRing extends StatelessWidget {
  final bool visible;
  final double borderRadius;
  final Widget child;

  const FocusRing({
    super.key,
    required this.visible,
    this.borderRadius = 9999,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: PlayerTheme.accent, width: 2),
      ),
      // A little outside the widget, so the ring reads as marking it rather
      // than as a border of it.
      padding: const EdgeInsets.all(2),
      child: child,
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
  });

  @override
  State<PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<PlayerIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? (widget.activeColor ?? Colors.white.withValues(alpha: 0.22))
        : (_hovered
            ? (widget.backgroundColor ?? Colors.white.withValues(alpha: 0.12))
            : (widget.backgroundColor ?? Colors.transparent));

    final iconContent = Stack(
      alignment: Alignment.center,
      children: [
        IconTheme(
          data: IconThemeData(
            color: widget.active ? Colors.white : (_hovered ? Colors.white : PlayerTheme.inkMuted),
            size: widget.iconSize,
          ),
          child: widget.icon,
        ),
        if (widget.showActiveBadge)
          Positioned(
            top: widget.size * 0.2,
            right: widget.size * 0.2,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.badgeColor ?? PlayerTheme.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.badgeColor ?? PlayerTheme.accent).withValues(alpha: 0.8),
                    blurRadius: 4,
                    spreadRadius: 1,
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

    Widget button = MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: buttonBody,
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: const Color(0xE6080C12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PlayerTheme.edgeSoft),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
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
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: widget.active
                  ? PlayerTheme.raised
                  : ((_hovered || _focused)
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: widget.active
                    ? PlayerTheme.edge
                    : ((_hovered || _focused)
                          ? PlayerTheme.edgeSoft
                          : Colors.transparent),
                width: 1,
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
                      fontSize: 11.5,
                      fontWeight: widget.active
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.count != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    widget.count!,
                    style: const TextStyle(
                      color: PlayerTheme.inkSubtle,
                      fontSize: 11,
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
        borderRadius: 12,
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

