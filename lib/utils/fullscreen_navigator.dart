import 'package:flutter/material.dart';

import '../../main.dart';
import 'navigation/route_transitions.dart';

/// Pushes a route onto the **root** navigator so it renders fullscreen,
/// escaping the hub's nested navigator. Use this for fullscreen playback
/// (video player, audiobook player, manga reader, etc.).
Future<T?> pushFullscreen<T>(Route<T> route) {
  return navigatorKey.currentState!.push<T>(route);
}

/// Replaces the current route on the **root** navigator (fullscreen).
Future<T?> pushFullscreenReplacement<T>(Route<T> route) {
  return navigatorKey.currentState!.pushReplacement<T, dynamic>(route);
}

/// Pushes [page] fullscreen with the app's standard page transition.
///
/// The hub wraps its content area in its own `Navigator` so a pushed
/// details page renders inside the content box, with the section top bar
/// and sidebar still around it. That is right for a details page and
/// wrong for playback -- resuming from Continue Watching is meant to go
/// straight to video, and a plain `Navigator.push` left the hub's top bar
/// drawn around the player. This is the same escape hatch as
/// [pushFullscreen], minus each caller restating the route class.
Future<T?> pushFullscreenPage<T>(Widget page) {
  return pushFullscreen<T>(CinematicSlideRoute<T>(page: page));
}
