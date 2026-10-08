import 'package:flutter/material.dart';

import '../../services/app_units.dart';
import '../common/title_or_logo.dart';

/// What is being loaded, above the filling logo: the title's own logo where
/// there is one, its name where there is not, and under it the episode.
///
/// Stremio's loading screen leads with the title's art, so a viewer who opened
/// the wrong thing sees it before the stream finishes loading, and a slow
/// torrent is waiting on something. [PlayerScreen] had been handed the logo
/// for exactly this and never drew it.
///
/// A logo that fails to load falls back to the name, as the details page does.
/// Anime has no logo to offer (AniList carries none), so it shows the name.
class PlayerLoadingTitle extends StatelessWidget {
  /// The title's transparent logo image, when its metadata has one.
  final String? logoUrl;

  /// The name shown when there is no logo, or it cannot be loaded.
  final String title;

  /// "S1 · E3 · Episode name" for an episode; null for a movie.
  final String? subtitle;

  const PlayerLoadingTitle({
    super.key,
    this.logoUrl,
    required this.title,
    this.subtitle,
  });

  /// "S1 · E3", with the episode's own name after it when it has one.
  static String? episodeLabel({int? season, int? episode, String? name}) {
    final parts = <String>[
      if (season != null) 'S$season',
      if (episode != null) 'E$episode',
    ];
    final cleaned = name?.trim() ?? '';
    // A name that only repeats the numbers ("Episode 3") says nothing the
    // numbers have not.
    final repeats = RegExp(r'^(episode|ep\.?)\s*\d+$', caseSensitive: false)
        .hasMatch(cleaned);
    if (cleaned.isNotEmpty && !repeats) parts.add(cleaned);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    // A phone held sideways has little height to share with the filling logo
    // and the status line below.
    final compact = MediaQuery.sizeOf(context).height < 500;
    final maxHeight = context.rem(compact ? 3.5 : 5.5);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.rem(22)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TitleOrLogo(
            logoUrl: logoUrl,
            name: title,
            maxLogoWidth: context.rem(22),
            maxLogoHeight: maxHeight,
            fontSize: compact ? AppType.titleSm : AppType.displaySm,
            letterSpacing: 0,
            color: Colors.white,
            shadowBlur: context.rem(AppRem.blurLg),
            shadowOffsetY: 0,
            logoAlignment: Alignment.center,
            textAlign: TextAlign.center,
            maxLines: 2,
            // Nothing while it loads: the name appearing and then being
            // replaced by the logo would flash on every launch.
            placeholder: SizedBox(height: maxHeight),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            SizedBox(height: context.rem(AppRem.xs)),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: AppType.bodyMd,
                letterSpacing: 0.4, // px: tracking, not a layout size
              ),
            ),
          ],
        ],
      ),
    );
  }
}
