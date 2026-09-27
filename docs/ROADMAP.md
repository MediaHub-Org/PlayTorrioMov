# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#76`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-27**, on `v1.8.12+45`.

---

## Pending

**Actionable now, no hardware** — #68 and #69. Neither is a research problem;
the methods live in `docs/CONVENTIONS.md` and the tests hold the invariants.

What is left is the part a test cannot hold:

- Data strings stay English on purpose.
- Unprobed fixed heights: lift on touch, probe, repeat. Pages that fetch
  on init (Details, Discover, the Watch cards) are out of scope -- their
  skeletons need the network, and this is about fixed heights around real
  text.

Six invariants are held by tests, not by passes over `lib/`:

| Test                           | Invariant                                                                   |
|:-------------------------------|:----------------------------------------------------------------------------|
| `no_hardcoded_text_test`       | No `Text()` holds an English sentence                                       |
| `icon_button_tooltip_test`     | Every icon-only control carries a label, button or not                      |
| `rtl_directional_padding_test` | No padding, and no content alignment, names a physical edge                 |
| `american_spelling_test`       | One spelling of every word, `.arb` files included                           |
| `text_scale_overflow_test`     | 31 probes hold at 3x text scale on a 360px view                            |
| `arrow_affordance_test`        | Every rail arrow turns around for Arabic, and the player transport does not |

### Device checks

Nothing here can be advanced by reading or writing code; each is one test
away from an answer. Cast issues go the same way: use it, and report what
breaks.

**A forced track picked by hand.** Forced shares the verified-selection path,
and stays manual-only by decision -- but no forced render has been confirmed
on a device yet. Pick one and check the picture, not just the tick.

### Translation (#68)

**What is left outside `Text(` is hardcoded Arabic.** The English sites are
keyed now -- Continue Watching badges, season-collection parts, the Arabic
sheet's status lines -- and `S01E01` shapes stay codes, as universal as episode
numbers. What remains is hardcoded Arabic across the Arabic anime pages:
correct for their audience today, and needing a native review before gaining
es/pt/en translations.

### Whether a phone can cast a torrent

The one open feature question. A torrent plays from TorrServer on the phone at
`127.0.0.1`, and a receiver asked to fetch that address asks *itself* — so it
would need the server bound to the LAN and handed the device's LAN address.

On Android the plugin is not the obstacle — it exposes `port`, so the LAN URL
would be built here from `NetworkInterface.list()`.

What the shipped `libtorrserver.so` actually binds is unproven. One command
decides it, with a torrent playing on the phone, from a laptop on the same
Wi-Fi:

```
curl http://<phone-LAN-IP>:<port>/echo
```

An answer means the feature is possible. A refusal closes it for good.
