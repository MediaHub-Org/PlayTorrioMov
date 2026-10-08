# Playback speed plan

**The problem.** On a slow connection, and on a normal one when a torrent has
many seeds, video plays slowly, most visibly on a TV. The ideal would be what
YouTube and the streaming services do: a high bitrate when the link allows it
and an automatic step down when it does not.

**Short answer.** Automatic adaptation of that kind needs the same video
encoded at several bitrates. This app plays whatever file a source hands it, so
for torrents and plain files there is nothing to step down to. What it can do is
(1) find out why a particular playback is slow, (2) choose a release the device
can actually sustain, (3) steer people to a path that is not limited by seeds
(debrid), and (4) switch to a lighter source when one stalls. True stream
adaptation is possible only for HLS sources, and is the smallest group.

Nothing below is built yet. This is the plan, with what is known, what is a
guess, and what has to be measured on a TV first.

## What the code does today

Read from `lib/`, not assumed.

| Area                | Today                                                                                                                                                                                                                  |
|:--------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Quality choice      | **A sort bias only.** `VideoQualityTier` (Good / Better / Best) orders the sources by closeness to 720p / 1080p / 4K. "There is no transcoding here, only a choice among whatever releases exist" (`video_quality_preference.dart`). |
| HLS                 | The player forces `hls-bitrate=max` (`player_settings.dart`), so a master playlist always opens at its highest variant. mpv picks the variant when the stream opens and does not move between them on its own.         |
| Bitrate knowledge   | `StreamBitrateResolver` reads `BANDWIDTH` off HLS master playlists and `StreamSource.bitrateKbps` reads a bitrate out of the title. Used for badges; nothing decides with it yet.                                       |
| Torrents            | Served by TorrServer (`torrserver_flutter`) over local HTTP. The start-up preload is shown in the loading logo; mpv gets a long network timeout and reconnect flags because the file still has gaps.                  |
| Buffering           | mpv demuxer cache from a preset: Minimal 50 MB / 5 s up to Maximum 600 MB / 60 s. Android defaults to **High resilience (300 MB / 30 s)**; the disk cache is on by default.                                            |
| Debrid              | Five providers are implemented (Real-Debrid, TorBox, AllDebrid, Premiumize, Debrid-Link) behind a "use debrid for streams" toggle. No code was found that marks a source as already cached on the provider.            |
| Switching sources   | The player can change source mid-playback (the sources panel); how well it carries the position over is worth checking before building on it.                                                                          |
| Diagnostics         | The player has a stats panel (host, speed, peers, completed, buffered, hash for torrents).                                                                                                                             |

## Step 0 — find out why it is slow (before building anything)

"Slow video, worse on the TV" has at least four different causes, and they need
different fixes. Guessing which one is how a week gets spent on the wrong one.

| Hypothesis                                                                                                                  | How to tell                                                                                              |
|:----------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------------------------------------------------------------|
| **The release's bitrate is above what the TV's link sustains.** A 4K remux is 60-80 Mbps; a 1080p web release is 8-15. TV Wi-Fi is often weak or on 2.4 GHz. | Download speed in the stats panel is below the file's bitrate; the buffer drains and refills.            |
| **The TV cannot decode it.** HEVC 10-bit or AV1 without hardware decoding drops frames with a full buffer.                  | Buffer stays full, picture stutters. Needs the hardware-decoder state and dropped frames in the stats.    |
| **Seeds are not speed.** Many seeds can still be throttled, far away or slow to connect; a TV box has a weak CPU for many peer connections. | Peers and speed in the stats vs the seed count on the card.                                              |
| **The cache is the bottleneck.** A 300-600 MB demuxer cache or the disk cache can strain a TV box with little RAM or slow storage. | Compare the same title with a Minimal preset and the disk cache off.                                     |

**Work item 0.1 — a playback diagnosis in the stats panel.** Add what is missing
to the existing panel: the file's bitrate next to the measured download rate,
the decoder in use (hardware or software), dropped frames, cache fill, and the
number of stalls so far. A single line in plain words at the bottom ("This
source needs about 18 Mbps; your link is delivering about 9") is the part that
makes the number useful to someone who is not debugging.

**Work item 0.2 — one TV session.** With 0.1 in a dev build, play one slow title
on the TV and send the panel's numbers. That decides which of the rows above is
the real cause here, and with it which steps below matter. Steps 1 to 3 do not
depend on the answer and can start first.

## Step 1 — choose a release the device can carry (low effort, works for all source types)

The cheapest fix is to stop offering the heaviest release first.

- On a TV, default the quality tier to **Better (1080p)**, not Best. A 4K
  release is only the right first pick when the link is known to carry it.
- Use the bitrate the app already extracts (title, HLS manifest) in the ranking:
  among releases of the same resolution, prefer the one with the lower bitrate,
  and never put a release above the measured throughput at the top.
- After the first playback the app knows the link's real speed (Step 0.1 already
  measures it). Remember it per network, and let it bound the ranking:
  "your link has delivered about 12 Mbps".

Risk: ranking by bitrate can hide the best-looking release from someone whose
link is fine. The sort stays a sort; nothing is hidden.

## Step 2 — debrid is the real fix for torrents (medium effort, user pays)

For a cached torrent a debrid provider serves the file over HTTP from its own
servers at line speed. Seeds, peers, connection counts and the TV's CPU stop
mattering; the stream behaves like any other file download. For a TV on a
normal connection this is the single largest improvement available, and the
five providers are already integrated.

What is missing is making it easy and visible:

1. **A cached badge on sources** (instant availability per provider). **Verify
   each provider's current API before building**: the availability endpoints
   differ per provider, and at least one major provider has changed or removed
   its own in the past. This must be checked against the provider's current
   documentation, not remembered.
2. **Prefer cached sources** at the top of the list when debrid is on.
3. **First-run guidance**: say plainly that torrents depend on seeds and a
   debrid account avoids that, without pushing a purchase. A subscription is
   the user's decision, not the app's.

Risk: it is a paid service and a per-provider API. The app should work well
without it; this is the recommended path for people who want speed.

## Step 3 — switch to a lighter source when one stalls (medium effort)

Adaptation at the granularity the app actually has: the source.

- Watch the player's buffering state and the measured throughput. When the
  buffer runs dry repeatedly and sustained throughput is below the file's
  bitrate, say so in the panel and **offer** the next lighter source from the
  list already loaded ("Switch to 720p, 3.2 Mbps"), carrying the position over.
- Offer, don't force, the first time; an opt-in "switch automatically" setting
  can follow once it has been seen to behave.
- It works for torrents, files and HLS alike, because it only needs the source
  list and the position.

Prerequisite: confirm a mid-playback source switch keeps the position and does
not drop the subtitle selection. That decides whether this is a small change or
a medium one.

Risk: a switch costs a reload and the new source may be just as slow. The
offer should only appear when a lighter source exists and is not marked dead.

## Step 4 — tune the pipeline (small, only with Step 0 data)

Candidates, each a measured experiment and none a default change on a guess:

- A TV-specific buffer preset: a lower byte ceiling (memory) with a longer time
  window, so a box with little RAM is not asked to hold 300-600 MB.
- Disk cache off on devices with slow storage.
- mpv's `cache-pause` behavior: how long it waits to resume after a stall.
- TorrServer's own settings (preload size, read-ahead, connection limit),
  exposed as one "Torrent performance" choice rather than raw numbers.
- On a TV with a weak link, a one-line hint in the stats ("5 GHz Wi-Fi or an
  Ethernet cable usually fixes this"), shown only when the measured speed is
  low.

## Step 5 — real stream adaptation, for HLS only (higher effort, narrow benefit)

For a source that is an HLS master playlist the variants exist, so a YouTube-like
step down is possible, but mpv will not do it by itself: it chooses at open
(`hls-bitrate`). The app would run its own small loop:

1. Parse the master playlist (the resolver already fetches it).
2. Start at a variant the measured throughput supports, not always the maximum.
3. On sustained stalls, reopen the same URL at the next lower `hls-bitrate`
   from the current position (a short hitch, not a seamless switch).
4. Step back up after a long clean stretch.

It is worth building only if HLS is a large share of what people actually play.
Torrents, MP4 and MKV links are not HLS. Check the share first (Step 0 data
from a few weeks of dev builds is enough); if it is small, skip this.

## Step 6 — what not to build

| Idea                                           | Why not                                                                                                                                                                                                                                  |
|:-----------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Transcoding to a lower bitrate on the fly       | Needs a machine with a hardware encoder in the path. The app is a client with no server; a TV cannot transcode a 4K remux. A "bring your own Jellyfin/Plex server" feature would be a different product decision, not a fix.            |
| Seamless ABR for torrents and plain files       | There is one encode. There is nothing to switch between. Step 3 (switch source) is the honest equivalent.                                                                                                                                |
| Raising the cache to the maximum by default     | Does nothing for a link slower than the bitrate: a bigger buffer only delays the stall. It costs memory on a TV, where memory is the scarce thing.                                                                                          |

## Order and what each step needs

| Step | What                                       | Effort | Needs the TV data first? | Helps                        |
|:-----|:-------------------------------------------|:-------|:-------------------------|:-----------------------------|
| 0    | Diagnosis in the stats panel, one TV run   | Small  | It produces it           | Tells us which step matters  |
| 1    | Release choice by device and measured link | Small  | No                       | Everything                   |
| 2    | Debrid: cached badge, prefer, guidance     | Medium | No                       | Torrents, the big one        |
| 3    | Offer a lighter source after stalls        | Medium | No                       | Everything                   |
| 4    | Pipeline tuning                            | Small  | **Yes**                  | Depends on the cause         |
| 5    | HLS step-down loop                         | Larger | Yes (HLS share)          | HLS sources only             |

Recommended start: **0.1, then 1 and 2 together**, with 0.2 on a TV as soon as
the dev build exists. Step 3 after that. Steps 4 and 5 wait for the numbers.

## What cannot be settled from the code

Everything about actual speed. The causes in Step 0 are hypotheses; this
document was written without a TV, a slow link or a debrid account, and none of
the steps has been tried on a device. The plan is ordered so that the first
thing built is what turns a guess into a measurement.
