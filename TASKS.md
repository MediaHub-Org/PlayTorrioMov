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
- [x] Settings entry point: same fixed position (top-right on mobile) on
      every screen — confirmed already true, see ROADMAP.md § Requested UI
      work #14
- [ ] Design mobile first, as a standing policy — ROADMAP.md § Requested
      UI work #15
- [x] Trim the subtitle language list to commonly-used / actually-available
      languages — see ROADMAP.md § Resolved #16
- [ ] A catalog fetch failure silently looks like "no content" instead of a
      retryable error — see ROADMAP.md § Known bugs #17
- [x] Pull latest commits from original repo (PlayTorrioMod) and log them —
      done: PlayTorrioMod sits 3 commits behind its own upstream
      (`ayman708-UX/PlayTorrioV3`), see ROADMAP.md § Upstream tracking for
      what was ported into this repo and what got skipped and why.
- [x] Re-add roadmap, releases, changelog, and README (own docs, no longer
      pointing to PlayTorrioMod as source of truth)
