/// What a Back press should do in a player.
enum BackAction {
  /// A menu or side panel is open: close it, and only it.
  closeOverlay,

  /// The top and bottom bars are showing: put them away.
  hideControls,

  /// Nothing is open and the bars are away: the first of two presses, which
  /// asks for a second to leave.
  armExit,

  /// Leave the player.
  exit,
}

/// Decides what Back means in a player, from the outside in.
///
/// Back used to leave the player outright, whatever was on screen, so on a TV
/// a remote's Back with the subtitle panel open threw away the video instead
/// of the panel -- and one stray press anywhere lost the place in a film
/// (#80). Now each press peels one layer: a panel, then the bars, then a
/// second press to leave.
///
/// Off a TV only the first layer applies. A phone's Back or a desktop's Esc
/// that closes an open panel before leaving is what everyone expects, but a
/// confirm-to-exit on a pointer device would only be in the way.
///
/// [isLoading] leaves at once: there is no playback to protect, and the
/// person pressing Back on a spinner or a failed source wants out.
BackAction decideBackPress({
  required bool hasOverlayOpen,
  required bool controlsVisible,
  required bool exitArmed,
  required bool isTv,
  bool isLoading = false,
}) {
  if (hasOverlayOpen) return BackAction.closeOverlay;
  if (!isTv || isLoading) return BackAction.exit;
  if (controlsVisible) return BackAction.hideControls;
  return exitArmed ? BackAction.exit : BackAction.armExit;
}
