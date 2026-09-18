import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/services/scraper/stream_scraper.dart';

/// A scraper that accepts the request and then never answers -- the shape of
/// a host that completes a TCP handshake and goes quiet. Most built-in
/// scrapers issue HTTP requests with no timeout, so this is reachable in
/// production, and before the per-scraper deadline it held the whole search
/// open forever.
class _NeverAnswersScraper extends StreamScraper {
  @override
  String get name => 'Never';

  @override
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) => StreamController<StreamSource>().stream;
}

class _AnswersOnceScraper extends StreamScraper {
  @override
  String get name => 'Quick';

  @override
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async* {
    yield StreamSource(
      name: 'Quick',
      addonName: 'Quick',
      title: 'A source',
      // No url and no infoHash, so it bypasses the network health check and
      // is emitted directly -- this test is about closing, not about
      // liveness probing.
    );
  }
}

void main() {
  group('ScraperManager.scrapeAll', () {
    setUp(() {
      // The manager is a singleton; start each test from a known roster.
      ScraperManager.instance.resetForTest();
    });

    test('a scraper that never answers does not hold the search open', () {
      fakeAsync((async) {
        ScraperManager.instance.registerScraper(_AnswersOnceScraper());
        ScraperManager.instance.registerScraper(_NeverAnswersScraper());

        var closed = false;
        final seen = <StreamSource>[];
        ScraperManager.instance
            .scrapeAll(type: 'movie', title: 'Anything')
            .listen(seen.add, onDone: () => closed = true);

        async.elapse(const Duration(seconds: 5));
        expect(seen, hasLength(1), reason: 'the quick scraper answered');
        expect(closed, isFalse, reason: 'still waiting on the silent one');

        async.elapse(const Duration(seconds: 30));
        expect(
          closed,
          isTrue,
          reason: 'the deadline should have dropped the silent scraper',
        );
      });
    });

    test('results from scrapers that did answer are kept', () {
      fakeAsync((async) {
        ScraperManager.instance.registerScraper(_AnswersOnceScraper());
        ScraperManager.instance.registerScraper(_NeverAnswersScraper());

        final seen = <StreamSource>[];
        ScraperManager.instance
            .scrapeAll(type: 'movie', title: 'Anything')
            .listen(seen.add);

        async.elapse(const Duration(seconds: 35));
        expect(seen.single.title, 'A source');
      });
    });

    test('with every scraper answering it closes without waiting', () {
      fakeAsync((async) {
        ScraperManager.instance.registerScraper(_AnswersOnceScraper());

        var closed = false;
        ScraperManager.instance
            .scrapeAll(type: 'movie', title: 'Anything')
            .listen((_) {}, onDone: () => closed = true);

        async.elapse(const Duration(seconds: 1));
        expect(closed, isTrue, reason: 'no deadline should be waited out');
      });
    });

    test('no scrapers at all closes immediately', () {
      fakeAsync((async) {
        var closed = false;
        ScraperManager.instance
            .scrapeAll(type: 'movie', title: 'Anything')
            .listen((_) {}, onDone: () => closed = true);

        async.flushMicrotasks();
        expect(closed, isTrue);
      });
    });

    test('canceling stops the scrapers still running', () {
      fakeAsync((async) {
        ScraperManager.instance.registerScraper(_NeverAnswersScraper());

        final sub = ScraperManager.instance
            .scrapeAll(type: 'movie', title: 'Anything')
            .listen((_) {});

        sub.cancel();
        async.elapse(const Duration(seconds: 35));

        // The pending deadline timer must have been canceled with it; a
        // live timer here would be a leak per abandoned search.
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
