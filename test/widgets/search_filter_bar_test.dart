// test/widgets/search_filter_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/utils/search_scope.dart';
import 'package:playtorriomov/widgets/common/hover_button.dart';
import 'package:playtorriomov/widgets/search/search_filter_bar.dart';

Future<void> pumpBar(
  WidgetTester tester, {
  required double width,
  double textScale = 1.0,
  SearchFilter type = SearchFilter.all,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SearchFilterBar(
            type: type,
            onTypeChanged: (_) {},
            decade: null,
            onDecadeChanged: (_) {},
            minRating: null,
            onMinRatingChanged: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final width in [320.0, 360.0, 390.0, 600.0, 768.0, 1280.0, 1920.0]) {
    testWidgets('fits at ${width.toInt()} px without overflowing', (
      tester,
    ) async {
      await pumpBar(tester, width: width);
      expect(tester.takeException(), isNull);
      // One line: every chip sits in the same band.
      final tops = {
        for (final e in find.byType(HoverButton).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      };
      expect(tops.length, 1, reason: 'one row');
    });
  }

  testWidgets('a wide window shows the words', (tester) async {
    await pumpBar(tester, width: 1280);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('All decades'), findsOneWidget);
    expect(find.byIcon(Icons.tv_rounded), findsNothing);
  });

  testWidgets('a narrow phone drops to icons for every control', (tester) async {
    await pumpBar(tester, width: 320);
    expect(find.text('Series'), findsNothing);
    expect(find.text('All decades'), findsNothing);
    for (final f in SearchFilter.values) {
      expect(find.byIcon(searchFilterIcon(f)), findsOneWidget, reason: '$f');
    }
    // And the names are still reachable: as semantics on each chip.
    expect(find.bySemanticsLabel('Series'), findsWidgets);
  });

  testWidgets('a large text size does not overflow, at any width', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 768.0]) {
      await pumpBar(tester, width: width, textScale: 2.0);
      expect(tester.takeException(), isNull, reason: '$width px at 2x');
    }
  });

  testWidgets('the same three controls on every type', (tester) async {
    for (final type in SearchFilter.values) {
      await pumpBar(tester, width: 1280, type: type);
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    }
  });
}
