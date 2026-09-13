import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/details_section_header.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('DetailsSectionHeader', () {
    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(wrap(const DetailsSectionHeader('Cast & Crew')));
      expect(find.text('Cast & Crew'), findsOneWidget);
    });

    testWidgets('a trailing widget sits opposite the title', (tester) async {
      await tester.pumpWidget(wrap(
        const DetailsSectionHeader('Episodes', trailing: Text('(24 total)')),
      ));

      expect(
        tester.getCenter(find.text('Episodes')).dx,
        lessThan(tester.getCenter(find.text('(24 total)')).dx),
      );
    });

    testWidgets('a long title with a trailing widget does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(
        const DetailsSectionHeader(
          'A Very Long Section Heading Indeed',
          trailing: Text('(1000 total)'),
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('right-to-left titles render', (tester) async {
      // Arabic anime's headings are RTL; they go through this widget too.
      await tester.pumpWidget(wrap(
        const DetailsSectionHeader('أنميات ذات صلة'),
      ));
      expect(find.text('أنميات ذات صلة'), findsOneWidget);
    });
  });

  test('no details page hand-rolls its own section heading', () {
    // The three details pages had drifted: Movies/Series used bold at -0.3
    // with 16px beneath, Anime used w800 at -0.4 with none, and Arabic anime
    // prefixed an accent icon. Each was defensible alone; together the same
    // page type read as three. This catches the fourth.
    //
    // The signal is a 20px heading at w800/bold inside lib/pages -- the size
    // these headings are, and large enough that body text does not collide
    // with the rule.
    final heading = RegExp(
      r'fontSize:\s*20\b[\s\S]{0,80}?fontWeight:\s*FontWeight\.(w800|bold)'
      r'|fontWeight:\s*FontWeight\.(w800|bold)[\s\S]{0,80}?fontSize:\s*20\b',
    );

    final offenders = <String>[];
    for (final file in Directory('lib/pages')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Only the details family shares this heading. Browse pages use
      // SectionHeader, and the player's menus have their own smaller
      // all-caps labels.
      if (!file.path.contains('details_page.dart')) continue;
      final source = file.readAsStringSync();
      if (heading.hasMatch(source)) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'use DetailsSectionHeader so the three details pages keep one '
          'heading instead of drifting apart again',
    );
  });
}
