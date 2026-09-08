// test/widgets/page_gutter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/app_spacing.dart';
import 'package:playtorriomov/widgets/movie/movie_card.dart';

void main() {
  group('AppSpacing.pageInset', () {
    test('is mobile first -- the phone value is the base, wider tiers step up', () {
      final mobile = AppSpacing.pageInsetForWidth(390);
      final tablet = AppSpacing.pageInsetForWidth(760);
      final desktop = AppSpacing.pageInsetForWidth(1440);

      expect(mobile, lessThan(tablet));
      expect(tablet, lessThan(desktop));
    });

    testWidgets('the context and width forms agree', (tester) async {
      tester.view.physicalSize = const Size(760, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(AppSpacing.pageInset(ctx), AppSpacing.pageInsetForWidth(760));
    });
  });

  group('a page has one left edge', () {
    test('card rows use the page gutter, not their own number', () {
      // A row's first card, the section title above it, and the filter bar
      // above that used to sit at 18, 20 and 16/24 respectively -- three
      // different left edges stacked down one page.
      for (final width in [390.0, 760.0, 1440.0]) {
        expect(
          MovieCardSizing.fromWidth(width).sidePadding,
          AppSpacing.pageInsetForWidth(width),
          reason: 'card row gutter must match the page gutter at $width',
        );
      }
    });
  });
}
