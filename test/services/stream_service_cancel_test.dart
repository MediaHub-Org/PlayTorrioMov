// test/services/stream_service_cancel_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/services/scraper/stream_scraper.dart';
import 'package:playtorriomov/services/stream/stream_service.dart';

/// A scraper that reports whether it was torn down.
///
/// `ScraperManager.scrapeAll` has always canceled its scrapers when its own
/// consumer stops listening -- `controller.onCancel` cancels every
/// subscription and deadline. What was missing was the link above it:
/// `StreamService.fetchStreams` wrapped that stream in a second controller
/// with no `onCancel` of its own, so canceling *its* consumer never reached
/// the manager, and forty-odd scrapers kept issuing HTTP requests into a
/// controller nobody was reading.
///
/// This scraper is how that link is checked. It never completes on its own,
/// so the only way `canceled` becomes true is if the teardown actually
/// traveled the whole way down.
class _CancellableScraper extends StreamScraper {
  final _controller = StreamController<StreamSource>();

  /// True once the manager canceled this scraper's subscription.
  bool canceled = false;

  @override
  String get name => 'Cancellable';

  @override
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) {
    _controller.onCancel = () => canceled = true;
    return _controller.stream;
  }
}

void main() {
  group('StreamService.fetchStreams teardown', () {
    late _CancellableScraper scraper;

    setUp(() {
      // The manager is a singleton; start each test from a known roster.
      ScraperManager.instance.resetForTest();
      scraper = _CancellableScraper();
      ScraperManager.instance.registerScraper(scraper);
    });

    test('canceling the consumer stops the scrapers underneath it', () async {
      final sub = StreamService.fetchStreams(
        type: 'movie',
        id: 'tt0111161',
        title: 'Anything',
      ).listen((_) {});

      // Let the subscription reach the manager before tearing it down.
      await Future<void>.delayed(Duration.zero);
      expect(
        scraper.canceled,
        isFalse,
        reason: 'nothing should have canceled it yet',
      );

      await sub.cancel();

      expect(
        scraper.canceled,
        isTrue,
        reason: 'leaving the watch screen mid-search has to stop the '
            'scrapers, not just stop reading them -- otherwise every one of '
            'them finishes its HTTP request into a dead controller',
      );
    });
  });
}
