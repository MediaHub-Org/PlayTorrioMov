# PLAN — the embedded-subtitle work, in order

The decisions behind this are in [TODO.md](TODO.md). This is the execution
plan: what to change, in what order, and how each step is known to be done.

Last written: **2026-09-26**.

---

## Where we are

The subtitle menu **detects** a file's own tracks — the tab reads
`Embedded 20` — and selecting one puts nothing on screen. Three fixes have
been made to that path by reading the code, and none was confirmed against a
file. That is the whole problem: the bug has survived three plausible fixes
because none of them was measured.

Two things are also true and worth stating before anything else:

- **The Downloads work is uncommitted.** It is finished and green; it should
  not be carried through this work as an uncommitted diff.
- **`docs/TODO.md` is untracked.** It is the reasoning this plan rests on.

---

## Phase 0 — Commit what is finished

Nothing below should start on top of an uncommitted diff.

| What                                                           | Files                                                                                                                                                                                                        |
|:---------------------------------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Downloads: play/pause/resume, quality, source, audio languages | `lib/models/download/download_task_model.dart`, `lib/services/download/download_service.dart`, `lib/pages/collection/collection_page.dart`, the four ARBs, `CHANGELOG.md`, `test/download_service_test.dart` |
| The decisions this plan rests on                               | `docs/TODO.md`                                                                                                                                                                                               |

**Done when:** `git status` is clean and `flutter test --exclude-tags network`
is green.

---

## Phase 1 — Instrument, do not fix

**The rule for this phase: no behaviour changes.** Add logging, run it once,
read the answer. A fix written before the measurement is a fourth guess.

### What to add

A single method on `PlayerScreen`, called after an embedded track is
selected, that reads five properties off mpv and logs them together:

| Property                | The question it answers                                               |
|:------------------------|:----------------------------------------------------------------------|
| `sid`                   | Did the selection reach mpv at all? `no` or `auto` means it did not.  |
| `sub-visibility`        | Does mpv think it is drawing?                                         |
| `sub-ass`               | Is libass on?                                                         |
| `track-list/N/selected` | Does mpv agree this is the current track?                             |
| `sub-text`              | Did mpv decode a line? Empty for ASS is *expected* — libass draws it. |

Log them as one line, prefixed `[SubDiag]`, so they can be read together
rather than hunted for.

### How to read the result

| What you see                            | What it means                                          | Where the fix goes                  |
|:----------------------------------------|:-------------------------------------------------------|:------------------------------------|
| `sid` is `no` / `auto`                  | The selection never reached mpv                        | The selection call, not the styling |
| `sid` correct, `sub-visibility` is `no` | Something turned it back off after we set it           | Phase 3                             |
| All correct, nothing on screen          | The surface is covering it, or libass draws off-screen | The video stack, not the state      |

### Done when

One run of a file with embedded subtitles produces the five values, and they
point at exactly one of the three rows above. **Write the answer into
`TODO.md` §2 before touching any code.**

---

## Phase 2 — Remove auto-select

Independent of Phase 1, and a deletion rather than a feature.

**What goes:** the call that turns a file's own subtitle track on when
playback starts, and the flag that makes it happen once.

**What stays:** the ordering. Audio-language-first, then alphabetical, is a
pure function of the track list — no state, no side effects, already tested.
It is the cheap half of the feature and the half that works.

**Why:** auto-select is only defensible with a remembered preference, and
there is not one. Per file, from scratch, every time, it surprises the viewer
*and* cannot learn. Removing it is strictly better than what is there now.

### Done when

- Starting a file with embedded subtitles shows none.
- The menu still lists them, audio language first.
- The tests that asserted auto-load are deleted, not weakened — a test for
  removed behaviour is worse than no test.

---

## Phase 3 — One piece of state, not a parameter

`applySubtitleStyling` takes a `forceLibass` flag, and **twenty-odd call
sites do not pass it** — every appearance setter. So any appearance change
after selecting an embedded track turns it back off. That is a real bug, and
it is the same shape as the one already fixed once.

**The fix is not another parameter.** It is one value:

- `PlayerSettings` gains a `ValueNotifier<bool> embeddedSubtitleActive`.
- `PlayerScreen` sets it when an embedded track is selected, and clears it
  when subtitles are turned off or an online track is chosen.
- `applySubtitleStyling` reads it instead of taking `forceLibass`.
- The parameter is deleted, and with it the twenty call sites that had to
  remember it.

**Why this is the simplicity answer:** one place to set, one place to read,
and no call site that can forget. It is fewer moving parts than today, not
more — which is the test for whether a fix belongs.

### Done when

- `forceLibass` no longer exists anywhere.
- Changing the font, size, colour or position while an embedded track is on
  leaves it on.
- A test asserts that: set the state, call an appearance setter, assert
  `sub-visibility` was not set to `no`.

---

## Phase 4 — Confirm on a real file

**Nothing above is done until the picture changes.** This is the phase that
has been skipped three times.

Use a file whose embedded tracks are known to exist — the menu's count is the
check, and `ffprobe` is the ground truth:

```
ffprobe -v error -select_streams s -show_entries stream=index,codec_name:stream_tags=language,title -of csv file.mkv
```

Check, in order:

1. The menu lists the tracks, audio language first.
2. Selecting one puts text on screen.
3. Changing the font size while it is on leaves it on.
4. Turning subtitles off and on again works.
5. An online subtitle still works, and does not disturb the embedded path.

### Done when

All five hold, on a real file, on a real build. Report which ones were
checked and which were not — "untested against a real file" is a useful
sentence; a confident claim about untested behaviour is not.

---

## Phase 5 — The remembered preference (later, not now)

The right end state, and deliberately last.

One global "subtitles on/off", saved. If on, pick the audio-matching track
when a file opens. A manual choice wins for that session.

**Why not now:** it is a setting, a stored value, a migration and a
precedence rule. Building it on top of a path that does not render would mean
debugging two things at once, and the second one would hide the first.

---

## Rules for the whole plan

1. **Measure before fixing.** Phase 1 exists because three fixes were written
   without it. If a fix is proposed before the diagnostic has been read, the
   answer is no.
2. **A fix that adds a parameter is probably wrong.** Phase 3 removes one.
   The test for a fix here is whether it leaves fewer moving parts.
3. **Delete tests for deleted behaviour.** Do not weaken them into passing.
4. **One phase, one commit.** Each phase above is independently revertible,
   and Phase 1 in particular should be revertible on its own — it changes no
   behaviour and should be removable without touching anything else.
5. **Say what was not verified.** Every phase ends with a "done when" that
   names what was actually checked.
