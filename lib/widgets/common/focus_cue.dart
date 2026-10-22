import 'package:flutter/widgets.dart';

/// Whether a control that holds focus should draw its focus cue now: the zoom,
/// the ring or the wash.
///
/// Focus alone is not the signal. FirstFocusScope and `autofocus` hand focus
/// to the first control of every section on open, and a mouse viewer never
/// asked for it. Flutter's highlight mode is the gate: touch until a key has
/// been pressed, traditional after (see TvModeService.installFocusPolicy).
/// Hover is not gated here; each control draws it from its own flag, as before.
bool isFocusCueShown(bool hasFocus) =>
    hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

/// Rebuilds a State when the highlight mode changes.
///
/// Without it, a control that already holds focus when the first key arrives
/// would draw its cue only on its next focus change: a D-pad press at the edge
/// of a row moves nothing, and the card under the remote would stay bare.
/// Mix in on a State whose build reads [isFocusCueShown].
mixin FocusCueState<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }
}
