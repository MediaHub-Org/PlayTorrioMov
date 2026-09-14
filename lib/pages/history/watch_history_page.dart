import 'package:flutter/material.dart';

import '../../models/continue_watching/continue_watching_item.dart';
import '../../services/app_spacing.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/theme/app_theme_service.dart';
import '../../widgets/common/glass_back_button.dart';
import '../../widgets/common/library_tabs.dart' show LibraryEmptyState;
import '../../widgets/home/continue_watching_slider.dart';
import '../../services/theme/app_colors.dart';

/// Everything watched, newest first — the full log behind the Continue
/// Watching row.
///
/// The row shows `activeItems`, which keeps one card per show and drops a
/// title once it is finished. `historyItems` is the other half: every
/// episode, up to 100, kept even after finishing. That list was being
/// recorded and persisted all along with nothing to render it — the only
/// reader was the player, looking up a single entry to resume one episode's
/// position.
///
/// It is reached from the row rather than from Library on purpose. Library's
/// tabs mean *what you chose to keep*; this is a record of what happened,
/// which is a different question and belongs next to the row that already
/// asks it.
class WatchHistoryPage extends StatelessWidget {
  /// Narrows to one section's history, using the same rule the row uses —
  /// see [ContinueWatchingService.matchesTypeFilter].
  final String? typeFilter;

  final String title;

  const WatchHistoryPage({super.key, this.typeFilter, this.title = 'History'});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    final inset = AppSpacing.pageInset(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        // Same leading inset and shared button as every other pushed page
        // -- AppBar's own 56px slot would centre it somewhere else, and a
        // narrower slot clamps the 48x48 button into an ellipse.
        leadingWidth: inset + 48,
        leading: Padding(
          padding: EdgeInsets.only(left: inset),
          child: const Center(child: GlassBackButton()),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: ValueListenableBuilder<List<ContinueWatchingItem>>(
        valueListenable: ContinueWatchingService.historyItems,
        builder: (context, all, _) {
          final items =
              all
                  .where(
                    (i) => ContinueWatchingService.matchesTypeFilter(
                      i,
                      typeFilter,
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

          if (items.isEmpty) {
            return const LibraryEmptyState(
              icon: Icons.history_rounded,
              title: 'Nothing watched yet',
              subtitle: 'Play something and it will be listed here.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Same card the row uses, laid out as a wrap so a long log
              // reads as a grid instead of one endless horizontal strip.
              final cardWidth = constraints.maxWidth > 900
                  ? 260.0
                  : constraints.maxWidth > 600
                  ? 220.0
                  : 180.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(inset, 16, inset, 32),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 18,
                  children: [
                    for (final item in items)
                      ContinueWatchingCard(
                        item: item,
                        width: cardWidth,
                        palette: palette,
                        onTap: () =>
                            ContinueWatchingService.resumePlayback(context, item),
                        // Removing here forgets the log entry. It deliberately
                        // does not touch activeItems: dropping a finished
                        // episode from history should not also clear the card
                        // still offering to resume the next one.
                        onRemove: () =>
                            ContinueWatchingService.removeHistoryItem(item),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
