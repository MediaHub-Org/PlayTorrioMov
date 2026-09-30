import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/movie/movie.dart';
import '../../models/trakt/trakt_calendar_entry.dart';
import '../../pages/details/details_page.dart';
import '../../services/simkl/simkl_calendar_service.dart';
import '../../services/simkl/simkl_service.dart';
import '../../services/trakt/trakt_calendar_service.dart';
import '../../services/trakt/trakt_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../services/theme/app_colors.dart';
import '../common/clamped_text_scale.dart';
import '../common/hover_button.dart';
import '../../services/app_units.dart';

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
    pushPage(
      context,
      DetailsPage(
        movie: Movie(
          id: imdbId,
          name: entry.showTitle,
          type: 'series',
          addonBaseUrl: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final entries = _entries;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: context.rem(1.75)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rem(1.125)),
            child: Text(
              context.l10n.homeCalendar,
              style: TextStyle(
                fontSize: AppType.lead,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(height: context.rem(AppRem.ms)),
          SizedBox(
            // 92 plus headroom: three text lines (title, episode, date) in a
            // 12px-padded card were already tight at the system default, and
            // ran 92px past this box at 3x with nothing capping them (#69).
            // Clamped below, and given a bit more room besides -- nothing
            // else on the page lines up against this row's exact height, so
            // unlike the cast rail there is no reason to hold it to the
            // original number.
            height: context.rem(7.25),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.rem(1.125)),
              itemCount: entries.length,
              separatorBuilder: (_, __) => SizedBox(width: context.rem(AppRem.ms)),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return HoverButton(
                  scaleAmount: 1.03,
                  showFocusRing: true,
                  onTap: () => _openDetails(entry),
                  child: Container(
                    width: context.rem(13.75),
                    padding: EdgeInsets.all(context.rem(AppRem.ms)),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(context.rem(0.875)),
                      border: Border.all(
                        color: AppColors.inkAlpha(0.08),
                      ),
                    ),
                    child: ClampedTextScale(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.showTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppType.small,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: context.rem(AppRem.xs)),
                          Text(
                            'S${entry.seasonNumber.toString().padLeft(2, '0')}'
                            'E${entry.episodeNumber.toString().padLeft(2, '0')}'
                            ' • ${entry.episodeTitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppType.tiny,
                              color: AppColors.inkAlpha(0.55),
                            ),
                          ),
                          SizedBox(height: context.rem(AppRem.xs)),
                          Text(
                            '${entry.firstAiredLocal.month}/${entry.firstAiredLocal.day}',
                            style: TextStyle(
                              fontSize: AppType.tiny,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkAlpha(0.4),
                            ),
                          ),
                        ],
                      ),
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
