import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_units.dart';
import '../../services/tv_mode_service.dart';
import 'player_glass.dart';

/// How a player menu is presented: the same contents in the shape each kind
/// of screen is good at.
enum PlayerPanelStyle {
  /// A card floating just above the transport bar. A pointer's shape: small,
  /// close to the button that opened it, dismissed by clicking away.
  popover,

  /// A full-height panel from the right edge, over a dimmed video. For a
  /// screen that is wide but short (a phone on its side), a tablet, and a TV,
  /// where a centered or bottom-anchored card has to scroll a long list that
  /// a column the height of the screen shows whole.
  sideSheet,

  /// A panel from the bottom edge, the full width. For a phone held upright,
  /// where the width is what is scarce and a drag down is what a thumb does.
  bottomSheet,
}

/// Picks the presentation for a screen.
///
/// Every menu used to be the same 20 rem card anchored bottom-right, whatever
/// it was shown on: on a phone it left most of the screen to the video and
/// squeezed the subtitle list into what remained, and on a TV it was a small
/// card at the edge of a very large picture. The shapes below are the ones the
/// big players use -- sheets from the bottom on a phone upright, a column from
/// the side wherever the screen is wide.
///
/// Size and platform decide it, nothing else, so it is a plain function that
/// a test can hold to account.
PlayerPanelStyle playerPanelStyleFor({
  required Size size,
  required bool isTv,
  required bool isTouch,
}) {
  if (isTv) return PlayerPanelStyle.sideSheet;
  // Upright and not very wide: a phone, or a narrow window.
  if (size.height > size.width && size.width < 900) {
    return PlayerPanelStyle.bottomSheet;
  }
  // A touch screen that is wide: a phone on its side, a tablet.
  if (isTouch) return PlayerPanelStyle.sideSheet;
  // A pointer on a wide window: the popover, as it has always been.
  return PlayerPanelStyle.popover;
}

/// What a menu inside a [PlayerMenuAnchor] needs to know about the panel it
/// is in, found with [maybeOf]. Null outside one, where a menu is just a card.
class PlayerPanelScope extends InheritedWidget {
  final PlayerPanelStyle style;

  /// The room the menu's own content has: the panel's height less its own
  /// chrome (the grabber, the close strip) and the system's insets.
  final double contentHeight;
  final double contentWidth;

  const PlayerPanelScope({
    super.key,
    required this.style,
    required this.contentHeight,
    required this.contentWidth,
    required super.child,
  });

  static PlayerPanelScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerPanelScope>();

  /// Whether the menu is in a sheet, which draws the surface itself, so the
  /// menu's own card chrome and fixed width are not wanted.
  static bool isSheet(BuildContext context) {
    final style = maybeOf(context)?.style;
    return style == PlayerPanelStyle.sideSheet ||
        style == PlayerPanelStyle.bottomSheet;
  }

  @override
  bool updateShouldNotify(PlayerPanelScope old) =>
      style != old.style ||
      contentHeight != old.contentHeight ||
      contentWidth != old.contentWidth;
}

/// Whether the platform's primary input is a finger. A TV is handled before
/// this is asked, and desktop and the web are pointers.
bool playerPanelIsTouch() =>
    PlayerPanelPolicy.touchOverride ??
    switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      _ => false,
    };

/// A seam for tests. `flutter_test` runs as Android, a touch platform, and
/// its own platform override cannot be reset before the framework checks it;
/// a test that is about the desktop popover sets this instead.
abstract final class PlayerPanelPolicy {
  @visibleForTesting
  static bool? touchOverride;
}

/// The surface a sheet draws: dark glass, with the edge it opens from.
class _SheetSurface extends StatelessWidget {
  final BorderRadiusGeometry radius;
  final Border border;
  final Widget child;

  const _SheetSurface({
    required this.radius,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: PlayerTheme.menuShadowOf(context),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Denser than the popover's glass: this sits over the whole
              // picture, and the text on it is read from a sofa.
              color: const Color(0xF40B1019),
              borderRadius: radius,
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A panel that comes in from an edge, with the scrim behind it, the close
/// affordances that suit the device, and the swipe that sends it back.
///
/// Close affordances, decided per shape (see the changelog entry):
///  - **Bottom sheet:** a grabber and a drag down. No X: the grabber says
///    "pull me", the scrim is tappable, and Back closes. An X in the corner
///    of a sheet that is already the width of the screen is a second way to
///    do what a swipe does, and it would sit in the one place a thumb has to
///    cross to reach the list.
///  - **Side sheet on a touch screen:** an X in a strip of its own at the
///    top, a swipe toward the edge it came from, a tap on the scrim. A side
///    panel has no grabber to suggest the swipe, so the X is what a person
///    finds first.
///  - **Side sheet on a TV:** nothing of the kind. Back closes it; an X would
///    be one more stop for the D-pad to cross, and a swipe has no meaning.
class PlayerSheet extends StatefulWidget {
  final PlayerPanelStyle style;
  final VoidCallback? onClose;
  final Widget child;

  const PlayerSheet({
    super.key,
    required this.style,
    required this.onClose,
    required this.child,
  }) : assert(style != PlayerPanelStyle.popover);

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet> {
  /// 1 while it is off the edge, 0 when it is in place: the fraction of its
  /// own size it is displaced by, so one number drives the slide in, the
  /// drag and the slide out.
  double _away = 1;
  bool _dragging = false;
  bool _closing = false;

  bool get _isSide => widget.style == PlayerPanelStyle.sideSheet;

  /// Which way "toward the edge it came from" points on the x axis: right in a
  /// left-to-right layout, left in a right-to-left one.
  double _toward(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
  bool get _swipeable => widget.onClose != null && !TvModeService.isTv.value;

  @override
  void initState() {
    super.initState();
    // In on the next frame, so there is a frame to slide from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _away = 0);
    });
  }

  void _dragBy(double deltaPixels, double extent) {
    if (!_swipeable || _closing || extent <= 0) return;
    setState(() {
      _dragging = true;
      _away = (_away + deltaPixels / extent).clamp(0.0, 1.0);
    });
  }

  void _dragEnd(double velocity, double extent) {
    if (!_swipeable || _closing) return;
    // Past a third of the way, or flung toward the edge.
    final dismiss = _away > 0.33 || velocity > 700;
    setState(() {
      _dragging = false;
      if (dismiss) {
        _closing = true;
        _away = 1;
      } else {
        _away = 0;
      }
    });
    if (dismiss && widget.onClose != null) {
      // Let the slide out play, then tell the owner. A frame is enough in a
      // test, where animations are pumped by hand.
      _afterSlide = widget.onClose;
    }
  }

  VoidCallback? _afterSlide;

  void _onSlideEnd() {
    final after = _afterSlide;
    if (_closing && after != null) {
      _afterSlide = null;
      after();
    }
  }

  void _requestClose() {
    final close = widget.onClose;
    if (close == null || _closing) return;
    setState(() {
      _closing = true;
      _away = 1;
      _afterSlide = close;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final pad = mq.padding;
    final isTv = TvModeService.isTv.value;
    final radius = context.rem(AppRem.xl);
    final slide = _dragging
        ? Duration.zero
        : const Duration(milliseconds: 220);

    final stripHeight = _isSide
        ? (isTv ? 0.0 : context.rem(AppRem.target))
        : context.rem(2.25);

    // The panel's own size.
    final double panelWidth;
    final double panelMaxHeight;
    if (_isSide) {
      panelWidth = (size.width * 0.42)
          .clamp(context.rem(22.5), context.rem(32))
          .clamp(0.0, size.width - context.rem(AppRem.xl));
      panelMaxHeight = size.height;
    } else {
      panelWidth = size.width;
      panelMaxHeight = size.height * 0.88;
    }

    final contentHeight = (panelMaxHeight -
            stripHeight -
            (_isSide ? pad.top + pad.bottom : pad.bottom))
        .clamp(120.0, double.infinity);
    // The inset on the edge the panel sits against.
    final endInset = Directionality.of(context) == TextDirection.rtl
        ? pad.left
        : pad.right;
    final contentWidth = panelWidth - (_isSide ? endInset : 0);

    Widget body = PlayerPanelScope(
      style: widget.style,
      contentHeight: contentHeight,
      contentWidth: contentWidth,
      child: _SheetContent(
        padding: EdgeInsetsDirectional.only(end: _isSide ? endInset : 0, bottom: pad.bottom),
        child: widget.child,
      ),
    );

    final strip = _isSide
        ? (stripHeight == 0
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: pad.top,
                      end: endInset + context.rem(AppRem.sm),
                    ),
                    child: _CloseButton(onPressed: _requestClose),
                  ),
                ))
        : _Grabber(
            height: stripHeight,
            onDrag: (d) => _dragBy(d, panelMaxHeight),
            onEnd: (v) => _dragEnd(v, panelMaxHeight),
            onTap: widget.onClose == null ? null : _requestClose,
          );

    final surface = _SheetSurface(
      radius: _isSide
          ? BorderRadiusDirectional.horizontal(start: Radius.circular(radius))
          : BorderRadius.vertical(top: Radius.circular(radius)),
      border: Border.all(color: PlayerTheme.edge, width: 1), // px: a hairline, not a layout size
      child: Column(
        mainAxisSize: _isSide ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (strip != null)
            _isSide
                ? SizedBox(height: stripHeight + pad.top, child: strip)
                : strip,
          if (_isSide && stripHeight == 0) SizedBox(height: pad.top),
          Flexible(fit: _isSide ? FlexFit.tight : FlexFit.loose, child: body),
        ],
      ),
    );

    final sized = _isSide
        ? SizedBox(width: panelWidth, height: panelMaxHeight, child: surface)
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: panelMaxHeight),
            child: surface,
          );

    final Widget panel = _swipeable && _isSide
        ? GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (d) =>
                _dragBy(d.delta.dx * _toward(context), panelWidth),
            onHorizontalDragEnd: (d) => _dragEnd(
              d.velocity.pixelsPerSecond.dx * _toward(context),
              panelWidth,
            ),
            child: sized,
          )
        : sized;

    return Positioned.fill(
      child: Stack(
        children: [
          // The scrim: tapping it closes, and it lightens as the panel goes.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose == null ? null : _requestClose,
              child: AnimatedContainer(
                duration: slide,
                color: Colors.black.withValues(alpha: 0.45 * (1 - _away)),
              ),
            ),
          ),
          Align(
            alignment: _isSide
                ? AlignmentDirectional.centerEnd
                : Alignment.bottomCenter,
            child: AnimatedSlide(
              duration: slide,
              curve: Curves.easeOutCubic,
              offset: _isSide
                  ? Offset(_away * _toward(context), 0)
                  : Offset(0, _away),
              onEnd: _onSlideEnd,
              child: panel,
            ),
          ),
        ],
      ),
    );
  }
}

/// The menu's own area inside a sheet: scrolls when the menu is taller than
/// the room, and keeps clear of the system's insets.
class _SheetContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SheetContent({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    // The focus scope goes round the menu's own area and not the strip above
    // it: a remote or keyboard opening a menu lands on its first control, not
    // on the close button that comes first in reading order.
    return PlayerFocusOnOpen(
      child: Padding(
        padding: padding,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
}

/// The grabber at the top of a bottom sheet, and the strip of drag area
/// around it. The drag lives here and not on the whole sheet so the list
/// below scrolls without fighting it.
class _Grabber extends StatelessWidget {
  final double height;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onEnd;
  final VoidCallback? onTap;

  const _Grabber({
    required this.height,
    required this.onDrag,
    required this.onEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      onVerticalDragEnd: (d) => onEnd(d.velocity.pixelsPerSecond.dy),
      child: SizedBox(
        height: height,
        child: Center(
          child: Container(
            width: context.rem(2.5),
            height: context.rem(AppRem.xs),
            decoration: BoxDecoration(
              color: PlayerTheme.inkDisabled,
              borderRadius: BorderRadius.circular(context.rem(AppRem.xxs)),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return PlayerIconButton(
      size: context.rem(2.25),
      iconSize: context.rem(1.25),
      icon: const Icon(Icons.close_rounded),
      tooltip: context.l10n.commonClose,
      onPressed: onPressed,
    );
  }
}
