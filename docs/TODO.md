# TODO — decisions to make, not code to write

This file is for questions that need an answer before anyone writes code.
Shipped work is in [CHANGELOG.md](../CHANGELOG.md); open bugs and unverified
claims are in [ROADMAP.md](ROADMAP.md).

Last written: **2026-09-26**.

---

## 1. Embedded subtitles: auto-select, or not?

### The question

When a file ships its own subtitle tracks, should the player turn one on by
itself?

### What each answer costs

**Auto-select on.** The viewer sees subtitles without asking. That is what
VLC and mpv do, and it is right for a file whose subtitles are the only way
to understand it. The cost is that it is a decision made on the viewer's
behalf, and it has to be *remembered* to be tolerable — otherwise someone who
turns subtitles off gets them back on the next episode, which is the single
most annoying thing a player can do.

**Auto-select off.** Nothing appears that nobody asked for. The viewer opens
the menu once and picks. The cost is that a viewer who needs subtitles has to
find them, and a file that ships them for a reason shows nothing.

### The finding

**Auto-select is only defensible with a remembered preference, and we do not
have one.** Today the choice is made per file, from scratch, every time. That
is the worst of both: it surprises the viewer *and* it cannot learn.

So the honest options are:

| Option                                     | What it means                                                               | Cost                                                                                                                      |
|:-------------------------------------------|:----------------------------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------|
| **A. No auto-select**                      | Nothing turns on by itself. The list is there; the viewer picks.            | Simplest. Predictable. A viewer who wants subtitles always opens the menu.                                                |
| **B. Auto-select + remembered preference** | One global "subtitles on/off", saved. If on, pick the audio-matching track. | Correct, and what Netflix does. Needs a setting, a stored value, and the rule that a manual choice wins for that session. |
| **C. Auto-select, per file, as now**       | —                                                                           | **Not an option.** It is what we have, and it is why this is a question.                                                  |

**Recommendation: A now, B later.** A is a deletion, not a feature — it
removes the code that is currently unverifiable and the behaviour that
surprises. B is the right end state but it is a setting, a migration and a
precedence rule, and it should not be built on top of a path that does not
work yet.

### The ordering question, separately

Ordering and auto-selection are independent, and it is worth not conflating
them.

**Audio-language-first ordering** is a pure function of data already on the
track list. It has no state, no side effects, and it is testable in isolation
— which is why it is already covered by tests. It costs about fifteen lines.

**Alphabetical-only** is simpler still, and it is what the list falls back to
when no track matches the audio.

**Recommendation: keep audio-first.** It is the cheap half of the feature and
the half that works. A viewer whose audio is Spanish and whose file has a
Spanish track should not have to read past Arabic, Czech and Danish to find
it. When nothing matches, the list is alphabetical — which is already the
behaviour, and already tested.

**What to remove:** the auto-select call, not the ordering. They are separate
code paths and only one of them is a problem.

---

## 2. Embedded subtitles do not render — stop guessing, instrument it

### What we know

- The menu **detects** them. The screenshot showed `Embedded 20`, so the
  track list is read correctly and the count is right.
- Selecting one does not put text on screen.
- The automatic path was reported working once, then reported broken. Both
  reports are from the same build family, so at least one is wrong.

### Why the guessing has to stop

Three fixes have been made to this path by reading the code, and none was
confirmed against a file. Each one was plausible and each one was unverified,
which is how a bug survives three fixes. The next step is not another fix.

### What to do instead

**Add a diagnostic, not a fix.** After selecting an embedded track, log what
mpv actually reports:

| Property                | What it tells us                                                                                                       |
|:------------------------|:-----------------------------------------------------------------------------------------------------------------------|
| `sid`                   | Whether a subtitle track is selected at all. If this is `no` or `auto`, the selection never reached mpv.               |
| `sub-visibility`        | Whether mpv thinks it is drawing.                                                                                      |
| `sub-ass`               | Whether libass is on.                                                                                                  |
| `track-list/N/selected` | Whether mpv agrees the track is the current one.                                                                       |
| `sub-text`              | The current line, if mpv decoded one. Empty for an ASS track is expected — libass draws it, it is not emitted as text. |

That table separates the three possible causes in one run:

1. **`sid` is wrong** → the selection never reached mpv. A player bug.
2. **`sid` is right, `sub-visibility` is `no`** → something turned it back
   off after we set it. See the note below.
3. **All correct, still nothing on screen** → the video surface is covering
   it, or libass is drawing off-screen. A rendering bug, not a state bug.

### The one code smell worth naming now

`applySubtitleStyling` takes a `forceLibass` flag, and **twenty-odd call
sites pass it without the flag** — every appearance setter does. So any
appearance change after selecting an embedded track turns it back off. That
is a real bug and it is the same shape as the one already fixed once.

The fix is not another parameter. It is **one piece of state**: the player
tells `PlayerSettings` "an embedded track is selected", and
`applySubtitleStyling` reads it. One place to set, one place to read, no
call site to forget. That is the simplicity answer, and it is worth doing
whether or not it turns out to be the cause.

---

## 3. How to tell whether a file has embedded subtitles

Three ways, in order of how much they cost:

1. **The subtitle menu's Embedded tab.** It shows a count — `Embedded 20`.
   That number *is* the answer, and it is already on screen. A file with none
   opens on the Online tab instead, because an empty Embedded tab would read
   as "no subtitles".
2. **The audio menu's track count.** A file with several audio tracks usually
   has several subtitle tracks; not a rule, but a hint.
3. **`ffprobe` on the file**, from a terminal:
   `ffprobe -v error -select_streams s -show_entries stream=index,codec_name:stream_tags=language,title -of csv file.mkv`
   This is the ground truth, and it is what to reach for when the menu and
   the picture disagree.

**If the menu says 20 and nothing renders, the file is fine and the player is
not.** That is the case to instrument, and it is the case in the report.

---

## 4. What to work on, in order

| # | Task                                                    | Why first                                                                                    |
|:--|:--------------------------------------------------------|:---------------------------------------------------------------------------------------------|
| 1 | **Instrument the embedded path** (§2)                   | Three fixes have failed blind. One run of the diagnostic table ends the guessing.            |
| 2 | **Remove auto-select** (§1, option A)                   | A deletion. Removes the surprising behaviour and the unverifiable code path in one change.   |
| 3 | **Move `forceLibass` into `PlayerSettings` state** (§2) | Fixes a real bug and removes a parameter from twenty call sites. Simpler *and* more correct. |
| 4 | **Confirm on a real file**                              | Nothing above is done until the picture changes.                                             |
| 5 | **Then decide on B** (§1)                               | A remembered preference is the right end state, but not on top of a path that does not work. |

### Not doing, so it stays decided

| What                                                        | Why not                                                                                                  |
|:------------------------------------------------------------|:---------------------------------------------------------------------------------------------------------|
| A per-file "remember my subtitle choice"                    | It is a preference wearing a per-file costume. One global setting is simpler and covers the same ground. |
| Reordering the list by anything but audio-then-alphabetical | Every other order needs a reason the data does not carry.                                                |
| A second `forceLibass`-style flag                           | The flag is the problem, not the number of flags.                                                        |