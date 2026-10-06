// test/widgets/anime_episode_rail_art_test.dart
//
// The episode rail's cards show AniList's per-episode art/title where it has
// one, and fall back to the plain numbered card where it does not.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/pages/anime/anime_details_page.dart';

const testAnime = AnimeMedia(
  id: 1,
  titleEnglish: 'Test Show',
  totalEpisodes: 2,
  format: 'TV',
  status: 'FINISHED',
  streamingEpisodes: [
    AnimeStreamingEpisode(
      number: 1,
      title: 'The Beginning',
      thumbnail: 'https://example.com/ep1.jpg',
    ),
    // Episode 2 deliberately has no entry -- exercises the fallback. One
    // matched episode out of two is exactly the coverage bar
    // `episodeInfo` requires before it trusts an offset at all (see
    // `anime_streaming_episode_test.dart`), which is what this is really
    // testing: not just a match, but one the coverage check allows through.
    AnimeStreamingEpisode(title: 'A Bonus Short With No Number'),
  ],
);

void main() {
  testWidgets(
      'an episode with AniList art shows its title; one without stays plain',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AnimeDetailsPage(anime: testAnime)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('The Beginning'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsOneWidget);

    // Episode 2 has nothing to match: plain numbered card, no stray title
    // line, and only the one thumbnail above belongs to episode 1.
    expect(find.text('EP 2'), findsOneWidget);
    expect(find.text('A Bonus Short With No Number'), findsNothing);
  });
}
