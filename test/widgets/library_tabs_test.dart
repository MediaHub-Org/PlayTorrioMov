import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/library_tabs.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('LibraryTabs', () {
    testWidgets('tapping a pill switches the TabBarView page', (tester) async {
      await tester.pumpWidget(
        wrap(
          LibraryTabs(
            title: 'Library',
            titleIcon: Icons.video_library_rounded,
            tabs: [
              LibraryTab(
                label: 'Saved',
                icon: Icons.bookmark_rounded,
                builder: (_) => const Text('Saved page'),
              ),
              LibraryTab(
                label: 'In Progress',
                icon: Icons.play_circle_outline_rounded,
                builder: (_) => const Text('In Progress page'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved page'), findsOneWidget);

      await tester.tap(find.text('In Progress'));
      await tester.pumpAndSettle();

      expect(find.text('In Progress page'), findsOneWidget);
      expect(find.text('Saved page'), findsNothing);
    });

    testWidgets('swiping the page updates which pill is highlighted', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          LibraryTabs(
            title: 'Library',
            titleIcon: Icons.video_library_rounded,
            tabs: [
              LibraryTab(
                label: 'Saved',
                icon: Icons.bookmark_rounded,
                builder: (_) => const Text('Saved page'),
              ),
              LibraryTab(
                label: 'In Progress',
                icon: Icons.play_circle_outline_rounded,
                builder: (_) => const Text('In Progress page'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(find.text('Saved page'), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('In Progress page'), findsOneWidget);
    });
  });
}
