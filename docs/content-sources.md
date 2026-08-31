# Content sources

<!-- Extracted from README.md so the README stays an overview. -->

## Manga Reader

<p align="center">
  <b>WeebCentral Integration</b> &nbsp;&middot;&nbsp; <b>Horizontal & Vertical Modes</b> &nbsp;&middot;&nbsp; <b>Pinch-to-Zoom</b> &nbsp;&middot;&nbsp; <b>Reading Progress</b> &nbsp;&middot;&nbsp; <b>Chapter Search</b> &nbsp;&middot;&nbsp; <b>Adult Content Toggle</b>
</p>

<p align="center">
  <em>A full-featured manga reading experience built on WeebCentral's web catalog. Browse, search, read, and track progress — all within the app, all persisted across sessions.</em>
</p>

### Discovery

The manga page offers two browsing modes:
- **Browse** — infinite-scroll grid of manga covers with genre tag filtering. Content loads in pages, with smooth loading indicators between fetches.
- **Search** — debounced text search across WeebCentral's catalog with paginated results.

A "Continue Reading" section at the top shows your reading history — the manga you've started, sorted by most recently read, with progress indicators on each card. This section persists via `SharedPreferences` and survives app restarts.

### Detail Page

Each manga has a detail page displaying:
- **Hero cover image** with gradient overlay transitioning to the metadata section
- **Metadata** — title, type (Manga/Manhwa/Manhua), status (Ongoing/Completed), year, author, tags
- **Synopsis** — full description parsed from WeebCentral's left sidebar layout
- **Chapter list** — paginated at 50 chapters per page, with page navigation controls
- **Chapter search** — filter chapters by number or name
- **Reading progress** — which chapter you last read, displayed with a visual indicator

### Reader

The reader page is the core manga experience. Images load from WeebCentral's CDN (`temp.compsci88.com`) with caching for offline-like performance:

| Feature | Detail |
|:--------|:-------|
| **Horizontal mode** | PageView with swipe navigation — one page at a time, full-screen |
| **Vertical mode** | Continuous scroll — all images in a column, natural reading flow |
| **Zoom** | Pinch-to-zoom with `InteractiveViewer`. Double-tap to reset. Min scale 1.0x, max 3.0x |
| **Chapter navigation** | Previous/next chapter buttons. Auto-advances to next chapter at end |
| **Progress saving** | Current page and chapter saved on navigation and periodically during reading |
| **Immersive UI** | Overlay auto-hides. Tap to reveal controls. Keyboard focus-aware |
| **Image pre-caching** | `CachedNetworkImage` pre-loads adjacent pages for smooth swiping |

### Progress Persistence

Reading progress is tracked with `ValueNotifier<int>` for reactive UI updates. Each manga's current chapter and page are stored in `SharedPreferences` via the `MangaService`. The history is capped to prevent bloat. The static cache on the manga discovery page preserves state across tab navigations — switching to Movies and back keeps your scroll position and loaded content.

<br/>

---

## Audiobooks

<p align="center">
  <b>9 Independent Sources</b> &nbsp;&middot;&nbsp; <b>Torrent & Direct Streaming</b> &nbsp;&middot;&nbsp; <b>Variable Speed</b> &nbsp;&middot;&nbsp; <b>Sleep Timer</b> &nbsp;&middot;&nbsp; <b>Progress Persistence</b> &nbsp;&middot;&nbsp; <b>Chapter Navigation</b>
</p>

<p align="center">
  <em>Nine audiobook sources searched in parallel, with results merged and relevance-ranked. Stream directly from WordPress-hosted audio files or torrent the full audiobook with selective chapter downloading. Every listening session is tracked and resumed exactly where you left off.</em>
</p>

### Source Aggregation

All nine sources are queried simultaneously with a 5-second timeout per source. Results are merged and sorted by relevance score:

| # | Source | Domain | Type |
|:-:|:-------|:-------|:-----|
| 1 | **AudiobookBay** | `audiobookbay.lu` | Torrent index — magnet links with file lists |
| 2 | **GoldenAudiobooks** | `goldenaudiobooks.com` | WordPress — direct audio URLs |
| 3 | **FullLengthAudiobooks** | `fulllengthaudiobooks.com` | WordPress — direct audio URLs |
| 4 | **HotAudiobooks** | `hotaudiobooks.com` | WordPress — direct audio URLs |
| 5 | **BookAudiobooks** | `bookaudiobooks.com` | WordPress — direct audio URLs |
| 6 | **Audiozaic** | `audiozaic.com` | WordPress — direct audio URLs |
| 7 | **AudioAZ** | `audioaz.com` | WordPress — direct audio URLs |
| 8 | **Audiobooks4Soul** | `audiobooks4soul.com` | WordPress — direct audio URLs |
| 9 | **Audionest** | `search.audionestapp.com` | Meilisearch API — Firebase anonymous auth |

### Discovery Page

The audiobooks page defaults to a "Harry Potter" search on first load — demonstrating the aggregation capabilities immediately. Features include:
- **Search** — debounced text search with relevance-scored results from all nine sources
- **"Continue Listening"** — horizontal carousel of in-progress audiobooks sorted by last listened timestamp
- **Results grid** — audiobook cards with cover art, title, source badge, and tap-to-detail navigation

### Detail & Chapter List

Each audiobook has:
- **Backdrop blur** cover image with ambient background glow
- **Source badge** — torrent (magnet icon) or stream (play icon)
- **Metadata** — title, author, source information
- **Chapter list** — all chapters with tap-to-play. Source-specific chapter extraction (each WordPress site has unique HTML structure; AudiobookBay returns torrent file lists).

### Player

The audiobook player handles two fundamentally different streaming modes:

**Direct Stream:**
- Standard HTTP audio streaming from WordPress sites
- Chapter-by-chapter playback with URL-based navigation
- No download required — plays immediately

**Torrent Stream:**
- Magnet link resolved through the torrent engine
- Selective file downloading — the engine identifies audio files (`.mp3`, `.m4b`, `.m4a`, `.ogg`, `.flac`) from the torrent file list
- Chapters map to individual torrent files via file index
- Sequential streaming with piece prioritization

**Player Features:**

| Feature | Detail |
|:--------|:-------|
| **Playback speed** | 1.0x, 1.25x, 1.5x, 1.75x, 2.0x |
| **Chapter navigation** | Previous/next buttons with label display |
| **Progress saving** | Position saved every 5 seconds to SharedPreferences |
| **Sleep timer** | Configurable auto-stop: 15min, 30min, 45min, 60min, or end of chapter |
| **Seek bar** | Draggable position slider with time labels |
| **Volume control** | Independent volume with mute toggle |
| **Visual** | Spinning disc animation during playback |
| **Transition** | Custom zoom+fade+slide route transition into and out of the player |

### Progress Persistence

Audiobook progress is stored as a JSON-encoded list in `SharedPreferences`, limited to 20 entries to prevent storage bloat. Each entry records: audiobook UUID, current chapter index, playback position in seconds, and timestamp of last listen. Entries are sorted by last listened — the most recent is always at the top of "Continue Listening."

<br/>

---

## Music Streaming

<p align="center">
  <b>Octave Streaming API</b> &nbsp;&middot;&nbsp; <b>Search & Browse</b> &nbsp;&middot;&nbsp; <b>Library Management</b> &nbsp;&middot;&nbsp; <b>Playlists</b> &nbsp;&middot;&nbsp; <b>Quality Switching</b> &nbsp;&middot;&nbsp; <b>Keyboard Shortcuts</b> &nbsp;&middot;&nbsp; <b>Queue System</b>
</p>

<p align="center">
  <em>A complete music streaming experience powered by the Octave API. Browse curated sections, search across tracks/artists/albums, build playlists, like tracks, and manage a personal library — all with a persistent mini-player and full-screen playback view.</em>
</p>

### Octave Integration

| Endpoint | Purpose |
|:---------|:--------|
| `api.octavestreaming.com/api/playback-token` | Fetch authenticated streaming token |
| `music.octavestreaming.com/api/search?q={query}` | Search tracks, artists, albums |
| `api.octavestreaming.com/audio/{quality}?track={id}&token={token}` | Direct audio stream (lossless/320/128) |
| `music.octavestreaming.com/api/artist/{id}` | Artist details, top tracks, albums, related |
| `music.octavestreaming.com/api/playlist/{id}` | Playlist details with track listing |

### Tabbed Interface

The music page uses four tabs:

| Tab | Content |
|:----|:--------|
| **Home** | Curated sections — trending tracks, new releases, featured artists, recommended playlists. Sections load progressively as API responses arrive. |
| **Search** | Debounced text search with results grouped by type: tracks, artists, albums, playlists. Tap any result to play or explore further. |
| **Browse** | Trending artists grid with cover images. Tap to view artist detail modal with top tracks, albums, and related artists. |
| **Library** | Personal collection: liked tracks list, user-created playlists with track counts, recently played history. |

### Player Controller

The `MusicPlayerController` singleton manages all playback state:

| Feature | Detail |
|:--------|:-------|
| **Playlist management** | Queue system — play now, play next, add to queue |
| **Quality switching** | Lossless, 320kbps, 128kbps — toggle mid-playback |
| **Play/pause/seek** | Standard transport controls |
| **Track navigation** | Next track (auto-advance), previous track (skip back if >4s into current track) |
| **Volume** | Independent volume control |
| **Shuffle** | Random queue order |
| **Repeat** | Off / Queue / Single track |
| **Like** | Heart toggle synced to library |

### Library Persistence

The `OctaveLibraryService` (also a singleton `ChangeNotifier`) persists liked tracks and custom playlists to `SharedPreferences` as JSON. Operations include: toggle like, create/delete playlist, add/remove track from playlist. The library survives app restarts and is reactive — any UI listening to the service updates automatically when tracks are liked or playlists are modified.

### Mini-Player & Full Player

A persistent mini-player bar sits at the bottom of the music page showing current track art, title, artist, and play/pause button. Tapping it expands to the full-screen player with:
- **Album art** with dominant color extraction for background ambiance
- **Track info** — title, artist, album
- **Seek bar** with elapsed/remaining time
- **Transport controls** — previous, play/pause, next, shuffle, repeat, like
- **Queue drawer** — slide-up panel showing upcoming tracks with drag-to-reorder
- **Lyrics drawer** — synced lyrics display (when available from Octave)
- **Quality indicator** — current streaming bitrate

### Keyboard Shortcuts

| Key | Action |
|:----|:-------|
| `Space` | Play / Pause |
| `J` | Seek backward 10s |
| `L` | Seek forward 10s |
| `M` | Mute / Unmute |
| `Q` | Toggle queue drawer |
| `F` | Toggle full-screen |
| `/` | Show shortcuts overlay |

<br/>
