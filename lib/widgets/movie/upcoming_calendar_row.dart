import 'package:flutter/material.dart';

import '../../models/movie/movie.dart';
import '../../models/trakt/trakt_calendar_entry.dart';
import '../../pages/details/details_page.dart';
import '../../services/simkl/simkl_calendar_service.dart';
import '../../services/simkl/simkl_service.dart';
import '../../services/trakt/trakt_calendar_service.dart';
import '../../services/trakt/trakt_service.dart';
import '../../utils/navigation/route_transitions.dart';

/// Upcoming episodes for the user's synced shows, next 14 days. Series-only:
/// Trakt/Simkl calendars are episode-shaped, movies have no equivalent
/// endpoint ported in this fork (see the design spec for why).
///
/// Renders nothing when neither Trakt nor Simkl is authenticated, or the
/// range has no entries — this is a bonus row for connected accounts, not
/// a feature every user needs to see an empty state for.
class UpcomingCalendarRow extends StatefulWidget {
  /// Injectable for tests (`TraktCalendarService.forTesting(...)`).
  /// Defaults to the real singleton.
  final TraktCalendarService? traktCalendar;

  /// Injectable for tests to bypass `TraktService.instance.isAuthenticated()`.
  /// Defaults to the real singleton method.
  final Future<bool> Function()? isTraktAuthenticated;

  const UpcomingCalendarRow({
    super.key,
    this.traktCalendar,
    this.isTraktAuthenticated,
  });

  @override
  State<UpcomingCalendarRow> createState() => _UpcomingCalendarRowState();
}

class _UpcomingCalendarRowState extends State<UpcomingCalendarRow> {
  List<TraktCalendarEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trakt = widget.traktCalendar ?? TraktCalendarService.instance;
    final isAuthed =
        widget.isTraktAuthenticated ?? TraktService.instance.isAuthenticated;
    final now = DateTime.now();
    final end = now.add(const Duration(days: 14));

    Map<DateTime, List<TraktCalendarEntry>> grouped = {};
    if (await isAuthed()) {
      grouped = await trakt.getRange(now, end);
    } else if (await SimklService.instance.isAuthenticated()) {
      grouped = await SimklCalendarService.instance.getRange(now, end);
    }

    if (!mounted) return;
    final flat = grouped.values.expand((e) => e).toList()
      ..sort((a, b) => a.firstAiredLocal.compareTo(b.firstAiredLocal));
    setState(() => _entries = flat);
  }

  void _openDetails(TraktCalendarEntry entry) {
    final imdbId = entry.showImdbId;
    if (imdbId == null || imdbId.isEmpty) return;
    Navigator.push(
      context,
      LiquidRevealRoute(
        page: DetailsPage(
          movie: Movie(
            id: imdbId,
            name: entry.showTitle,
            type: 'series',
            addonBaseUrl: '',
          ),
        ),
        tapPosition: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Calendar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return GestureDetector(
                  onTap: () => _openDetails(entry),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151F).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.showTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'S${entry.seasonNumber.toString().padLeft(2, '0')}'
                          'E${entry.episodeNumber.toString().padLeft(2, '0')}'
                          ' • ${entry.episodeTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.firstAiredLocal.month}/${entry.firstAiredLocal.day}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
