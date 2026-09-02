import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/trakt/trakt_calendar_entry.dart';
import 'package:playtorriomov/services/trakt/trakt_calendar_service.dart';
import 'package:playtorriomov/widgets/movie/upcoming_calendar_row.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('UpcomingCalendarRow', () {
    testWidgets('renders nothing when the fetcher returns no entries', (
      tester,
    ) async {
      final service = TraktCalendarService.forTesting(
        fetcher: (start, days) async => [],
      );

      await tester.pumpWidget(
        wrap(
          UpcomingCalendarRow(
            traktCalendar: service,
            isTraktAuthenticated: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsNothing);
    });

    testWidgets('renders entries the fetcher returns, sorted by air date', (
      tester,
    ) async {
      final now = DateTime.now();
      final service = TraktCalendarService.forTesting(
        fetcher: (start, days) async => [
          TraktCalendarEntry(
            firstAired: now.add(const Duration(days: 3)).toIso8601String(),
            firstAiredLocal: now.add(const Duration(days: 3)),
            showTraktId: 1,
            showTitle: 'Later Show',
            seasonNumber: 1,
            episodeNumber: 2,
            episodeTitle: 'Ep Two',
            imdbId: 'tt0000001',
          ),
          TraktCalendarEntry(
            firstAired: now.add(const Duration(days: 1)).toIso8601String(),
            firstAiredLocal: now.add(const Duration(days: 1)),
            showTraktId: 2,
            showTitle: 'Sooner Show',
            seasonNumber: 2,
            episodeNumber: 1,
            episodeTitle: 'Ep One',
            imdbId: 'tt0000002',
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(
          UpcomingCalendarRow(
            traktCalendar: service,
            isTraktAuthenticated: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Sooner Show'), findsOneWidget);
      expect(find.text('Later Show'), findsOneWidget);

      // Sooner Show airs first, so its card comes first in the list.
      final soonerLeft = tester.getTopLeft(find.text('Sooner Show')).dx;
      final laterLeft = tester.getTopLeft(find.text('Later Show')).dx;
      expect(soonerLeft, lessThan(laterLeft));
    });
  });
}
