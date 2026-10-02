import 'package:flutter/material.dart';

import '../../services/app_units.dart';

/// The app logo filling from the bottom as a stream loads, like Stremio. The
/// fill gives a sense of progress without claiming a precise percentage.
///
/// [progress] is 0..1 (see `PlayerLoadProgress`). The fill animates between
/// updates because the real numbers arrive in jumps, a second apart.
class PlayerLoadingLogo extends StatelessWidget {
  final double progress;

  const PlayerLoadingLogo({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final size = context.rem(6.5);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, filled, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The unfilled logo: the same picture, dimmed, so the
                    // fill reads as the logo "lighting up" rather than a
                    // bar growing behind a stencil.
                    Opacity(
                      opacity: 0.22,
                      child: Image.asset(
                        'assets/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: filled,
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: Image.asset(
                            'assets/icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
