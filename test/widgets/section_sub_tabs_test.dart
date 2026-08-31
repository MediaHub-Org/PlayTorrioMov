// test/widgets/section_sub_tabs_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/widgets/common/section_sub_tabs.dart';

void setSurfaceWidth(WidgetTester tester, double width, {double textScale = 1}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget wrap(Widget child, {double textScale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('SectionSubTabs', () {
    testWidgets('a three-way split does not overflow a narrow phone',
        (tester) async {
      // The Read hub's Saved tab splits Audiobooks / Books / Manga, which is
      // wider than the two-way splits this widget was written for. An
      // overflow here paints a yellow-and-black stripe over the control.
      setSurfaceWidth(tester, 320);
      await tester.pumpWidget(wrap(
        SectionSubTabs(
          activeId: 'audiobooks',
          onSelected: (_) {},
          tabs: const [
            SubTab(
              id: 'audiobooks',
              label: 'Audiobooks',
              icon: Icons.headphones_rounded,
            ),
            SubTab(
              id: 'books',
              label: 'Books',
              icon: Icons.import_contacts_rounded,
            ),
            SubTab(
              id: 'manga',
              label: 'Manga',
              icon: Icons.auto_stories_rounded,
            ),
          ],
          child: const SizedBox(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Audiobooks'), findsOneWidget);
    });

    testWidgets('survives a large text scale too', (tester) async {
      setSurfaceWidth(tester, 320);
      await tester.pumpWidget(wrap(
        SectionSubTabs(
          activeId: 'songs',
          onSelected: (_) {},
          tabs: const [
            SubTab(id: 'songs', label: 'Songs', icon: Icons.favorite_rounded),
            SubTab(
              id: 'podcasts',
              label: 'Podcasts',
              icon: Icons.podcasts_rounded,
            ),
            SubTab(
              id: 'playlists',
              label: 'Playlists',
              icon: Icons.queue_music_rounded,
            ),
          ],
          child: const SizedBox(),
        ),
        textScale: 1.6,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a tab reports its id', (tester) async {
      setSurfaceWidth(tester, 800);
      String? picked;
      await tester.pumpWidget(wrap(
        SectionSubTabs(
          activeId: 'songs',
          onSelected: (id) => picked = id,
          tabs: const [
            SubTab(id: 'songs', label: 'Songs', icon: Icons.favorite_rounded),
            SubTab(
              id: 'playlists',
              label: 'Playlists',
              icon: Icons.queue_music_rounded,
            ),
          ],
          child: const SizedBox(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlists'));
      expect(picked, 'playlists');
    });
  });
}
