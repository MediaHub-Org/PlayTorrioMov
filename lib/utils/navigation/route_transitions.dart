import 'package:flutter/material.dart';

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
class CinematicSlideRoute extends PageRouteBuilder {
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

/// Pushes [page] onto the nearest navigator with the app's one page
/// transition.
///
/// Every forward navigation goes through here, so a page arrives the same
/// way no matter what opened it. It used to depend on the call site: a
/// poster tap, a "see all", a settings row and a search button each picked
/// their own route class, so the same Details page slid in from one place
/// and circle-revealed from another.
///
/// Uses the nearest navigator on purpose -- inside a hub that is the hub's
/// own `NestedNavigator`, which is what keeps a details page inside the
/// content area. Fullscreen playback deliberately escapes that; see
/// `pushFullscreenPage` in utils/fullscreen_navigator.dart.
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(CinematicSlideRoute(page: page));
}

/// Replaces the current route with [page], same transition as [pushPage].
///
/// For navigation that should not stack: Details -> a different Details
/// (a related title, a resolved redirect), where backing out of the second
/// should return to where the first was opened from, not to the first.
Future<T?> pushReplacementPage<T>(BuildContext context, Widget page) {
  return Navigator.of(
    context,
  ).pushReplacement<T, dynamic>(CinematicSlideRoute(page: page));
}
