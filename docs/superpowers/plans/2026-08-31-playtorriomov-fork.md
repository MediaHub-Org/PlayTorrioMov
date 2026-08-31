# PlayTorrioMov Fork Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork PlayTorrioMod into a new Media-only sibling app, PlayTorrioMov (Movies & Series / Anime / Live TV / Library), dropping Music/Podcasts/Audiobooks/Books/Manga/Comics and collapsing the now-single-hub nav abstraction.

**Architecture:** Filesystem copy of the whole repo to a sibling directory, then a sequence of deletions and surgical edits against the copy. This is a subtractive mechanical port, not new behavior — there is no new logic to drive with unit tests. Each task's "verify" step is `flutter analyze` (must stay clean throughout) instead of a written test, except the final task which also runs `flutter test` and a manual launch. Do the work directly in the target repo at `D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov` — do not touch PlayTorrioMod.

**Tech Stack:** Flutter/Dart, Android Gradle/Kotlin, Xcode (iOS/macOS project files), CMake (Windows), Inno Setup (Windows installer).

**Spec:** `docs/superpowers/specs/2026-08-31-playtorriomov-fork-design.md` (in PlayTorrioMod — this plan's source of truth for scope and rationale).

## Global Constraints

- Target directory: `D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov` — filesystem copy, fresh git history, not a clone of PlayTorrioMod's `.git`.
- New app display name: `PlayTorrioMov`. New Android `applicationId`: `com.mediahub.playtorriomov`. Android `namespace` (Kotlin package `com.example.playtorrio`) stays unchanged — it is only the generated R/BuildConfig package, not the install identity (see comment in `android/app/build.gradle.kts`), and the original PlayTorrioMod build already keeps them mismatched on purpose.
- Keep `archive` package (subtitle-zip extraction, shared with movies/series). Drop `audio_service` and `xml` (only removed-module consumers).
- Collapse, don't prune: once Music/Books hubs are gone only one hub remains, so the `AppHub` enum and the hub dimension in `HubController`/`AdaptiveNavShell`/`TopBar` are deleted outright, not left as a 1-branch switch.
- Final section labels or ids do not change except the "watch" section's display label: `Movies/Series` → `Movies & Series`. Search stays an icon (`page_search_button.dart`), not a nav tab — nothing to do here, just don't add one.
- After every task: `flutter analyze` must report no new errors introduced by that task (pre-existing warnings elsewhere in the repo are not this plan's concern).

---

### Task 1: Fork the repo, sanity-build the untouched copy

**Files:**
- Create: `D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov\` (entire copy of PlayTorrioMod)

**Interfaces:** None — this task produces the working tree every later task edits.

- [ ] **Step 1: Copy the repository**

```powershell
Copy-Item -Path "D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMod" -Destination "D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov" -Recurse
Remove-Item -Recurse -Force "D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov\.git"
Remove-Item -Recurse -Force "D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov\build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov\.dart_tool" -ErrorAction SilentlyContinue
```

- [ ] **Step 2: Initialize fresh git history**

```powershell
Set-Location "D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov"
git init
git add -A
git commit -m "fork from PlayTorrioMod"
```

(If this errors with "Author identity unknown", stop and ask the user to set `git config user.name`/`user.email` — do not set it yourself.)

- [ ] **Step 3: Confirm the untouched copy still builds**

```powershell
flutter pub get
flutter analyze
```

Expected: same analyze output as PlayTorrioMod (no new errors — this is the baseline every later task's `flutter analyze` diffs against).

- [ ] **Step 4: Commit** (only if Step 1's commit didn't already capture `pubspec.lock`/generated files pulled in by `pub get`)

```powershell
git add -A
git commit -m "chore: pub get baseline" --allow-empty
```

---

### Task 2: Delete the Music, Podcasts, Audiobooks, Books, Manga, Comics modules

**Files:**
- Delete: everything listed below (all under `D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov`)

**Interfaces:** None produced — later tasks (3, 6, 7) remove the remaining references to these deleted files.

- [ ] **Step 1: Delete module directories and files**

```powershell
Set-Location "D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov"

# Music
Remove-Item -Recurse -Force lib\models\music, lib\services\music, lib\pages\music, lib\widgets\music
Remove-Item -Force lib\pages\hub\music_hub.dart
Remove-Item -Force lib\pages\settings\appearance\music_player_studio_page.dart
Remove-Item -Force test\music_smoke_test.dart

# Podcasts
Remove-Item -Recurse -Force lib\services\podcast, lib\pages\podcast

# Audiobooks
Remove-Item -Recurse -Force lib\models\audiobook, lib\services\audiobook, lib\pages\audiobooks, lib\widgets\audiobook
Remove-Item -Force lib\pages\settings\appearance\audiobook_player_studio_page.dart
Remove-Item -Force test\audiobookbay_scraper_test.dart

# Books
Remove-Item -Recurse -Force lib\models\book, lib\services\books, lib\pages\read
Remove-Item -Force lib\pages\collection\books_library_page.dart
Remove-Item -Force test\pages\book_reader_zip_slip_test.dart

# Manga
Remove-Item -Recurse -Force lib\models\manga, lib\services\manga, lib\pages\manga, lib\widgets\manga
Remove-Item -Force lib\pages\settings\appearance\manga_settings_page.dart

# Comics
Remove-Item -Force lib\pages\catalog\comics_page.dart

# Hub wrapper for the three removed hubs
Remove-Item -Force lib\pages\hub\books_hub.dart
```

- [ ] **Step 2: Confirm nothing outside this plan's later tasks still imports the deleted paths**

```powershell
Select-String -Path lib\**\*.dart -Pattern "models/music|services/music|pages/music|widgets/music|models/audiobook|services/audiobook|pages/audiobooks|widgets/audiobook|models/book/|services/books|pages/read/|models/manga|services/manga|pages/manga|widgets/manga|services/podcast|pages/podcast|books_library_page|comics_page|books_hub" -ErrorAction SilentlyContinue
```

Expected: only hits inside files this plan's later tasks (3, 6, 7) still edit — `lib/main.dart`, `lib/pages/hub/hub_page.dart` (fixed in Task 4), `lib/pages/settings/appearance_settings_page.dart`, `lib/pages/settings/about_settings_page.dart`. If anything else shows up, note the file — it's a shared/mixed file this plan missed and needs its own fix before continuing.

- [ ] **Step 3: Commit**

```powershell
git add -A
git commit -m "remove Music, Podcasts, Audiobooks, Books, Manga, Comics modules"
```

(`flutter analyze` will show new errors at this point — main.dart and the hub wiring still reference deleted files. That's expected; Tasks 3–4 fix it. Don't try to make analyze clean yet.)

---

### Task 3: Strip main.dart's bootstrap and delete MediaSessionService

**Files:**
- Modify: `lib/main.dart`
- Delete: `lib/services/media_session/media_session_service.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `main()`'s `Future.wait` list, trimmed to only keep-module services — later tasks don't depend on this.

- [ ] **Step 1: Remove the deleted-module imports and service calls from main.dart**

Replace the import block:

```dart
import './services/addon/addon_manager.dart';
import './services/theme/app_theme_service.dart';
import './services/updater/app_updater_service.dart';
import './services/audiobook/audiobook_library_service.dart';
import './services/backup/cloud_backup_settings.dart';
import './services/download/download_service.dart';
import './services/books/continue_reading_service.dart';
import './services/books/reader_settings.dart';
import './services/continue_watching/continue_watching_service.dart';
import './services/theme/custom_background_service.dart';
import './services/theme/glass_settings.dart';
import './services/audiobook/audiobook_settings.dart';
import './services/iptv/iptv_controller.dart';
import './services/iptv/iptv_settings.dart';
import './services/manga/manga_settings.dart';
import './services/media_session/media_session_service.dart';
import './services/music/music_download_service.dart';
import './services/music/music_settings.dart';
import './services/music/qobuz_music_service.dart';
import './services/my_list/my_list_service.dart';
import './services/player/player_settings.dart';
import './services/tmdb/tmdb_settings.dart';
import './services/stream/torrent_stream_service.dart';
import './services/config/env_service.dart';
import './services/window/window_service.dart';
import './services/p2p/p2p_settings_service.dart';
import './services/discord/discord_rpc_service.dart';
```

with:

```dart
import './services/addon/addon_manager.dart';
import './services/theme/app_theme_service.dart';
import './services/updater/app_updater_service.dart';
import './services/backup/cloud_backup_settings.dart';
import './services/download/download_service.dart';
import './services/continue_watching/continue_watching_service.dart';
import './services/theme/custom_background_service.dart';
import './services/theme/glass_settings.dart';
import './services/iptv/iptv_controller.dart';
import './services/iptv/iptv_settings.dart';
import './services/my_list/my_list_service.dart';
import './services/player/player_settings.dart';
import './services/tmdb/tmdb_settings.dart';
import './services/stream/torrent_stream_service.dart';
import './services/config/env_service.dart';
import './services/window/window_service.dart';
import './services/p2p/p2p_settings_service.dart';
import './services/discord/discord_rpc_service.dart';
```

Replace the `Future.wait` block:

```dart
  await Future.wait([
    AddonManager.instance.initialize(),
    AudiobookLibraryService.instance.init(),
    AppThemeService.initialize(),
    AudiobookSettings.initialize(),
    CloudBackupSettings.initialize(),
    ContinueWatchingService.initialize(),
    ContinueReadingService.initialize(),
    ReaderSettings.initialize(),
    CustomBackgroundService.initialize(),
    GlassSettings.initialize(),
    IptvController.instance.init(),
    IptvSettings.initialize(),
    MangaSettings.initialize(),
    MusicSettings.initialize(),
    MusicDownloadService.instance.init(),
    QobuzMusicService.instance.initialize(),
    MyListService.initialize(),
    TmdbSettings.initialize(),
    P2pSettingsService.initialize(),
    DownloadService.instance.initialize(),
    TorrentStreamService().start(),
    // Publishes the active source to the Android/iOS media session. Awaited
    // with the rest so the session exists before anything can start playing,
    // but it never throws -- a missing session costs the notification
    // controls, not startup.
    MediaSessionService.init(),
    DiscordRpcService.instance.initialize(),
  ]);
```

with:

```dart
  await Future.wait([
    AddonManager.instance.initialize(),
    AppThemeService.initialize(),
    CloudBackupSettings.initialize(),
    ContinueWatchingService.initialize(),
    CustomBackgroundService.initialize(),
    GlassSettings.initialize(),
    IptvController.instance.init(),
    IptvSettings.initialize(),
    MyListService.initialize(),
    TmdbSettings.initialize(),
    P2pSettingsService.initialize(),
    DownloadService.instance.initialize(),
    TorrentStreamService().start(),
    DiscordRpcService.instance.initialize(),
  ]);
```

- [ ] **Step 2: Delete the now-unreferenced MediaSessionService**

```powershell
Remove-Item -Force lib\services\media_session\media_session_service.dart
```

- [ ] **Step 3: Verify**

```powershell
flutter analyze lib/main.dart
```

Expected: no errors on this file (other files still broken until later tasks — that's fine).

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git rm -r lib/services/media_session
git commit -m "strip main.dart bootstrap to keep-modules, delete MediaSessionService"
```

---

### Task 4: Collapse the hub abstraction to a single Media hub

**Files:**
- Delete: `lib/utils/app_hub.dart`, `lib/utils/hub_navigator.dart`
- Modify (full rewrite): `lib/utils/hub_controller.dart`, `lib/pages/hub/hub_page.dart`, `lib/widgets/common/adaptive_nav_shell.dart`, `lib/widgets/common/top_bar.dart`

**Interfaces:**
- Consumes: `lib/pages/hub/media_hub.dart` (unmodified — reads `HubController.instance.mediaSection`, `.watchType`, calls `.setWatchType`), `lib/widgets/common/section_top_bar.dart` (unmodified — reads `HubController.instance.currentSections`/`.currentSectionId`, calls `.setCurrentSection`).
- Produces: `HubController` keeps its existing member names (`mediaSection`, `watchType`, `setWatchType`, `setMediaSection`, `currentSections`, `currentSectionId`, `setCurrentSection`) with identical signatures, so `media_hub.dart` and `section_top_bar.dart` need zero changes — only the hub dimension (`AppHub`, `currentHub`, `setHub`, the books/music branches) is deleted.

- [ ] **Step 1: Delete `app_hub.dart` and `hub_navigator.dart`**

```powershell
Remove-Item -Force lib\utils\app_hub.dart
Remove-Item -Force lib\utils\hub_navigator.dart
```

(`hub_navigator.dart` has exactly one caller today — `hub_page.dart`'s `registerGoHome` — and Step 3 removes that call, so nothing references it after this task.)

- [ ] **Step 2: Rewrite `lib/utils/hub_controller.dart`**

```dart
import 'package:flutter/material.dart';

/// A single section within the Media hub (Movies & Series, Anime, Live TV,
/// Library).
class HubSection {
  final String id;
  final String label;
  final IconData icon;

  const HubSection({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Global controller for the top-level navigation: which section is active,
/// and (for the Movies & Series section) which of its two sub-tabs is
/// showing. The header and the hub both read/write this so navigation stays
/// in sync.
class HubController extends ChangeNotifier {
  static final HubController instance = HubController._internal();
  HubController._internal();

  String _mediaSection = 'watch';

  // Movies and Series share one section but stay separate catalogs, one tap
  // apart. See SectionSubTabs for why.
  String _watchType = 'movie'; // 'movie' | 'series'

  String get mediaSection => _mediaSection;
  String get watchType => _watchType;

  void setWatchType(String type) {
    if (_watchType == type) return;
    _watchType = type;
    notifyListeners();
  }

  void setMediaSection(String id) {
    if (_mediaSection == id) return;
    _mediaSection = id;
    notifyListeners();
  }

  /// The Media hub's four sections, shown as chips on tablet/desktop
  /// (SectionTopBar) and as the bottom tab bar on mobile (AdaptiveNavShell).
  List<HubSection> get currentSections => const [
        HubSection(id: 'watch', label: 'Movies & Series', icon: Icons.movie_rounded),
        HubSection(id: 'anime', label: 'Anime', icon: Icons.animation_rounded),
        HubSection(id: 'iptv', label: 'Live TV', icon: Icons.live_tv_rounded),
        HubSection(id: 'collection', label: 'Library', icon: Icons.video_library_rounded),
      ];

  String get currentSectionId => _mediaSection;

  void setCurrentSection(String id) => setMediaSection(id);
}
```

- [ ] **Step 3: Rewrite `lib/pages/hub/hub_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common/nested_navigator.dart';
import '../../widgets/common/universal_play_bar.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../widgets/common/adaptive_nav_shell.dart';
import '../settings/settings_page.dart';
import 'media_hub.dart';

/// HubPage: the top-level container hosting the app's single Media hub
/// (Movies & Series, Anime, Live TV, Library).
class HubPage extends StatefulWidget {
  const HubPage({super.key});

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  final FocusNode _focusNode = FocusNode();

  // Bumped after Settings closes to force the hub to remount and pick up any
  // addon changes made there — mirrors the old multi-hub cache invalidation,
  // just for the one hub that's left.
  int _rebuildKey = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// TV remote Back/Exit support: Escape pops the current route.
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Only pop if there is actually a route to pop. On the root HubPage
      // there is nothing beneath it, so popping would leave a black screen.
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = AppBreakpoints.of(context);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF080A0F),
        body: Stack(
          children: [
            // Nav chrome + content: TopBar on tablet/desktop, a collapsed
            // top bar + bottom tab bar on mobile. See AdaptiveNavShell.
            Positioned.fill(
              child: AdaptiveNavShell(
                onSettingsTap: () async {
                  await Navigator.push(
                    context,
                    LiquidRevealRoute(
                      page: const SettingsPage(),
                      tapPosition: null,
                    ),
                  );
                  // Addons may have changed in Settings — remount the hub so
                  // it rebuilds and refetches on next show.
                  if (mounted) {
                    setState(() => _rebuildKey++);
                  }
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadii.lg),
                  ),
                  child: NestedNavigator(
                    key: ValueKey(_rebuildKey),
                    child: const MediaHub(),
                  ),
                ),
              ),
            ),
            // Universal Play Bar. On desktop/tablet it sits 16px above the
            // bottom; on mobile it clears AdaptiveNavShell's bottom tab bar.
            Positioned(
              bottom: tier == ScreenTier.mobile
                  ? AdaptiveNavShell.mobileBottomBarInset(context) + 12
                  : 16,
              left: 12,
              right: 12,
              // UniversalPlayBar hides itself when nothing is playing.
              child: const UniversalPlayBar(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rewrite `lib/widgets/common/adaptive_nav_shell.dart`** — drop the hub-pill row

```dart
import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../utils/hub_controller.dart';
import 'sidebar_logo.dart';
import 'top_bar.dart';

/// Tier-aware nav chrome wrapping the Media hub's content area.
///
/// Desktop/tablet keep [TopBar]: logo, sections as a chip row beneath it
/// (see [SectionTopBar]), settings on the right.
///
/// Mobile mirrors that hierarchy: the bottom bar -- the easiest thing to
/// reach on a phone -- carries the hub's four sections. The header is just
/// the wordmark and a settings button.
class AdaptiveNavShell extends StatelessWidget {
  /// Height of the mobile bottom tab bar. Callers positioning other
  /// bottom-anchored chrome (e.g. a mini player) above it on mobile
  /// should offset by at least this much.
  static const double mobileBottomBarHeight = 64;

  /// Total space the mobile bottom tab bar occupies on screen, including
  /// the device's bottom safe-area inset (e.g. the iOS home indicator).
  /// Callers positioning other bottom-anchored chrome above it on mobile
  /// (e.g. a mini player) should use this instead of [mobileBottomBarHeight]
  /// alone, or their chrome will overlap the inset.
  static double mobileBottomBarInset(BuildContext context) =>
      mobileBottomBarHeight + MediaQuery.paddingOf(context).bottom;

  final Widget child;
  final VoidCallback? onSettingsTap;

  const AdaptiveNavShell({
    super.key,
    required this.child,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final tier = AppBreakpoints.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    if (tier == ScreenTier.mobile) {
      return Column(
        children: [
          SizedBox(height: topPadding),
          _MobileTopBar(onSettingsTap: onSettingsTap),
          Expanded(child: child),
          const SafeArea(top: false, child: _MobileSectionTabBar()),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(height: topPadding),
        TopBar(onSettingsTap: onSettingsTap),
        Expanded(child: child),
      ],
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const _MobileTopBar({this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0D15),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Flexible(child: SidebarLogo()),
          const Spacer(),
          if (onSettingsTap != null)
            IconButton(
              onPressed: onSettingsTap,
              tooltip: 'Settings',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
            ),
        ],
      ),
    );
  }
}

/// The four sections of the hub, in the bottom bar where they are easiest to
/// reach.
class _MobileSectionTabBar extends StatelessWidget {
  const _MobileSectionTabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('adaptiveNavMobileBar'),
      height: AdaptiveNavShell.mobileBottomBarHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0D15),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: ListenableBuilder(
        listenable: HubController.instance,
        builder: (context, _) {
          final sections = HubController.instance.currentSections;
          final activeId = HubController.instance.currentSectionId;
          return Row(
            children: [
              for (final section in sections)
                Expanded(
                  child: _SectionTab(
                    section: section,
                    selected: section.id == activeId,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final HubSection section;
  final bool selected;

  const _SectionTab({required this.section, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white54;
    return InkWell(
      onTap: () => HubController.instance.setCurrentSection(section.id),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(section.icon, color: color, size: 21),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              section.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rewrite `lib/widgets/common/top_bar.dart`** — drop the hub switcher, keep logo + settings

```dart
import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import 'sidebar_logo.dart';

/// The slim global top bar shown above the hub's content.
///
/// Holds the PlayTorrio logo and a Settings button. The section switcher for
/// the hub's four sections renders below it, in the content area — see
/// [SectionTopBar].
class TopBar extends StatelessWidget {
  /// The height available to the bar. Callers should inset their content by
  /// this amount so nothing sits beneath the bar.
  final double height;

  /// Invoked when the settings (gear) button is tapped.
  final VoidCallback? onSettingsTap;

  const TopBar({super.key, this.height = 60, this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D15),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Align(alignment: Alignment.centerLeft, child: SidebarLogo()),
          if (onSettingsTap != null)
            Align(
              alignment: Alignment.centerRight,
              child: _settingsButton(onTap: onSettingsTap!),
            ),
        ],
      ),
    );
  }

  Widget _settingsButton({required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Settings',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        foregroundColor: Colors.white70,
      ),
      icon: const Icon(Icons.settings_rounded, size: 20),
    );
  }
}
```

- [ ] **Step 6: Verify**

```powershell
flutter analyze lib/utils/hub_controller.dart lib/pages/hub/hub_page.dart lib/widgets/common/adaptive_nav_shell.dart lib/widgets/common/top_bar.dart lib/pages/hub/media_hub.dart lib/widgets/common/section_top_bar.dart
```

Expected: no errors on any of these six files. (`media_hub.dart` and `section_top_bar.dart` are listed because they're the consumers this task promised not to break — confirm, don't just assume.)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "collapse hub abstraction: single Media hub, drop AppHub"
```

---

### Task 5: Strip the deleted-module tiles from Settings pages

**Files:**
- Modify: `lib/pages/settings/appearance_settings_page.dart`, `lib/pages/settings/about_settings_page.dart`

**Interfaces:** None — leaf UI, nothing downstream depends on these.

- [ ] **Step 1: `appearance_settings_page.dart` — drop the three removed-module imports**

Replace:

```dart
import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/audiobook/audiobook_settings.dart';
import '../../services/theme/custom_background_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/manga/manga_settings.dart';
import '../../services/music/music_settings.dart';
import 'appearance/audiobook_player_studio_page.dart';
import 'appearance/custom_background_settings_page.dart';
import 'appearance/liquid_glass_settings_page.dart';
import 'appearance/live_tv_settings_page.dart';
import 'appearance/manga_settings_page.dart';
import 'appearance/music_player_studio_page.dart';
```

with:

```dart
import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/custom_background_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/iptv/iptv_settings.dart';
import 'appearance/custom_background_settings_page.dart';
import 'appearance/liquid_glass_settings_page.dart';
import 'appearance/live_tv_settings_page.dart';
```

- [ ] **Step 2: Delete "Button 4: Manga UI", "Button 5: Audiobook UI", "Button 6: Music UI"**

Remove these three `ValueListenableBuilder` blocks (and their preceding `const SizedBox(height: 14)`) — from the comment `// Button 4: Manga UI & Reader Atmosphere` through the end of the `// Button 6: Music UI & Player Studio` block (the `ValueListenableBuilder<MusicFullscreenPreset>` closing with `),` before `const SizedBox(height: 28),`). What remains after Button 2 (Live TV) is directly `const SizedBox(height: 28),` followed by the "Visual Overview Notes" section — unchanged.

- [ ] **Step 3: `about_settings_page.dart` — rewrite the hub description card and `_HubList`**

Replace:

```dart
              const _Card(
                title: 'Watch, Listen, Read',
                body:
                    'One app for every format. Navigation is organised by what '
                    'you want to do rather than by file type, so the same '
                    'search, library and playback surface serves all three.',
                child: _HubList(),
              ),
```

with:

```dart
              const _Card(
                title: 'Movies & Series, Anime, Live TV',
                body:
                    'One app for streaming media. The same search, library '
                    'and playback surface serves every section.',
                child: _HubList(),
              ),
```

Replace the `_HubList` widget's `_hubs` list:

```dart
  static const _hubs = [
    (Icons.play_circle_outline_rounded, 'Watch',
        'Movies/Series · Anime · Live TV · Library'),
    (Icons.headphones_rounded, 'Listen',
        'Music · Podcasts · Radio · Library'),
    (Icons.menu_book_rounded, 'Read',
        'Audiobooks · Books · Comics/Manga · Library'),
  ];
```

with:

```dart
  static const _hubs = [
    (Icons.play_circle_outline_rounded, 'Movies & Series',
        'Movies · Series · Anime · Live TV · Library'),
  ];
```

(The `SizedBox(width: 58)` label column in `_HubList.build` was sized for the shorter "Watch"/"Listen"/"Read" labels — widen it to fit "Movies & Series": change `width: 58` to `width: 108` in that same file's `build` method.)

- [ ] **Step 4: Verify**

```powershell
flutter analyze lib/pages/settings/appearance_settings_page.dart lib/pages/settings/about_settings_page.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/settings/appearance_settings_page.dart lib/pages/settings/about_settings_page.dart
git commit -m "settings: drop Manga/Audiobook/Music tiles and hub descriptions"
```

---

### Task 6: Strip removed-module branches from shared services/widgets

**Files:**
- Modify: `lib/services/discord/discord_rpc_service.dart`, `lib/services/download/download_service.dart`, `lib/widgets/common/universal_play_bar.dart`, `lib/services/playback_coordinator.dart`, `lib/widgets/common/like_button.dart`

**Interfaces:** None — internal cleanup, public method signatures used by keep-modules (`setWatchingMovie`, `setWatchingSeries`, `setWatchingAnime`, `setWatchingLiveTv`, `clearToIdle`, `clearPresence`, `PlaybackCoordinator.activate` and friends) are unchanged.

- [ ] **Step 1: `discord_rpc_service.dart` — drop the four removed-module status methods and enum members**

Replace the enum:

```dart
enum DiscordActivityKind {
  idle,
  movie,
  series,
  anime,
  liveTv,
  audiobook,
  book,
  manga,
  music,
}
```

with:

```dart
enum DiscordActivityKind {
  idle,
  movie,
  series,
  anime,
  liveTv,
}
```

Delete these four methods in full: `setListeningAudiobook`, `setReadingBook`, `setReadingManga`, `setListeningMusic` (each runs from its `///` doc comment through its closing `}`, ending with `await _updatePresence(presence); }`).

- [ ] **Step 2: `download_service.dart` — drop the audiobook branch**

Replace:

```dart
    required String type, // 'movie', 'series', 'anime', 'audiobook'
```

with:

```dart
    required String type, // 'movie', 'series', 'anime'
```

Replace:

```dart
    final isAudiobook = type == 'audiobook';

    DownloadSourceType sourceType;
    String targetExt = isAudiobook ? '.mp3' : '.mp4';

    if (isAudiobook) {
      // Audio containers only -- sniff the URL, otherwise fall back to a
      // generic '.mp3' (audiobook sources rarely expose a clean extension
      // on a magnet/debrid-resolved URL).
      final lower = rawUrl?.toLowerCase() ?? '';
      for (final ext in ['.m4b', '.m4a', '.mp3', '.opus', '.ogg', '.flac', '.wav']) {
        if (lower.contains(ext)) {
          targetExt = ext;
          break;
        }
      }
      sourceType = (isTorrent && !useDebrid)
          ? DownloadSourceType.p2p
          : (useDebrid ? DownloadSourceType.debrid : DownloadSourceType.http);
    } else if (isTorrent && !useDebrid) {
      sourceType = DownloadSourceType.p2p;
      targetExt = '.mkv'; // Standard container for torrent video
    } else if (useDebrid) {
      sourceType = DownloadSourceType.debrid;
    } else {
      sourceType = DownloadSourceType.http;
      if (rawUrl != null && rawUrl.toLowerCase().contains('.mkv')) {
        targetExt = '.mkv';
      }
    }
```

with:

```dart
    DownloadSourceType sourceType;
    String targetExt = '.mp4';

    if (isTorrent && !useDebrid) {
      sourceType = DownloadSourceType.p2p;
      targetExt = '.mkv'; // Standard container for torrent video
    } else if (useDebrid) {
      sourceType = DownloadSourceType.debrid;
    } else {
      sourceType = DownloadSourceType.http;
      if (rawUrl != null && rawUrl.toLowerCase().contains('.mkv')) {
        targetExt = '.mkv';
      }
    }
```

- [ ] **Step 3: `universal_play_bar.dart` — drop audiobook/podcast branches and stale doc comment**

Replace:

```dart
/// A universal bottom play bar shown across all hubs (Media, Books, Music).
///
/// It reflects whatever is currently playing (music, video, or audiobook) via
/// the global [PlaybackCoordinator], with a play/pause toggle and a stop
/// button. It sits above the AppDock so it never overlaps the hub switcher.
```

with:

```dart
/// A universal bottom play bar shown above the hub's content.
///
/// It reflects whatever is currently playing via the global
/// [PlaybackCoordinator], with a play/pause toggle and a stop button.
```

Replace:

```dart
  Widget _kindIcon(String? kind) {
    final icon = switch (kind) {
      'music' => Icons.music_note_rounded,
      'video' => Icons.movie_rounded,
      'audiobook' => Icons.headphones_rounded,
      'podcast' => Icons.podcasts_rounded,
      _ => Icons.play_arrow_rounded,
    };
```

with:

```dart
  Widget _kindIcon(String? kind) {
    final icon = switch (kind) {
      'video' => Icons.movie_rounded,
      _ => Icons.play_arrow_rounded,
    };
```

Replace:

```dart
  String _kindLabel(String? kind) {
    return switch (kind) {
      'music' => 'MUSIC',
      'video' => 'VIDEO',
      'audiobook' => 'AUDIOBOOK',
      'podcast' => 'PODCAST',
      _ => 'PLAYING',
    };
  }
```

with:

```dart
  String _kindLabel(String? kind) {
    return switch (kind) {
      'video' => 'VIDEO',
      _ => 'PLAYING',
    };
  }
```

(The `canLike`/`LikeButton` block stays — it is dead until something calls `PlaybackCoordinator.activate(..., isLiked: ...)`, which no keep-module source does, so it silently never renders. Leaving it is less risky than tracing every video-player call site to confirm removal is safe, for a mechanical fork task.)

- [ ] **Step 4: `playback_coordinator.dart` — update stale doc comments only (no code change)**

Replace:

```dart
/// A global coordinator that ensures only **one** playback source plays at a
/// time across the whole app (music, video, audiobooks).
```

with:

```dart
/// A global coordinator that ensures only **one** playback source plays at a
/// time across the whole app.
```

Replace:

```dart
  /// [sourceId] uniquely identifies the playback source (e.g. a track id, a
  /// video id, an audiobook id). [kind] is a coarse category ('music',
  /// 'video', 'audiobook') used to decide which global shortcuts apply.
```

with:

```dart
  /// [sourceId] uniquely identifies the playback source (e.g. a video id).
  /// [kind] is a coarse category (currently just 'video') used to decide
  /// which global shortcuts apply.
```

Replace:

```dart
  /// [isLiked]/[onToggleLike] let the play bar show and toggle a like
  /// button for this source (music tracks only — leave both null for
  /// video/audiobook/podcast sources, which have no like concept).
```

with:

```dart
  /// [isLiked]/[onToggleLike] let the play bar show and toggle a like
  /// button for this source. No keep-module source uses this — leave both
  /// null.
```

- [ ] **Step 5: `like_button.dart` — update stale doc comment only**

Replace:

```dart
/// Audiobooks, Manga, Podcasts, Books and Music each had their own: two pill
/// variants, a bare `IconButton`, and two list-row hearts, in three different
/// reds. Worse, the two presentations had contradictory-looking colour rules —
/// the pill filled red and turned its icon *white*, the bare icon turned
/// *red*.
```

with:

```dart
/// PlayTorrioMod's other content types each had their own before this was
/// unified: two pill variants, a bare `IconButton`, and two list-row hearts,
/// in three different reds. Worse, the two presentations had
/// contradictory-looking colour rules — the pill filled red and turned its
/// icon *white*, the bare icon turned *red*.
```

- [ ] **Step 6: Verify**

```powershell
flutter analyze lib/services/discord/discord_rpc_service.dart lib/services/download/download_service.dart lib/widgets/common/universal_play_bar.dart lib/services/playback_coordinator.dart lib/widgets/common/like_button.dart
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add lib/services/discord/discord_rpc_service.dart lib/services/download/download_service.dart lib/widgets/common/universal_play_bar.dart lib/services/playback_coordinator.dart lib/widgets/common/like_button.dart
git commit -m "strip removed-module branches from discord, downloads, play bar"
```

---

### Task 7: Trim pubspec.yaml and fix package-name imports

**Files:**
- Modify: `pubspec.yaml`, `lib/pages/player/player_screen.dart`, `lib/widgets/player/player_subtitle_menu.dart`, `lib/services/subtitles/subtitle_service.dart`, `lib/services/subtitles/subtitle_provider.dart`

**Interfaces:** None.

- [ ] **Step 1: `pubspec.yaml` — rename package, rewrite description, drop unused deps**

Replace:

```yaml
name: playtorrio
description: "All-in-one media streaming app — movies, series, manga, audiobooks, and music. Powered by Stremio addons, torrent streaming, and the open web."
```

with:

```yaml
name: playtorriomov
description: "Media streaming app — movies, series, anime, and live TV. Powered by Stremio addons, torrent streaming, and the open web."
```

Delete the line `  xml: ^7.0.1` and the line `  audio_service: ^0.18.19`.

Replace:

```yaml
  dart_discord_presence: ^1.2.0
```

with (drop the now-moot comment about unused PDF/MOBI/FB2 packages, since the Read hub no longer exists at all):

```yaml
  dart_discord_presence: ^1.2.0 # Discord Rich Presence
```

- [ ] **Step 2: Fix the 4 files importing `package:playtorrio/`**

```powershell
Get-ChildItem -Path lib\pages\player\player_screen.dart, lib\widgets\player\player_subtitle_menu.dart, lib\services\subtitles\subtitle_service.dart, lib\services\subtitles\subtitle_provider.dart | ForEach-Object {
  (Get-Content $_.FullName) -replace 'package:playtorrio/', 'package:playtorriomov/' | Set-Content $_.FullName
}
```

- [ ] **Step 3: Verify**

```powershell
flutter pub get
flutter analyze
```

Expected: `flutter analyze` shows errors ONLY in files this plan has not yet reached (platform config isn't analyzed by `flutter analyze` at all, so this should actually be close to clean — investigate anything unexpected before moving on).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml lib/pages/player/player_screen.dart lib/widgets/player/player_subtitle_menu.dart lib/services/subtitles/subtitle_service.dart lib/services/subtitles/subtitle_provider.dart pubspec.lock
git commit -m "pubspec: rename package to playtorriomov, drop audio_service/xml"
```

---

### Task 8: Rebrand platform identity (Android, iOS, macOS, Windows, installer)

**Files:**
- Modify: `lib/app_info.dart`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`, `macos/Runner.xcodeproj/project.pbxproj`, `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`, `macos/Runner/Configs/AppInfo.xcconfig`, `windows/CMakeLists.txt`, `windows/runner/Runner.rc`, `windows/runner/main.cpp`, `installer/windows/setup.iss`

**Interfaces:** None.

- [ ] **Step 1: `lib/app_info.dart`**

Replace:

```dart
  static const String name = 'PlayTorrioMod';
```

with:

```dart
  static const String name = 'PlayTorrioMov';
```

(Leave `tagline`, `channel`, `fallbackVersion`, `fallbackBuildNumber` as-is — versioning and channel status are independent of the rebrand.)

- [ ] **Step 2: Android — `applicationId` and manifest audio-service entries**

In `android/app/build.gradle.kts`, replace:

```kotlin
        applicationId = "com.mediahub.playtorriomod"
```

with:

```kotlin
        applicationId = "com.mediahub.playtorriomov"
```

(`namespace = "com.example.playtorrio"` stays unchanged — see Global Constraints.)

In `android/app/src/main/AndroidManifest.xml`:

Replace `android:label="PlayTorrioMod"` with `android:label="PlayTorrioMov"`.

Delete this permission and its comment:

```xml
    <!-- Android 14+ requires the specific type for the audio_service
         foreground service that backs the playback notification. -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

Delete the `AudioService` `<service>` block and the `MediaButtonReceiver` `<receiver>` block:

```xml
        <!-- Playback notification / lock screen / Bluetooth controls.
             Both components live in the audio_service plugin; the
             tools:ignore silences lint's "not instantiatable" warning,
             which fires only because the classes are not in this module. -->
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>

        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>

```

(Keep `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS` — used by the download/update-notification path, unrelated to `audio_service`.)

- [ ] **Step 3: iOS — Info.plist and bundle id**

In `ios/Runner/Info.plist`, replace:

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>audio</string>
		<string>fetch</string>
		<string>processing</string>
	</array>
```

with:

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>fetch</string>
		<string>processing</string>
	</array>
```

Replace both `<string>PlayTorrioMod</string>` occurrences (`CFBundleDisplayName` and `CFBundleName` keys) with `<string>PlayTorrioMov</string>`.

In `ios/Runner.xcodeproj/project.pbxproj`, replace all 6 occurrences of `com.mediahub.playtorriomod` with `com.mediahub.playtorriomov` (this naturally covers both the plain `com.mediahub.playtorriomod;` lines and the `com.mediahub.playtorriomod.RunnerTests;` lines):

```powershell
(Get-Content ios\Runner.xcodeproj\project.pbxproj) -replace 'com\.mediahub\.playtorriomod', 'com.mediahub.playtorriomov' | Set-Content ios\Runner.xcodeproj\project.pbxproj
```

- [ ] **Step 4: macOS — bundle id, product name, scheme references**

```powershell
(Get-Content macos\Runner\Configs\AppInfo.xcconfig) -replace 'PlayTorrioMod', 'PlayTorrioMov' -replace 'com\.mediahub\.playtorriomod', 'com.mediahub.playtorriomov' | Set-Content macos\Runner\Configs\AppInfo.xcconfig
(Get-Content macos\Runner.xcodeproj\project.pbxproj) -replace 'PlayTorrioMod\.app', 'PlayTorrioMov.app' -replace 'com\.mediahub\.playtorriomod', 'com.mediahub.playtorriomov' -replace 'PlayTorrioMod"', 'PlayTorrioMov"' | Set-Content macos\Runner.xcodeproj\project.pbxproj
(Get-Content macos\Runner.xcodeproj\xcshareddata\xcschemes\Runner.xcscheme) -replace 'PlayTorrioMod\.app', 'PlayTorrioMov.app' | Set-Content macos\Runner.xcodeproj\xcshareddata\xcschemes\Runner.xcscheme
```

Read `macos/Runner.xcodeproj/project.pbxproj` line ~391 (`TEST_HOST = "$(BUILT_PRODUCTS_DIR)/PlayTorrioMod.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/PlayTorrioMod";`) after the replace to confirm both the `.app` path segment and the trailing bare executable name (`.../PlayTorrioMod"` → `.../PlayTorrioMov"`) both updated — the three-pattern replace above is written to catch both, but this file is hand-edited XML-ish text so verify by reading it, don't just trust the regex.

- [ ] **Step 5: Windows — CMake project name, binary name, Runner.rc, main.cpp window title**

In `windows/CMakeLists.txt`, replace `project(PlayTorrioMod LANGUAGES CXX)` with `project(PlayTorrioMov LANGUAGES CXX)`, and `set(BINARY_NAME "PlayTorrioMod")` with `set(BINARY_NAME "PlayTorrioMov")`.

In `windows/runner/Runner.rc`, replace all 4 occurrences:

```
            VALUE "FileDescription", "PlayTorrioMod" "\0"
```
```
            VALUE "InternalName", "PlayTorrioMod" "\0"
```
```
            VALUE "OriginalFilename", "PlayTorrioMod.exe" "\0"
```
```
            VALUE "ProductName", "PlayTorrioMod" "\0"
```

with the `PlayTorrioMod`/`PlayTorrioMod.exe` substrings replaced by `PlayTorrioMov`/`PlayTorrioMov.exe` respectively (keep the surrounding `VALUE "...", "..." "\0"` structure unchanged).

In `windows/runner/main.cpp`, replace:

```cpp
  if (!window.Create(L"PlayTorrioMod", origin, size)) {
```

with:

```cpp
  if (!window.Create(L"PlayTorrioMov", origin, size)) {
```

- [ ] **Step 6: Windows installer**

In `installer/windows/setup.iss`, replace:

```
#define MyAppName      "PlayTorrioMod"
```

with:

```
#define MyAppName      "PlayTorrioMov"
```

Replace `#define MyAppExeName   "PlayTorrioMod.exe"` with `#define MyAppExeName   "PlayTorrioMov.exe"`.

Replace `#define MyAppURL       "https://github.com/MediaHub-Org/PlayTorrioMod"` with `#define MyAppURL       "https://github.com/MediaHub-Org/PlayTorrioMov"` (update once that GitHub repo exists — a placeholder URL is fine until then, this is a desktop-only installer string, not consumed by the app).

Replace `OutputBaseFilename=PlayTorrioMod-Windows-Setup` with `OutputBaseFilename=PlayTorrioMov-Windows-Setup`.

Replace `AppId={{9B8C7D6E-5F4E-3D2C-1B0A-9F8E7D6C5B4A}` with a freshly generated GUID (Inno Setup's `AppId` must be unique per product so both apps can be installed side by side — reusing PlayTorrioMod's would make Windows treat an install of one as an upgrade of the other):

```powershell
[guid]::NewGuid()
```

Paste the result into `AppId={{<new-guid>}`.

- [ ] **Step 7: Verify**

```powershell
flutter analyze
```

Expected: clean (or matching Task 1's baseline exactly — platform config files aren't analyzed by this command, but a typo introduced by the regex replaces above would show up as a build failure, not an analyze error, so this step is a light sanity check, not full coverage. Task 12 covers actually building.)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "rebrand: PlayTorrioMod -> PlayTorrioMov across all platform identity files"
```

---

### Task 9: README and doc cleanup

**Files:**
- Modify: `README.md`
- Delete: `docs/CHANGELOG.md`, `docs/AUDIT.md`, `docs/FORK_DIFFERENCES.md` (these document PlayTorrioMod's own fork history and diff-from-upstream — copying them verbatim into PlayTorrioMov would misrepresent a different app's history as this one's)
- Modify: `docs/README.md`, `docs/ROADMAP.md`, `docs/branching.md`, `docs/configuration.md` (swap the product name only — leave the rest of their content as-is; a full content audit of these docs is out of scope for this plan)

**Interfaces:** None.

- [ ] **Step 1: Delete the fork-history-specific docs**

```powershell
Remove-Item -Force docs\CHANGELOG.md, docs\AUDIT.md, docs\FORK_DIFFERENCES.md
```

- [ ] **Step 2: Rewrite `README.md`**

Replace the header block (lines 1–20):

```markdown
<p align="center">
  <img src="assets/icon.png" alt="PlayTorrioMod logo" width="160"/>
</p>
<p align="center">
  <h1 align="center">PlayTorrioMod</h1>
  <h3 align="center"><em>Watch, Listen, Read — one app, every format</em></h3>
</p>

<p align="center">
  A Flutter media hub that pulls movies, series, anime, live TV, music, radio,
  podcasts, audiobooks, books, comics and manga into a single interface —
  from Stremio-compatible addons, torrent swarms, and the open web.
</p>

<p align="center">
  <a href="https://github.com/MediaHub-Org/PlayTorrioMod/releases"><img height="20" src="https://img.shields.io/github/v/release/MediaHub-Org/PlayTorrioMod?include_prereleases&style=flat&color=7C5CFF" alt="Latest release"/></a>
  <img height="20" src="https://img.shields.io/badge/LICENSE-GPL--3.0-4169A1?style=flat" alt="License"/>
  <img height="20" src="https://img.shields.io/badge/FLUTTER-3.44-02569B?style=flat&logo=flutter&logoColor=white" alt="Flutter"/>
  <img height="20" src="https://img.shields.io/badge/Android_iOS_Windows_macOS_Linux-000000?style=flat" alt="Platforms"/>
</p>
```

with:

```markdown
<p align="center">
  <img src="assets/icon.png" alt="PlayTorrioMov logo" width="160"/>
</p>
<p align="center">
  <h1 align="center">PlayTorrioMov</h1>
  <h3 align="center"><em>Movies, Series, Anime & Live TV — one app</em></h3>
</p>

<p align="center">
  A Flutter media app that pulls movies, series, anime and live TV into a
  single interface — from Stremio-compatible addons, torrent swarms, and the
  open web. Forked from
  <a href="https://github.com/MediaHub-Org/PlayTorrioMod">PlayTorrioMod</a>
  with Music and Books removed — better served by dedicated apps.
</p>

<p align="center">
  <a href="https://github.com/MediaHub-Org/PlayTorrioMov/releases"><img height="20" src="https://img.shields.io/github/v/release/MediaHub-Org/PlayTorrioMov?include_prereleases&style=flat&color=7C5CFF" alt="Latest release"/></a>
  <img height="20" src="https://img.shields.io/badge/LICENSE-GPL--3.0-4169A1?style=flat" alt="License"/>
  <img height="20" src="https://img.shields.io/badge/FLUTTER-3.44-02569B?style=flat&logo=flutter&logoColor=white" alt="Flutter"/>
  <img height="20" src="https://img.shields.io/badge/Android_iOS_Windows_macOS_Linux-000000?style=flat" alt="Platforms"/>
</p>
```

Replace the "Three hubs" section:

```markdown
## Three hubs

Navigation is organised by what you want to do, not by file format. Every hub
shares the same search, filters, favourites and playback surface.

| Hub | Sections |
|:--|:--|
| **Watch** | Movies · Series · Anime · Live TV · Library |
| **Listen** | Music · Radio · Podcasts · Library |
| **Read** | Audiobooks · Books · Comics · Manga · Library |

On phones the section switcher collapses to a dropdown; tablets and desktops
get the full chip bar. See [UI & Design](docs/ui-design.md).
```

with:

```markdown
## Sections

| Section | Content |
|:--|:--|
| **Movies & Series** | TMDB-catalog movies and series, one tap apart |
| **Anime** | Its own catalog and scraper |
| **Live TV** | IPTV channels |
| **Library** | Everything you've saved |

On phones the sections sit in the bottom tab bar; tablets and desktops get a
chip row under the top bar. See [UI & Design](docs/ui-design.md).
```

- [ ] **Step 3: Swap the product name in the remaining docs**

```powershell
Get-ChildItem -Path docs\README.md, docs\ROADMAP.md, docs\branching.md, docs\configuration.md | ForEach-Object {
  (Get-Content $_.FullName) -replace 'PlayTorrioMod', 'PlayTorrioMov' | Set-Content $_.FullName
}
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: rebrand README, drop PlayTorrioMod-specific fork-history docs"
```

---

### Task 10: Confirm no stray references to removed modules remain

**Files:** None modified — verification-only task.

**Interfaces:** None.

- [ ] **Step 1: Repo-wide grep for removed-module keywords**

```powershell
Select-String -Path lib\**\*.dart -Pattern "\bMusic\b|\bPodcast\b|\bAudiobook\b|\bManga\b|\bComics?\b|\bBooks?Hub\b|AppHub|audio_service|HubNavigator" -ErrorAction SilentlyContinue | Where-Object { $_.Path -notmatch "docs[\\/]" }
```

Expected: no hits. If something shows up, it's a reference this plan's earlier tasks missed — read the surrounding code, decide whether it's a stray import/comment (fix inline) or a deeper dependency this plan's design didn't account for (stop and report rather than guessing).

- [ ] **Step 2: Confirm the deleted packages are gone from the dependency tree**

```powershell
flutter pub deps | Select-String "audio_service|xml "
```

Expected: no output.

---

### Task 11: Final verification — analyze, test, manual launch

**Files:** None modified.

**Interfaces:** None.

- [ ] **Step 1: Full static analysis**

```powershell
flutter analyze
```

Expected: clean (matches or improves on Task 1's baseline — zero new errors, and the errors that existed only because of the fork-in-progress from Tasks 2–9 are now gone).

- [ ] **Step 2: Run the test suite**

```powershell
flutter test
```

Expected: all pass. (The two removed-module test files and the book-reader test were already deleted in Task 2 — this should not need any further test edits.)

- [ ] **Step 3: Manual launch on Windows**

```powershell
flutter run -d windows
```

Confirm, by hand: the app launches with the "PlayTorrioMov" window title, the four sections (Movies & Series, Anime, Live TV, Library) all open without error, the Movies & Series pill still switches between Movies and Series, Settings opens with no Manga/Audiobook/Music tiles, About shows only the one hub description, and there's no leftover hub-pill row anywhere in the mobile-width layout (resize the window narrow to check).

- [ ] **Step 4: Commit anything Step 1–3 caused you to fix, otherwise stop — no commit needed for a clean pass**

```bash
git add -A
git commit -m "fix: address flutter analyze/test findings from fork verification"
```

(Skip this commit entirely if nothing needed fixing.)
