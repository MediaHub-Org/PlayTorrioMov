# Streaming

<!-- Extracted from README.md so the README stays an overview. -->

## Movie & TV Streaming

<p align="center">
  <b>Stremio Addon Catalogs</b> &nbsp;&middot;&nbsp; <b>Genre Browsing</b> &nbsp;&middot;&nbsp; <b>Infinite Scroll</b> &nbsp;&middot;&nbsp; <b>Season/Episode Navigation</b> &nbsp;&middot;&nbsp; <b>9 VOD Scrapers</b> &nbsp;&middot;&nbsp; <b>Torrent Streaming</b> &nbsp;&middot;&nbsp; <b>"More Like This"</b>
</p>

<p align="center">
  <em>The movie and TV pipeline is the heart of PlayTorrio. Content discovery flows from community addon catalogs through metadata enrichment to multi-source stream aggregation — all happening concurrently so the user sees results as soon as they arrive.</em>
</p>

### Discovery Pipeline

```
Addon Catalog >> Metadata Enrichment >> Stream Aggregation >> Playback
     |                  |                       |
  Cinemeta          BestSimilar           9 Scrapers
  Community         Recommendations       Torrent DHT
  Custom URLs       Cast + Genres         Subtitle Fetch
```

### Home Screen

The landing page features a hero carousel showcasing featured titles pulled from all installed addons, with intelligent deduplication to ensure visual diversity. Below the hero, horizontally scrollable sections stream in progressively as each addon returns its catalogs. Every section is labeled with catalog name, content type, and source addon. Pull-to-refresh reloads everything. A glass-bottom navigation dock provides one-tap access to Manga, Audiobooks, and Music sections.

### Detail Pages

Tapping any poster navigates to a full detail page with:
- **Backdrop image** with gradient overlay for readability
- **Metadata header** — title, year, IMDb rating, runtime, director, cast
- **Expandable synopsis** with animated height transition
- **Genre tags** rendered as tappable chips
- **Cast row** with horizontal scrolling
- **Season selector** with episode grid and quick-scroll buttons
- **"More Like This"** section powered by the BestSimilar recommendation engine
- **Links section** for external trailers, IMDb pages, and related content

### Stream Selection

The Watch Screen queries all available sources in parallel — nine built-in VOD scrapers plus every installed Stremio addon. Results stream in progressively, batched at 60ms intervals to avoid UI jank. Each stream source displays:
- **Quality badge** — 4K, 1080p, 720p, or 480p detected from title metadata
- **Codec tag** — HEVC, H.264, AV1
- **HDR indicator** — Dolby Vision, HDR10+, HDR
- **File size** — parsed and formatted from torrent metadata
- **Source label** — which scraper or addon provided the stream
- **Type indicator** — direct VOD URL or torrent magnet link

Streams are sorted by quality rank (4K > 1080p > 720p > 480p) with same-quality ties broken alphabetically. An addon filter dropdown lets users focus on specific sources. Desktop and mobile layouts adapt responsively. Tapping a stream navigates to the full-screen player via a cinematic slide transition.

### Video Player

The player screen is immersive and landscape-oriented. Built on `video_player` with `fvp` (FFmpeg Video Player) for broad codec support. Features include:
- **Auto-hiding controls** — tap to reveal, auto-dismiss after inactivity
- **Subtitle overlay** — load external SRT/VTT with adjustable delay and scale
- **Playback speed** — variable rate control
- **Video fit toggle** — cover, contain, fill modes
- **Volume control** with mute toggle
- **Torrent health display** — active peers, download speed, cache percentage

For torrent streams, the player shows real-time libtorrent statistics so users can monitor swarm health during playback.

<br/>

---

## VOD Scrapers

<p align="center">
  <b>9 Scrapers</b> &nbsp;&middot;&nbsp; <b>Plugin Architecture</b> &nbsp;&middot;&nbsp; <b>Concurrent Execution</b> &nbsp;&middot;&nbsp; <b>Automatic Deduplication</b> &nbsp;&middot;&nbsp; <b>Dual Providers</b>
</p>

<p align="center">
  <em>Each scraper is an independent module that implements a common interface. The ScraperManager runs all nine concurrently, collects results, and deduplicates by info-hash. Adding a new source is a matter of extending one abstract class and registering it.</em>
</p>

### Scraper Registry

<table>
<tr><th>#</th><th>Scraper</th><th>Type</th><th>Provider</th><th>Description</th></tr>
<tr><td>1</td><td><b>FlyStream</b></td><td>Direct VOD</td><td>PlayTorrioHTTP</td><td>High-speed HLS streams with quality/codec metadata. Simple API with random viewer ID generation.</td></tr>
<tr><td>2</td><td><b>Videasy</b></td><td>Direct VOD</td><td>PlayTorrioHTTP</td><td>Multi-CDN HLS extractor. Uses RC4-style sbox decryption to unlock API responses. Queries five different providers (Yoru, Neon, Breach, Killjoy, Omen).</td></tr>
<tr><td>3</td><td><b>VidSrc</b></td><td>Direct VOD</td><td>PlayTorrioHTTP</td><td>Dual-strategy: queries API first, falls back to scraping embed page for m3u8 URLs. TMDB ID resolution for accurate matching.</td></tr>
<tr><td>4</td><td><b>MultiEmbed</b></td><td>Direct VOD</td><td>PlayTorrioHTTP</td><td>2embed.cc multi-server extractor. Parses server dropdown, follows XPS chain (xpass.top >> playlist.json >> m3u8 URLs).</td></tr>
<tr><td>5</td><td><b>VidCore</b></td><td>Direct VOD</td><td>PlayTorrioHTTP</td><td>Multi-server VOD extractor with skip-based pagination to discover all available servers. Handles nested source structures.</td></tr>
<tr><td>6</td><td><b>4KHDHub</b></td><td>Direct VOD</td><td>PlayTorrioHTTP</td><td>4K-focused direct stream source. Resolves obfuscated redirect chains (base64 + ROT13 cipher). Validates stream health with HEAD request before returning.</td></tr>
<tr><td>7</td><td><b>XDownloader</b></td><td>Direct VOD</td><td>PlayTorrioHTTP</td><td>Films365/All Movies Downloader API. Bearer token authentication. Handles movies (direct download) and TV (season >> episode navigation).</td></tr>
<tr><td>8</td><td><b>Knaben</b></td><td>Torrent</td><td>PlayTorrio</td><td>knaben.org meta-search. HTML table parsing with exact title matching. Uses ParseTorrentTitle for season/episode filtering.</td></tr>
<tr><td>9</td><td><b>Torrent Galaxy</b></td><td>Torrent</td><td>PlayTorrio</td><td>torrentgalaxy.info search. Two-phase: list page search then concurrent detail page fetching for magnet links.</td></tr>
</table>

### Scraper Architecture

```dart
abstract class StreamScraper {
  String get name;
  Future<List<StreamSource>> scrape({
    required String type,        // 'movie' or 'series'
    required String title,       // Exact title for matching
    required int? year,          // Release year for disambiguation
    required int? season,        // TV season number
    required int? episode,       // TV episode number
    required String? imdbId,     // IMDb ID for TMDB lookup
  });
}
```

Each scraper implements this interface. The `ScraperManager` singleton maintains a registry, runs all scrapers via `Future.wait`, and deduplicates results by info-hash. A TMDB helper utility resolves IMDb IDs to TMDB IDs for scrapers that need them. Results are cached with LRU eviction. Failed scrapers are silently skipped — one broken source never blocks the others.

**Providers:**
- **PlayTorrioHTTP** — Direct VOD scrapers that return HTTP/HTTPS stream URLs (m3u8, mp4)
- **PlayTorrio** — Torrent scrapers that return magnet links and info-hashes, which feed into the torrent streaming engine

<br/>

---

## Torrent Streaming Engine

<p align="center">
  <b>Native libtorrent</b> &nbsp;&middot;&nbsp; <b>Selective File Download</b> &nbsp;&middot;&nbsp; <b>Intelligent File Selection</b> &nbsp;&middot;&nbsp; <b>Real-Time Stats</b> &nbsp;&middot;&nbsp; <b>HTTP Stream Output</b>
</p>

<p align="center">
  <em>PlayTorrio embeds a full BitTorrent client via <code>libtorrent_flutter</code> — native C++ libtorrent bindings compiled for each platform. Torrents are streamed sequentially: the engine prioritizes pieces needed for immediate playback while continuing to download the rest in the background.</em>
</p>

### Engine Configuration

| Parameter | Value | Description |
|:----------|:------|:------------|
| Max connections | 200 | Simultaneous peer connections |
| Cache size | Dynamic | Memory-mapped, OS-managed |
| Listen ports | OS-assigned | Random available ports |
| DHT | Enabled | Mainline DHT for peer discovery |
| LSD | Enabled | Local Service Discovery |
| uTP | Enabled | Micro Transport Protocol |

### File Selection Algorithm

When a multi-file torrent is loaded (common for TV season packs), the engine applies a smart selection strategy:

1. **Parse all filenames** using the `ParseTorrentTitle` utility — extract season, episode, resolution, codec, and audio metadata from raw torrent filenames
2. **Match by season/episode** if the user requested a specific episode — filters to files whose parsed metadata matches the target season and episode numbers
3. **Filter by media extension** — only considers files with video extensions: `.mp4`, `.mkv`, `.avi`, `.webm`, `.mov`, `.wmv`, `.flv`, `.ts`, `.m2ts`
4. **Fallback to largest file** — if no episode match is found, selects the largest media file by byte size (typically the full movie)
5. **Return file index** — passes the selected file's index to libtorrent for prioritized piece download

### Real-Time Statistics

The engine exposes a `statsStream` that emits `TorrentStats` updates during playback:

| Stat | Unit | Description |
|:-----|:-----|:------------|
| Download speed | Mbps/Kbps | Current peer download rate |
| Upload speed | Mbps/Kbps | Current upload contribution |
| Active peers | Count | Connected and transferring peers |
| Total peers | Count | All known peers in swarm |
| Cache progress | Percentage | Pieces buffered vs total |
| Total progress | Bytes | Downloaded vs total torrent size |
| Connection state | Enum | stopped, starting, ready, error |

### Engine Lifecycle

```
initialize() >> start() >> streamTorrent(magnet) >> [playback] >> cleanup()
                  |              |                        |
            Configures       Adds magnet,           Removes torrent,
            libtorrent       waits metadata,        frees resources
            settings         selects file,
                             starts HTTP stream
```

The engine is a singleton. Multiple torrents can be active simultaneously — each keyed by its info-hash. Disposed torrent IDs are tracked to prevent double-dispose crashes. The engine properly shuts down on app termination.

<br/>

---

## Stremio Addon System

<p align="center">
  <b>Community Catalogs</b> &nbsp;&middot;&nbsp; <b>Metadata Enrichment</b> &nbsp;&middot;&nbsp; <b>Concurrent Search</b> &nbsp;&middot;&nbsp; <b>Relevance Scoring</b> &nbsp;&middot;&nbsp; <b>Progressive Loading</b>
</p>

<p align="center">
  <em>PlayTorrio is a fully functional Stremio client. It speaks the Stremio addon protocol natively — fetching manifests, browsing catalogs, searching content, and loading metadata from any community addon URL. The addon manager is the central orchestrator for all movie and TV content discovery.</em>
</p>

### Addon Manager (Singleton)

The `AddonManager` is the first service initialized at startup and the backbone of content discovery:

| Operation | Description |
|:----------|:------------|
| `initialize()` | Loads installed addons from SharedPreferences. Auto-installs Cinemeta if no addons configured. |
| `addAddon(url)` | Fetches manifest from URL, validates it, deduplicates by ID, saves to persistent storage. |
| `removeAddon(id)` | Removes addon and clears associated caches. |
| `toggleAddon(id, enabled)` | Enables/disables without uninstalling — filtered at query time. |
| `fetchAllHomeSections()` | Aggregates all catalogs from all enabled addons into `MovieSection` objects. Returns as a stream — sections render progressively as each addon responds. |
| `searchAll(query)` | Searches across all enabled addons concurrently. Results are relevance-scored and sorted before display. |
| `fetchByGenre(genre)` | Filters catalogs by genre tag across all enabled addons. |

### Content Flow

```
User installs addon URL
        |
        v
AddonManager fetches /manifest.json
        |
        v
Parses AddonManifest (id, name, version, resources, catalogs, types)
        |
        v
Stores InstalledAddon (baseUrl + manifest + enabled flag)
        |
        v
On home screen load: AddonManager.fetchAllHomeSections()
        |
        v
For each addon catalog: MetadataService.fetchCatalog()
        |
        v
HTTP GET {baseUrl}/catalog/{type}/{catalogId}.json
        |
        v
Parse response into List<Movie> with poster, year, type metadata
        |
        v
Wrap in MovieSection (title, subtitle, contentType, addon source)
        |
        v
Stream to UI — each section renders as it arrives
```

### Search Architecture

Searches execute concurrently across all enabled addons. Each addon's results are scored by the `RelevanceScorer` using exact-match-first ranking:

```
Query: "Breaking Bad"
        |
        v
Addon 1 search >> [{title: "Breaking Bad", score: 10000}, ...]
Addon 2 search >> [{title: "Better Call Saul", score: 5000}, ...]
Addon 3 search >> [{title: "Breaking Bad S05", score: 10000}, ...]
        |
        v
Merge + Sort by score descending
        |
        v
Display sectioned by addon source
```

The relevance scorer strips leading articles ("the", "a", "an"), normalizes to lowercase alphanumeric, and applies tiered bonuses: exact match (10,000), substring match (5,000), prefix match (3,000). Multi-word queries are capped if not all tokens match.

### Built-in Defaults

The Cinemeta addon is pre-configured and installed automatically on first launch. It provides the baseline movie and series catalog. Users can add any Stremio-compatible community addon — Torrentio, Orion, KnightCrawler, self-hosted servers, or private instances — by pasting the manifest URL in Settings.

<br/>

---

## Subtitles

<p align="center">
  <b>Subdl Provider</b> &nbsp;&middot;&nbsp; <b>Multi-Language</b> &nbsp;&middot;&nbsp; <b>TV Season/Episode Matching</b> &nbsp;&middot;&nbsp; <b>ZIP Extraction</b> &nbsp;&middot;&nbsp; <b>SRT/VTT Parsing</b> &nbsp;&middot;&nbsp; <b>Pluggable Providers</b>
</p>

<p align="center">
  <em>Subtitles are fetched on-demand when entering the video player. The subtitle service queries all registered providers concurrently, groups results by language, and downloads/extracts the selected subtitle file to a local temp directory for the video player to render.</em>
</p>

### Subtitle Architecture

```
Player Screen opens
        |
        v
SubtitleService.fetchAllSubtitles(movieName, imdbId?, season?, episode?)
        |
        v
All providers queried concurrently
        |
        v
Results grouped by language >> List<SubtitleLanguageGroup>
        |
        v
User selects variant >> SubtitleService.downloadSubtitle(variant)
        |
        v
SubtitleExtractor downloads ZIP >> extracts SRT/VTT >> returns local path
        |
        v
Player loads subtitle file with delay/scale adjustment
```

### Subdl Provider

The Subdl provider searches for subtitles by movie name and optionally filters by IMDb ID for precision. For TV shows, it matches season and episode numbers against Subdl's structured metadata. Downloaded subtitles arrive as ZIP archives and are extracted to a temporary directory. Both SRT and VTT formats are supported.

### Provider Interface

```dart
abstract class SubtitleProvider {
  Future<List<SubtitleVariant>> search({
    required String movieName,
    String? imdbId,
    int? season,
    int? episode,
  });
  
  Future<String> download(SubtitleVariant variant);
}
```

New subtitle providers can be added by implementing this interface and registering with the `SubtitleService`. The service handles concurrent queries, language grouping, and deduplication automatically.

### Player Integration

In the video player, users can:
- **Select subtitle language** from the grouped list of available subtitles
- **Adjust subtitle delay** — shift timing forward or backward in 100ms increments
- **Adjust subtitle scale** — larger or smaller text rendering
- **Toggle subtitles** on/off during playback

Subtitles render via the native video player's text track support with the selected delay and scale applied.

<br/>
