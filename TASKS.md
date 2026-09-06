# Tasks

> PlayTorrioMov is now the main repo (not PlayTorrioMod) — smaller codebase,
> video-only (Movies/Series/Anime/Live TV), works well.

- [ ] Logo: add extra element — black & white film-strip/clapperboard line
      accent (🎬🎞️ movie-action motif)
- [ ] Consistent header spacing (margin/padding) across all pages, mobile
      first; see ROADMAP.md § Code and consistency #10
- [x] Fix Android back button — root cause was `NestedNavigator` not
      participating in the system back-gesture dispatch; see ROADMAP.md §
      Resolved.
- [x] Fix tags on pages — only icon shows, doesn't fit screen; unified into
      one shared `GenreTagRow` widget, icon-only, one row, same across
      Movies/Series/Anime/Anime-Arabic — see ROADMAP.md § Resolved #12
- [x] Split Movies & Series into two separate sections — see ROADMAP.md §
      Navigation principle and § Resolved #13
- [x] Settings entry point: same fixed position on every screen — a later
      pass found the mobile/desktop bars actually differed in height (52 vs
      60) and button size, drifting the icon a few px between tiers; fixed
      with a shared `SettingsIconButton` + `TopBar.sharedHeight`. See
      ROADMAP.md § Resolved #14.
- [ ] Design mobile first, as a standing policy — ROADMAP.md § Requested
      UI work #15
- [x] Trim the subtitle language list to commonly-used / actually-available
      languages — see ROADMAP.md § Resolved #16
- [x] A catalog fetch failure silently looks like "no content" instead of a
      retryable error — see ROADMAP.md § Resolved #17
- [x] Unify the genre/decade/sort/search pill row's design and position
      across Movies, Series, and Anime (`PillFilterHeaderBar`); enforce a
      760x600 minimum desktop window size so the app can't be shrunk into
      the cramped mobile breakpoint; remove Library's own local search bar;
      add a Watched chip to Library; add a favorite-channel heart on IPTV
      channel cards with a new Live TV chip in Library to show them — see
      ROADMAP.md § Resolved #18
- [x] Fix IPTV channel favoriting discoverability, the 5-section bar being
      hidden behind Details/Search pages on desktop, the Settings icon's
      remaining position drift (a `Flexible`/`Spacer` flex-space bug), and
      unify the back button design across all 8 details/search pages
      (new `GlassBackButton`) — see ROADMAP.md § Resolved #19
- [x] Pull latest commits from original repo (PlayTorrioMod) and log them —
      done: PlayTorrioMod sits 3 commits behind its own upstream
      (`ayman708-UX/PlayTorrioV3`), see ROADMAP.md § Upstream tracking for
      what was ported into this repo and what got skipped and why.
- [x] Re-add roadmap, releases, changelog, and README (own docs, no longer
      pointing to PlayTorrioMod as source of truth)
