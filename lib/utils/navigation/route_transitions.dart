import 'package:flutter/material.dart';

import '../../main.dart';

/// The app's one page transition.
///
/// The outgoing page's content slides to the left and fades out, while the
/// incoming page's content slides in from the right and fades in. Both
/// pages share the same dark background and backdrop image, creating the
/// illusion of persistent scenery with only the overlaid UI elements
/// moving.
///
/// Prefer [pushPage] / [pushReplacementPage] over naming this directly --
/// they are what keeps every navigation on the same transition.
class CinematicSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  CinematicSlideRoute({
    required this.page,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          opaque: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Incoming page: slide from right + fade in
            final inCurve = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.25, 0.1, 0.25, 1.0),
              reverseCurve: Curves.easeInCubic,
            );

            final slideIn = Tween<Offset>(
              begin: const Offset(0.15, 0),
              end: Offset.zero,
            ).animate(inCurve);

            final fadeIn = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ));

            return SlideTransition(
              position: slideIn,
              child: FadeTransition(
                opacity: fadeIn,
                child: child,
              ),
            );
          },
        );
}

/// Pushes [page] onto the **root** navigator with the app's one page
/// transition, so it renders fullscreen -- covering the hub's top bar and
/// section chips, not just the content box below them.
///
/// Every forward navigation with a back button goes through here, so a page
/// arrives the same way no matter what opened it. It used to depend on the
/// call site: a poster tap, a "see all", a settings row and a search button
/// each picked their own route class, so the same Details page slid in from
/// one place and circle-revealed from another.
///
/// Used to push onto the *nearest* navigator instead -- inside a hub that is
/// the hub's own `NestedNavigator`, which kept a details page inside the
/// content area, with the top bar and section chips still drawn around it.
/// That left every "back button" page showing two back affordances at once
/// (the page's own, and implicitly the hub chrome still visible above it),
/// so every one of them now escapes to the root navigator instead -- the
/// same escape hatch fullscreen playback already used; see
/// `pushFullscreenPage` in utils/fullscreen_navigator.dart. [context] is
/// kept in the signature only so call sites don't need to change.
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return navigatorKey.currentState!.push<T>(CinematicSlideRoute<T>(page: page));
}

/// Replaces the current route with [page], same transition as [pushPage].
///
/// For navigation that should not stack: Details -> a different Details
/// (a related title, a resolved redirect), where backing out of the second
/// should return to where the first was opened from, not to the first.
Future<T?> pushReplacementPage<T>(BuildContext context, Widget page) {
  return navigatorKey.currentState!
      .pushReplacement<T, dynamic>(CinematicSlideRoute<T>(page: page));
}
