// test/widgets/player_top_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_top_bar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PlayerTopBar download button', () {
    testWidgets('sits next to Copy Stream URL and fires its callback',
        (tester) async {
      var downloads = 0;
      await tester.pumpWidget(wrap(PlayerTopBar(
        title: 'A Film',
        onBack: () {},
        onCopyStreamUrl: () {},
        onDownload: () => downloads++,
      )));

      final copy = tester.getCenter(find.byIcon(Icons.link_rounded));
      final download = tester.getCenter(find.byIcon(Icons.download_rounded));
      expect((download.dx - copy.dx).abs(), lessThan(60),
          reason: 'one button apart at most, not on the far side of the bar');
      expect(download.dy, copy.dy);

      await tester.tap(find.byIcon(Icons.download_rounded));
      expect(downloads, 1);
    });

    testWidgets('fits on a phone with every button showing', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(PlayerTopBar(
        title: 'A Film With A Rather Long Title',
        subtitle: 'S1:E2 • An Episode Title',
        onBack: () {},
        onToggleEpisodes: () {},
        onCopyStreamUrl: () {},
        onDownload: () {},
        onCast: () {},
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('is absent when there is nothing to download', (tester) async {
      await tester.pumpWidget(wrap(PlayerTopBar(
        title: 'A Film',
        onBack: () {},
        onCopyStreamUrl: () {},
      )));

      expect(find.byIcon(Icons.download_rounded), findsNothing);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    });
  });
}
