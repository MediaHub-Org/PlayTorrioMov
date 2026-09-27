# Roadmap — PlayTorrioMov

**What is left to do.** Shipped work is in [CHANGELOG.md](../CHANGELOG.md),
the release process is in [RELEASES.md](RELEASES.md), and item numbers
(`#15`–`#74`) are indexed at the end of the changelog.

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-27**, on `v1.8.11+44`.

---

## Pending

Two kinds of work are left, and they need different things from you.

**Actionable now, no hardware** — #68 and #69. Neither is a research problem;
the methods live in `docs/CONVENTIONS.md` and the tests hold the invariants.
What is left of both is now the part a test cannot hold, which is worth being
precise about:

| Held by a test | What that leaves |
|:--|:--|
| `no_hardcoded_text_test` — no `Text()` holds an English sentence | Strings built from data, which stay English on purpose |
| `rtl_directional_padding_test` — no padding names a physical edge | ~87 `Alignment` constants and icon direction, which need judgment per site |
| `icon_button_tooltip_test` — every icon-only *button* carries a label | Icon-only controls that are not buttons: ~24 candidates, and the count is unreliable |
| `text_scale_overflow_test` — 19 widgets survive 3x on a 360px view | ~46 files with a fixed `height:` that nothing has probed |

An invariant with a test behind it does not need revisiting, so the four
right-hand cells are the work. Each of them needs a judgment a test cannot
make, which is why none of them is behind one.

**Needs a device** — the torrent-cast question, the pill rail, a
dub-default file, and a forced track. Nothing here can be advanced by reading
or writing code; each is one test away from an answer. Cast issues go the
same way: use it, and report what breaks.

### Device checks

**"ORIGINAL on a dub-default file (#76).** The badge marks whichever track the
file opens with, because neither media_kit nor mpv exposes a default marker.
Check it on a multi-audio file that defaults to a dub.

**#74's pill rail has not been seen on screen.** What to look at: a source list too short to
overflow (no buttons at all), one long enough to overflow (a button at each
end, the left one dimmed), and a scroll to the end (the right one dimmed, the
left one lit). The buttons are driven by `maxScrollExtent`, so the case worth
checking is a row that is *just* wider than its frame.

The rail is shared by the phone and desktop layouts, so the edge affordances
are split by *platform*, not width: the fade is drawn everywhere, the button
only on desktop. A tablet is wide enough to pass any breakpoint and is still
a touch device, where the row is dragged and a button over the first and last
pill would swallow taps meant for them. **The phone layout has not been seen on a device either**; what to check is
that the fade reads as "more this way" without a button, and that the first
and last pill are tappable right to their edges.

**A forced track picked by hand.** Forced shares the verified-selection path,
and stays manual-only by decision -- but no forced render has been confirmed
on a device yet. Pick one and check the picture, not just the tick.

### Translation (#68)

**Eleven sites need translating by hand.** They reach the screen through a
named argument or a field instead of `Text(`, so the scan cannot see them:
two tooltips on the Continue Watching card, a hint, the player's own title for
an anime episode, the Arabic pages' error text, and the browse pages' error
heading.

**The RTL remainder needs eyes, not geometry.** Physical padding is fixed
and held by a test; what is left is about meaning:

- **~87 `Alignment.centerLeft`-style constants.** Unlike the padding these
  are not all wrong: some are genuinely physical (a gradient, a badge pinned
  to a corner of artwork). Converting them wholesale would be a sweep with no
  test behind it. They need reading one at a time, asking "leading, or left?"
- **Icon direction.** A back chevron, a "next episode" arrow and the source
  rail's scroll buttons all point somewhere. Flutter does not mirror
  `Icons.arrow_forward_ios` for you; `Icons.arrow_forward` has a
  `matchTextDirection` sibling and these do not use it.
- **The player transport.** Seek-forward and seek-back are physical controls
  over a timeline, and a timeline in Arabic is a genuine design question, not
  a bug to fix blind.

**Catalog descriptions need Cinemeta's API to take a locale.** Synopsis text
comes from the Stremio addon, not TMDB (cast/crew only here) — unstarted.

**Still missing: show original titles.** The language picker ships
(`AppThemeService.setLocale`, four locales in Appearance settings) but the
opt-in display-only toggle does not: with a translated UI there is no way to
keep original/English titles, which is what Stremio, Plex and Jellyfin
default to. The rule it must obey lives in `docs/CONVENTIONS.md` under
Naming/Titles -- a translated title is not a stable identifier, while the
original is the one string every provider agrees on.

### Text scale and accessibility (#69)

**The unprobed tail.** ~46 files with a fixed `height:` still unaudited,
deliberately unranked: ranking by grepping `height:` returned 165 hits whose
loudest were `height: 4` spacers, and a ranking that wrong is worse than none.

**The details-page cards cannot be probed yet.** `DetailsPage` fetches over
the network and its rails are private builders, so there is nothing a test
can construct. Making them probeable means extracting the credit card and
the similar card as public widgets.

**Icon-only controls that are not buttons need reading one at a time.** An
`Icon` inside a `GestureDetector`: 24 candidates across 15 files, an
unreliable count since an ancestor `Tooltip` labels just as well. Buttons are
held by a test.

### Whether a phone can cast a torrent

The one open feature question. A torrent plays from TorrServer on the phone at
`127.0.0.1`, and a receiver asked to fetch that address asks *itself* — so it
would need the server bound to the LAN and handed the device's LAN address.

Reading the code settled half of it: **iOS is dead** (the plugin's Go shim
hardcodes `net.Listen("tcp", "127.0.0.1:"+portStr)`), and **on Android the
plugin is not the obstacle** — it exposes `port`, so the LAN URL would be built
here from `NetworkInterface.list()`.

What the shipped `libtorrserver.so` actually binds is unproven. One command
decides it, with a torrent playing on the phone, from a laptop on the same
Wi-Fi:

```
curl http://<phone-LAN-IP>:<port>/echo
```

An answer means the feature is possible. A refusal closes it for good.

