import 'package:flutter/material.dart';

import '../../widgets/common/page_search_button.dart';

/// Comics browsing, pending a data source.
///
/// This is deliberately an explicit empty state rather than an empty grid.
/// There is no comics provider wired up: every candidate evaluated so far
/// either routes downloads through a Cloudflare-challenged file host or
/// renders its chapter list client-side, neither of which is scrapeable
/// server-side (see docs/ROADMAP.md). Showing a blank grid implied the
/// catalog was merely empty; this says what is actually going on.
///
/// When a source exists, this page becomes a [BrowseScaffold] like the other
/// catalogs — hero plus rows — and nothing else has to change.
class ComicsPage extends StatelessWidget {
  const ComicsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Comics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                PageSearchButton(),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 46,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No comics source yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      'Comics are not wired up to a provider yet. Manga is '
                      'available now under the Manga tab, and comics will '
                      'appear here once a workable source is in place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
