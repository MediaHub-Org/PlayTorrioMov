# Upstream merge tracking — ad0e40d / 6c4d0cf / f1f1310

Working checklist for porting the 3-commit gap between Mov and
`ayman708-UX/PlayTorrioV3` (`v3/main`, still at `f1f1310` as of this pass —
see [ROADMAP.md](ROADMAP.md#upstream-tracking) for the high-level summary
and history). One row per file per commit. This file is a scratch log for
doing the port, not a permanent record — safe to delete once all three
land and ROADMAP.md's own table is updated.

Legend: ✅ clean cherry-pick · ✍️ hand-merged · ⏭️ skipped (see note) · ⬜ not started

## ad0e40d — audio dub & language filtering, scraper touch-ups

Branch: `port/ad0e40d-dub-lang-filtering`

| File | Status | Note |
|---|---|---|
| `lib/models/stream/stream_model.dart` | ✅ | Clean cherry-pick — `getAudioLanguages`/`hasAudioLanguage`/`getAudioBadge`. |
| `lib/pages/player/watch_screen.dart` | ✍️ | Hand-merged. Ported: `_selectedAudioFilter` state + filter clause, `_buildAudioFilterDropdown`/`_showAudioGlassDropdown`/`_buildAudioDropdownItem` (styled to match Mov's existing size/addon dropdowns), audio badge on `_SourceCard`, and the smart open-above/clamped positioning fix retrofitted onto the existing size and addon dropdowns. Skipped: the type-filter chip bar (Debrid/Torrent/Direct) and seeder filter — both predate this commit and Mov never had them; the mobile bottom-sheet variants (`_showXBottomSheet`, glass bottom-sheet container) — a parallel mobile UX Mov doesn't have for any filter yet, out of scope for "port this filter feature"; the desktop `Expanded` flex responsiveness tweak — Mov's flex ratio (6:4) already differs from upstream's own baseline (5:6), so blindly following upstream's new ratio risks an unreviewed layout regression with no way to see it rendered here. |
| `lib/services/scraper/sites/{fsharetv,fsonic,movy,nova,purstream,vidvault,vidzee,vixsrc,vuflix,xdownloader}.dart` | ✅ | Clean cherry-pick. |
| `test/audio_language_detector_test.dart` | ✅ | Clean cherry-pick; fixed `package:playtorrio/…` → `package:playtorriomov/…` import (upstream's package name). All 26 cases pass. |
| Version-bump files (`pubspec.yaml`, `README.md`, `installer/windows/setup.iss`, `windows/runner/Runner.rc`, `about_settings_page.dart`, `settings_page.dart`, `updates_settings_page.dart`, `.github/workflows/build.yml`) | ⏭️ | Mov is already ahead on its own version line (`1.1.6+14`); don't regress to `1.1.3+14`. |
| `lib/services/backup/backup_restore_service.dart` | ⏭️ | Doesn't exist in Mov — Mov's cloud-backup feature lives in `backup_service.dart`/`cloud_backup_settings.dart` under different names. Not this commit's concern. |
| `lib/pages/home/home_page.dart`, `lib/services/theme/dock_settings.dart`, `lib/widgets/common/app_liquid_dock.dart`, `lib/pages/audiobooks/audiobook_player_screen.dart`, `lib/services/music/music_player_controller.dart` | ⏭️ | Nav-shell/audiobook/music files that don't exist in Mov's architecture. |

Verification: `flutter analyze` on all touched files — 0 issues. `flutter test test/audio_language_detector_test.dart` — 26/26 pass. Full `flutter test` — 1 unrelated failure (`chunk1_vyla_test.dart` PeeStream, a live-network scraper test hitting a real external site not touched by this commit; not a regression).

## 6c4d0cf — player error filtering & stream health

Branch: `port/6c4d0cf-stream-error-filtering` (planned, off branch 1)

⬜ Not started yet.

## f1f1310 — Stremio catalog-extra & collection addons

Branch: `port/f1f1310-stremio-catalog-extras` (planned, off branch 2)

⬜ Not started yet.
