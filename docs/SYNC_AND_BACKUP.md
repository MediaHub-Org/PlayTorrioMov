# Sync, metadata sources, and backup

Two separate questions keep getting asked together, so this keeps them
separate on purpose: **where does the app's catalog/episode data come from**
(Cinemeta, TMDB, AniList, AniDB), and **where does a viewer's own data go**
(watch history to Trakt/Simkl, a backup of the app's local state to
somewhere else). Trakt and Simkl answer the second question, never the
first — see [Trakt/Simkl are not metadata sources](#traktsimkl-are-not-metadata-sources)
below for why that distinction matters to the "is Trakt VIP worth it"
question this was written to answer.

---

## Metadata sources today

| Source | What it's for | Gives | Costs |
|---|---|---|---|
| **Cinemeta** (`v3-cinemeta.strem.io`) | Default catalog/meta addon | Movie & series catalogs, basic meta, episode lists | Free, no key |
| **TMDB** | Richer movie/series detail | Posters, backdrops, cast, episode stills/overviews, "where to watch" | Free API key (`TMDB_API_KEY` in `.env`) |
| **AniList** | Anime catalog, detail pages, recommendations/relations, (new) per-episode art/title via `streamingEpisodes` | Rich anime metadata; sparse and sometimes mis-numbered per-episode art (see below) | Free, no key, public GraphQL endpoint |
| **AniDB** (via an extractor, not a public API client) | Anime episode *numbering/titles* specifically | The episode count and title the app treats as ground truth for "how many episodes does this season have" | Free, scraped |

`AnimeMedia.episodeInfo` (added this session) is the one place these last two
disagree in a way worth knowing about: AniDB's episode count is what the
rail actually uses (`_computedTotalEpisodes` in `anime_details_page.dart`
prefers it over AniList's own `episodes` field, which is frequently null for
long-running or still-airing shows), while AniList's `streamingEpisodes` is
where the per-card art and title come from. The two numbering schemes don't
always agree — see `lib/models/anime/anime_media.dart`'s
`_episodeNumberOffset` doc comment and `test/models/anime_streaming_episode_test.dart`
for the real cases (My Hero Academia, Solo Leveling, One Piece) this was
built and corrected against.

## Trakt/Simkl are not metadata sources

Trakt and Simkl are **watch-history and scrobbling services** — they record
what you watched and when, show a calendar of upcoming episodes, and (their
actual product) let you see that history on trakt.tv/simkl.com and sync it
across devices and apps. Neither hosts its own posters or episode stills:
both tell you the TMDB/TVDB id for a title and expect *you* to fetch images
from TMDB yourself, which is exactly what this app already does via its own
TMDB integration.

**So: paying for Trakt VIP does not unlock better movie/series/anime data.**
TMDB (free) remains the richer source for posters, overviews and episode
stills; Cinemeta (free) remains the bootstrap catalog; AniList/AniDB (free)
remain the anime-specific sources. What Trakt VIP actually unlocks, for the
one question that matters here, is narrower and specific:

- **Registering a new Trakt OAuth API application.** Trakt closed this to
  non-VIP accounts at some point after this app's Trakt integration was
  built; VIP is a subscription held by *whoever registers the app*
  (this project's maintainer), not by each person who signs in through it.
  This is confirmed via Trakt's own community forums, not a bug on this
  app's end.
- The ordinary Trakt VIP perks (ad-free trakt.tv, unlimited custom lists,
  earlier access to new trakt.tv features) — irrelevant to this app, which
  only talks to the API.

Trakt's own anime coverage is also notably weaker than AniList/AniDB's: it
inherits TVDB/TMDB's anime entries, which have exactly the
split-cour/continuation-numbering inconsistencies this session's AniList
fix had to work around — Trakt does not solve that problem, it has it too.

### Current state of each

- **Simkl**: fully wired (`lib/pages/settings/sync_settings_page.dart`'s
  `_SimklSyncCard`, backed by `lib/services/simkl/simkl_service.dart`). Works
  out of the box once a client ID is set (`SIMKL_CLIENT_ID` in `.env`) —
  registering one is free and takes about a minute at
  simkl.com/settings/developer. The in-app "unavailable" message already
  walks a user through this.
- **Trakt**: equally fully wired (`_TraktSyncCard`, `TraktService`,
  `TraktCalendarService`, `TraktContinueWatchingService` — the device-code
  OAuth pairing flow, sync-now, logout, calendar and continue-watching
  enrichment are all implemented and already called from the UI). The
  **only** thing missing is a working `TRAKT_CLIENT_ID`/`TRAKT_CLIENT_SECRET`
  in `.env`. Until one exists, `sync_settings_page.dart` shows
  `unavailableNote` explaining the VIP requirement instead of a dead button.
  **To turn it on**: whoever holds (or buys) a Trakt VIP subscription
  registers an application at trakt.tv/oauth/applications (redirect URI can
  be anything for the device-code flow this app uses) and hands over the
  Client ID and Client Secret to go in `.env`. There is no code left to
  write for this — it is a credentials problem, not a feature gap.
- Both cards can be connected at once; the app does not force a choice
  between them. Running both means scrobbling to two services for every
  watch, which is harmless but redundant if you only read history from one.

---

## Backup: today, and the vendor question

### What exists today

`lib/services/backup/backup_service.dart` + `cloud_backup_settings.dart`:

- **Local export/import**: a JSON envelope written to a file the user
  picks, containing the app's own state (library, continue watching,
  settings — not account passwords; Trakt/Simkl tokens and the WebDAV
  password live in `SecureValueStore`, the platform keychain/credential
  store, not in the exported file).
- **WebDAV cloud backup**: the user points the app at *their own* WebDAV
  endpoint (Nextcloud, ownCloud, a self-hosted WebDAV server, or any paid
  host that speaks WebDAV) with a URL, username and password. The app PUTs
  and GETs the same JSON envelope there with plain HTTP Basic Auth.
- **Dropbox backup** (`dropbox_backup_service.dart`): PKCE OAuth against a
  "public client" app (App Key only, no secret), with the code Dropbox
  shows pasted back in -- the same shape as Trakt's device code. Uploads
  and downloads the same envelope. Needs a `DROPBOX_APP_KEY` (free, from
  the Dropbox App Console) this build does not carry yet.
- **Google Drive backup** (`google_drive_backup_service.dart`): OAuth
  against a "Desktop" client with a loopback redirect (no redirect URI to
  pre-register, and no pasted code -- Google retired that flow), narrow
  `drive.file` scope, same envelope under the same name. Needs a
  `GOOGLE_DRIVE_CLIENT_ID` (free, from a Google Cloud project) this build
  does not carry yet.
- **Auto-backup** (`auto_backup_service.dart`): on by default once a
  destination is connected, backing up at app open when a day/week/month
  (your choice) has passed since the last one. There is no background-task
  runner in this app, so "at app open" is what "automatic" means --
  Dropbox first, then Google Drive, then WebDAV.

The WebDAV choice was deliberate (see the comment in
`cloud_backup_settings.dart`): "no vendor lock-in, no request-signing
dependency to add." Plain HTTP PUT/GET with Basic Auth has no OAuth app to
register, no API quota, no vendor SDK, and works with any WebDAV-speaking
host the user already has.

### Why Dropbox/Google Drive/Mega don't fit that model

None of the three requested providers speaks WebDAV for a consumer
account, so this is not an extension of the existing path — it is three
separate integrations, each with its own cost:

| Provider | Auth | Real cost of adding it |
|---|---|---|
| **Dropbox** | OAuth2, PKCE — no client secret needed for an installed/public app | Built (`dropbox_backup_service.dart` + the Backup settings card): PKCE flow with the code pasted back in, plain REST upload/download. Still needs a `DROPBOX_APP_KEY` — registering one is free, at dropbox.com/developers/apps. |
| **Google Drive** | OAuth2 via a Google Cloud project | Built (`google_drive_backup_service.dart` + the Backup settings card): a "Desktop" client, loopback redirect (no URI to pre-register, any port), PKCE, and the narrow `drive.file` scope — the app sees only files it created itself, never the whole Drive. Still needs a `GOOGLE_DRIVE_CLIENT_ID` — free, from a Google Cloud project with an OAuth consent screen. Two Google-side gotchas, both setup rather than code: consent screens left in test mode expire their grants after 7 days, so publish it to Production; and until Google verifies the app, sign-in shows an "unverified app" warning the user taps through. |
| **Mega** | Proprietary — no REST/OAuth; email+password login, client-side key derivation (RSA/AES) done the way Mega's own SDK does it | No official Dart SDK; the community packages that exist are less mature than Dropbox's or Google's official ones. The largest and least certain lift of the three, and the one most likely to need rework if Mega changes anything server-side. |

None of this is a reason not to do it — it's the reason to pick one (or an
order) rather than build all three at once, and to decide up front whether
"auto-backup" means a timer while the app is open (no background-service
infrastructure exists today to do it while closed) or something else.

### Open, waiting on a decision

One provider left: Mega (proprietary login, client-side key derivation, no
mature Dart SDK -- the largest and least certain lift, see the table
above). Dropbox and Google Drive are built and only need their app
credentials; "auto" is settled as "at app open" (`auto_backup_service.dart`).
The remaining question is the credential model already put to the user:
a maintainer-registered app shipped to everyone (the TMDB/Simkl "it just
works" model) or a user-registered one (the Trakt "bring your own app"
model) per provider.

---

## Where this lives in the code

- `lib/services/trakt/`, `lib/services/simkl/` — the two sync services,
  structurally identical (device-code/PIN pairing, calendar, continue
  watching, item transformers).
- `lib/pages/settings/sync_settings_page.dart` — both cards, the shared
  `_SyncCardChrome`, and the `unavailableNote` pattern for "built but needs a
  credential this build doesn't have."
- `lib/services/backup/` — local export/import and WebDAV cloud backup.
- `lib/models/anime/anime_media.dart` — `AnimeStreamingEpisode`,
  `episodeInfo`, the offset/coverage logic that reconciles AniList's episode
  numbering with AniDB's.
- `lib/services/metadata/metadata_service.dart` — the generic Stremio-addon
  client Cinemeta (and any other addon) goes through.
