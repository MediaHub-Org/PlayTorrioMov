# Conventions — PlayTorrioMov

How code is written in this repository. It exists so that a human and an AI
agent produce the *same* code for the same problem, and so that a change made
in one corner of the app looks like it belongs there.

This is not a style guide for its own sake. Every rule below is either
enforced by tooling, or it is a pattern this codebase already follows
consistently enough that breaking it is a bug in review.

---

## 1. The triangle

Three properties, in priority order. When they conflict, the one higher in
the list wins.

### Correctness — the floor

The code does what it claims, on every platform it ships to, including the
cases nobody typed in: a null track, a 404, a device with no Play Services, a
file with no subtitles, a user who presses the button twice.

Correctness is never traded. Not for speed, not for brevity, not for
elegance. A fast wrong answer is a bug with good benchmarks.

### Clarity — the default

A reader — human or agent — understands the intent without running the code,
without opening three other files, and without a comment explaining what the
line already says.

Clarity is the default state. It is only spent when efficiency has been
*measured* and the trade is worth it, and the trade is written down in a
comment at the site.

### Efficiency — a requirement, met with evidence

No more CPU, memory, network, battery, or binary size than the job needs.
This matters here more than in most apps: this is a video player that
decodes, streams torrents, and runs on phones and TVs.

But efficiency is satisfied by *evidence*, not by cleverness. "This is
faster" is a claim; a profile, a benchmark, or a measurement is an argument.
Unmeasured micro-optimization is how clarity gets spent for nothing.

### Comfort is the output, not a vertex

The three above are the inputs. Comfort — the feeling that the code is
pleasant to write and safe to change — is what you get when all three hold.
It is not a fourth thing to balance; it is the signal that the balance is
right.

When a change feels uncomfortable to make, that is information: something in
the triangle is off. Usually clarity.

### The tie-breaker

When two rules below disagree, ask in this order:

1. **Is it correct?** If not, stop. Fix that.
2. **Is it clear?** If not, and there is no measurement saying otherwise,
   make it clear.
3. **Is it efficient enough?** If a measurement says no, optimize — and
   leave the measurement in the comment.

---

## 2. Naming

Names are the cheapest documentation and the first thing a reader sees.

### Files

`snake_case.dart`, and the name matches the primary type it holds.

| File                       | Holds                                 |
|:---------------------------|:--------------------------------------|
| `player_transport.dart`    | `PlayerTransport`                     |
| `sleep_timer_service.dart` | `SleepTimerService`                   |
| `subtitle_languages.dart`  | the language tables and their helpers |

Suffixes carry meaning, and some are load-bearing:

| Suffix           | Meaning                           | Enforced by                                                                |
|:-----------------|:----------------------------------|:---------------------------------------------------------------------------|
| `_menu.dart`     | a player popover panel            | `test/player_convergence_test.dart` globs `lib/widgets/player/*_menu.dart` |
| `_service.dart`  | a singleton or static service     | convention                                                                 |
| `_provider.dart` | a subtitle scraper                | convention                                                                 |
| `_model.dart`    | a plain data type                 | convention                                                                 |
| `_page.dart`     | a routed screen                   | convention                                                                 |
| `_test.dart`     | a test, mirroring the `lib/` path | convention                                                                 |

The `_menu.dart` rule is not cosmetic: a test asserts that no file matching
that glob contains a close button. Renaming a menu to something else silently
removes it from that check.

### Types

`UpperCamelCase`. A type name is a noun phrase: `PlayerStepSlider`,
`SubtitleLanguageGroup`, `SleepTimerService`.

### Variables and functions

`lowerCamelCase`. A function name starts with a verb and says what it does,
not how:

```dart
// Yes
void _applyVolume(double value, {bool showHud = false});
Future<void> _savePlaybackProgress();
String? _selectedAudioLanguage;

// No — says nothing, or says the mechanism
void _doVolume();
Future<void> _writeJsonToDisk();
```

### Booleans

Read as a question: `isPlaying`, `hasOtherSources`, `canCastUrl`,
`_isCastableSource`, `_showControls`. Never `flag`, `check`, `status`.

### Callbacks

`on` + the event, past tense for things that happened, imperative for things
to do:

```dart
final VoidCallback onClose;              // do this
final ValueChanged<double> onRateSelected; // this happened
final VoidCallback? onBack;
```

### Private members

A leading `_`. If it is private, it is not part of the contract, and a test
that needs it gets `@visibleForTesting` rather than a rename to public.

### Constants

`lowerCamelCase` for `static const` and top-level `const`; `SCREAMING_CAPS`
is not used in this codebase.

```dart
static const List<double> _points = [0.25, 0.5, 0.75, 1.0];
const Map<String, String> _iso639ToDisplayName = { ... };
```

### Titles

A title is two fields on `AnimeMedia`, and they must never merge:
`canonicalTitle` feeds scraper queries, `uniqueKey`, Trakt/Simkl matching and
filename parsing, and is never localized; `nativeTitle` is the title in its
own language. `titleFor({required bool native})` picks between them, and a
model depends on nothing, so it takes the preference rather than reading
it — `animeDisplayTitle()` in `services/titles/title_display.dart` is what
every call site uses, reading `AppThemeService.preferNativeTitles`.

Localizing the identifier forks identity — the same show saved under one
setting becomes a different object from the one saved under another, taking
collection membership, Continue Watching dedupe and Trakt/Simkl matching with
it — and starves the title-string scrapers, which fail silently on a
translated title. `displayTitle` still exists as a fixed alias of
`canonicalTitle`, deliberately *not* made switchable: every call site was
checked and moved to `animeDisplayTitle`, and a getter that had quietly
started honoring the setting instead would have made a missed one impossible
to spot in review.

AniList sends four titles per show, so the toggle exists for anime today.
Movies and series carry one title, with no per-viewer choice to make.

### Spelling: American English, everywhere

One variant, not two. `color`, `behavior`, `catalog`, `center`, `gray`,
`labeled`, `canceled`, `initialize`, `normalize`, `optimize`, `analyze`,
`program`, `license`.

This applies to identifiers, comments, doc comments, commit messages and
docs — not just user-facing strings. Mixing the two is the actual problem:
`colour` in one file and `color` in the next makes a search miss half the
hits and makes the codebase read as though two people wrote it.

**The exception is an external API's own spelling.** AniList's GraphQL field
is `favourites`, and its status enum value is `CANCELLED`; those stay exactly
as the API spells them, because renaming them breaks the wire format. When a
British spelling is load-bearing, it is a quoted API token, not prose.

`test/american_spelling_test.dart` holds this, over `lib/`, `test/` and
`docs/` alike, with the API tokens allowed per file. Two forms are outside it
on purpose: `grey` is Flutter's own name (`Colors.grey`), and the
doubled-consonant forms (`cancelled`, `labelled`) are current in American
English and used by Flutter's API, so a guard on them would fight the
framework.

---

## 3. Functions

### One job, named for the job

If you cannot name it without "and", it is two functions.

### Small enough to read without scrolling

Not a line count — a *concept* count. A 40-line function that does one thing
linearly is fine. A 12-line function with four nested conditions is not.

### Extract when you would need a comment to explain a block

The comment is the signal. If a block needs a sentence to say what it does,
that sentence is the function's name.

```dart
// Before: a comment explaining a block
// Strip the media name, then the extension, then collapse whitespace.
var title = variant.title.trim();
for (final word in _words(movieName)) { ... }
title = title.replaceAll(...);

// After: the sentence became the name
final title = _cleanTitle(variant.title, movieName);
```

### Guard clauses over nesting

Return early. The happy path stays at one indentation level.

```dart
// Yes
Future<void> startDiscovery() async {
  if (!isSupported || !_initialized) return;
  try {
    await GoogleCastDiscoveryManager.instance.startDiscovery();
  } catch (e) {
    debugPrint('[CastService] startDiscovery error: $e');
  }
}

// No — the guard is a wrapper around everything
Future<void> startDiscovery() async {
  if (isSupported && _initialized) {
    try {
      await GoogleCastDiscoveryManager.instance.startDiscovery();
    } catch (e) { ... }
  }
}
```

### Named parameters past two arguments

Positional for one or two obvious arguments; named for everything else,
`required` for the ones with no sensible default.

```dart
SubtitleVariant({
  required this.providerName,
  required this.language,
  required this.title,
  this.extraData = const {},
  bool? isHearingImpaired,
});
```

### Side effects are named as side effects

A getter does not mutate. A function called `_selectedAudioLanguage` returns
a value; a function called `_applyVolume` changes something. Do not hide a
write inside a read.

### Pure where possible

Logic that can be a pure function should be one — it is testable without a
widget tree, a network, or a player. `SubtitleAutoPick` is the model: the
rules for "which subtitle should turn on" live in a static class with no
dependencies, so they can be read and tested on their own.

---

## 4. Control flow

### `if` / `else if` chains: order by likelihood, not by alphabet

The common case first. The player's key handler checks `space` before `f11`
because space is pressed constantly and F11 rarely.

### Prefer `switch` expressions for mapping

When every branch produces a value, a `switch` expression beats a chain of
`if`s and is exhaustive by construction:

```dart
final regionName = switch (region) {
  'latam' || 'latin america' => 'Latin America',
  'br' || 'brazil' => 'Brazil',
  _ => _capitalizeWords(region),
};
```

### No nested ternaries

One ternary is a choice. Two is a puzzle. Extract a variable or a function.

```dart
// Yes
final isShort = size.height < 500;
final isCompact = size.width < 680;
return (isShort ? 46.0 : (isCompact ? 62.0 : 78.0)) + padding;

// No
return (a ? (b ? c : d) : (e ? f : g));
```

### Loops: `for` when you need control flow, `where`/`map` when you do not

Use the collection methods for a straight transform. Use a `for` loop when
you need to `break`, `continue`, accumulate into more than one thing, or
await inside.

```dart
// Transform — collection methods
final names = tracks.where((t) => t.language != null).map((t) => t.language!).toList();

// Control flow — a loop
for (final variant in allVariants) {
  final language = canonicalLanguageGroup(variant.language);
  if (language.isEmpty) continue;
  if (!seen.add(key)) continue;
  grouped.putIfAbsent(language, () => []).add(cleaned);
}
```

`forEach` is not used for side effects; a `for` loop says the same thing
without the closure.

### Do not optimize a loop before measuring it

The loop over subtitle variants runs once per search, over tens of items. The
loop over decoded video frames runs sixty times a second. Only one of those
is worth a clever data structure, and the profile says which.

---

## 5. Structure

### Where things live

```
lib/
  models/      plain data types; depend on nothing
  services/    one folder per domain; own the state and the I/O
  widgets/     reusable UI, grouped by area (player/, hub/, ...)
  pages/       routed screens, grouped by area
  utils/       small pure helpers
  l10n/        generated localizations + the context.l10n accessor
```

### Dependencies point inward

`pages` → `widgets` → `services` → `models`.

A model never imports a service. A service never imports a page. A widget
never reaches into a page's state. When you feel the urge to break this, the
thing you want is usually a callback passed down, or a `ValueNotifier` the
service owns.

### One primary type per file

Helpers used only by that type live in the same file, private. Helpers used
by two types move to a shared file — `subtitle_languages.dart` exists because
three providers had three copies of the same table and they had drifted.

### Services: two shapes, pick deliberately

**Stateless, static-only** — `abstract final class`, no instances:

```dart
abstract final class CastService {
  static bool get isSupported => ...;
  static Future<void> initialize() async { ... }
}
```

**Stateful, one owner** — a singleton with an `instance`, holding
`ValueNotifier`s the UI listens to:

```dart
class SleepTimerService {
  SleepTimerService._();
  static final SleepTimerService instance = SleepTimerService._();
  final ValueNotifier<int?> minutesRemaining = ValueNotifier<int?>(null);
}
```

A singleton is justified when the state must outlive the widget that shows it
— the sleep timer keeps counting while the controls are hidden and the menus
are closed. It is not justified as a way to avoid passing a parameter.

### Shared UI primitives live in one place

`player_glass.dart` holds `PlayerGlassCard`, `PlayerMenuHeader`,
`PlayerIconButton`, `PlayerToggleChip`, `FocusRing`, `PlayerStepSlider`. A
player menu composes these; it does not re-implement a card or a button.

### Localization

Two accessors, and the choice is deliberate:

- `context.l10n` — falls back to English when no delegate is in scope. Use
  it in **widgets that tests pump bare**, which is most of them.
- `AppLocalizations.of(context)` — force-unwraps and throws without a
  delegate. Use it on **real screens**, where a missing delegate is a bug
  worth failing on.

English is the fallback, so a missing key degrades rather than crashes. The
reasoning is written out in `lib/l10n/l10n.dart`. Reaching for the wrong one
breaks every test that renders the widget, and the failure reads as a
null-check crash rather than a missing delegate, so it costs more to diagnose
than it should.

**Adding a string, per string:**

1. Add the key to `lib/l10n/app_en.arb` **and all three translations** —
   `app_es.arb`, `app_ar.arb`, `app_pt.arb`. A test compares every file to
   English in both directions, because a missing key does not crash:
   `gen-l10n` emits the English string, so the app looks fine and one screen
   is quietly untranslated.
2. Run `flutter gen-l10n`. The generated `app_localizations*.dart` is
   gitignored and CI regenerates it.
3. Read it with `context.l10n.yourKey`.

Append keys as text, in the file's own one-line-per-`@key` style. Rewriting an
ARB through a JSON dump reformats every entry in it — that was +1049/−185 for
two keys, and it breaks "do not reformat what you did not change."

A value inside a sentence takes a placeholder, never concatenation:
`detailsPlayEp` is `"Play Ep {number}"`, because word order differs in the
other three languages. A count that changes the noun takes an ICU plural —
`"{count, plural, =1{1 Season} other{{count} Seasons}}"` — and Arabic gets its
own `=2` / `few` / `many` forms, which `libraryTitleCount` shows.

Before adding a key, check whether one already says it. Of 42 strings found in
the last sweep, a third needed no new key: the portal browser had its own
English copies of four rows the settings page already translated, and
`discoverAllOf` was added and then removed because `catalogAllOf` already read
`"All {name}"` word for word.

**A `const` enum cannot hold a translated string; give it a method.**
`LibrarySection.localizedLabel` and `LibraryShelf.localizedLabel` are the
shape to copy (`HubSection.localizedLabel` is the earlier hand-rolled
version). `DecoderPreset`, `BufferResiliencePreset` and
`SubtitleStylePreset` expose `title(l10n)` / `description(l10n)` with
exhaustive switches, so a preset without a translation is a compile error
rather than a blank row.

**What stays English is data, not UI, and that is a decision rather than a
gap.** The 48 scrapers build a source's `title` and `description` from their
own name and the release's quality ("VidRock · Alpha · 1080p"): those strings
are how a source row is read and matched, not sentences. Debrid provider ids
are persisted and compared with `==`, so only the display of `'None'` is
translated, never the value. Platform names and the Keyboard Shortcuts page's
key column are product names and physical keys; only the generic
`Desktop/Mobile` fallback goes through the ARB. AniList's genre and format
values are sent back to its API to filter.

**Translating a widget can expose an overflow the English hid.** A longer
Portuguese string pushed the audio menu's rows 75px past the card. Probe a
newly translated widget in the longest language at a phone's width, not only
in English — see *Probing for overflow at 3x text scale*.

### Right-to-left

Arabic ships, so every layout in `lib/` renders right-to-left for some users.
`Row`, `ListView` and the Material widgets flip themselves under
`Directionality`. **Physical padding does not:** `EdgeInsets.only(left:)` is
still the left edge in Arabic. Use `EdgeInsetsDirectional.only(start:/end:)`,
which is a drop-in — `padding` and `margin` both take `EdgeInsetsGeometry`.

`test/rtl_directional_padding_test.dart` fails if a physical edge comes back.
37 sites across 21 files were wrong, and two of them applied a whole *page*
inset that way, so Live TV's search page and the watch-history page hugged the
wrong edge entirely.

`Alignment` is the same question, and the answer splits three ways: content in
reading order is `AlignmentDirectional`; a gradient over artwork stays physical,
because pictures do not mirror; and an alignment that marks a position along a
value track (a seek bar, a progress fill) belongs to the unanswered question of
whether a timeline should mirror at all.
`test/rtl_directional_padding_test.dart` holds the first and allowlists the
third by file.

**Check `matchTextDirection` before mirroring an icon.** An `IconData` can
declare it, and `Icon` reflects the glyph itself when it does — the
`arrow_back_ios*` family does, so swapping one for its opposite would turn it
back. `readingOrderArrow` in `widgets/common/arrow_affordance.dart` reads the
flag rather than keeping a list of which icons have it, because that answer
belongs to the Flutter version in `pubspec.yaml`.

### Sizes: rem and named tokens, not numbers

A size is `context.rem(AppRem.md)`, never `12` or `40`. One rem is 16 logical
pixels at the default text size and follows the user's text size (the system's
and the in-app zoom), clamped to the range the layouts were probed to hold --
see `lib/services/app_units.dart`. A gap, a bar, a button's padding and an icon
then move with the text, and a change of spacing is made in one place.

- **A recurring size has a name; a one-off can be a rem number.** The spacing,
  radius and icon steps are `AppRem` tokens (`context.rem(AppRem.md)`). A
  size used in one place and nowhere else may be written as rem directly
  (`context.rem(2.75)`, which is 44 logical pixels at the default text size);
  give it a name the second time it appears. The guard test only rejects bare
  pixel numbers, so both pass.
- **Font sizes are not rem.** Flutter multiplies a `fontSize` by the text
  scaler when it paints, so scaling it here too would apply the setting twice.
  Use the constants in `AppType`, which is a half-step ramp (`caption` 12,
  `captionPlus` 12.5, `small` 13, ...).
- **A hairline stays a hairline.** A 1px border is meant to be 1px at any text
  size; mark the line `// px` so the guard test lets it through.
- **Not `const`.** A rem size depends on the context, so the widget holding it
  cannot be `const`. That is the price of a size that moves; it is cheap.
- **Fractions of the window** (a poster's width, a menu's) already avoid a
  fixed number; give their bounds as rem too.
- **The guard covers the whole UI.** `test/units_no_raw_pixels_test.dart` scans
  every file under `lib/pages` and `lib/widgets` and fails on a bare size. A
  file that must keep pixels goes in its `exemptFiles`, with the reason (none
  does today). A widget whose height is a budget that a test measures takes the
  text-size factor instead: `SimilarCard.heightFor(width, scale)`,
  `CreditCard.railHeightOf(context)` and
  `ContinueWatchingSlider.bandHeight(width, scale)`, where `scale` is
  `AppUnits.scaleOf(context)`. `lib/services` is not
  scanned: a number there is data, not the size of something on screen.

### Text scale: the box must be able to grow

A reader can set text to 3x. Where a box's height is fixed by the layout around
it rather than by its own text, that text runs outside it.

- **`Wrap` and `Expanded` are not interchangeable**, and the settings pages
  proved it. A `Wrap` hands its children unbounded width, so a block of text
  inside one sizes to its natural 3x width and runs off the card — a 1310px
  overflow, not a fix. Reach for `Wrap` when the children are small and can
  genuinely sit on a second line; reach for `Expanded` when one child is a
  block of text that should wrap internally.
- **`Text` + `Spacer` + button in a flat `Row` is the recurring bug.** The
  title takes its natural width and shoves the button off the edge — 321px in
  the cast sheet's header. `Expanded` on the text, taking the `Spacer`'s job,
  is the fix. This exact shape has been the bug three times: that header, the
  Continue Watching header, and the catalog cards' metadata rows.
- **Clamp only what has nowhere to go.** `ClampedTextScale` (default 1.3, the
  established ceiling) is for a box that genuinely cannot grow. Where it can —
  a control strip sitting in a `Wrap` — let it grow instead; the Episodes strip
  still wanted 179px at 1.3 because its jump input and batch dropdown are
  fixed-width boxes with text inside them.
- **Scroll rather than clamp when the content is a list.** The cast sheet had
  no scrollable at all, so anything taller than the modal painted past the
  bottom — and that is not only a 3x problem.

---

## 6. Comments

This codebase comments the **why**, and it does so in prose. That is a
convention, not an accident, and it is the single most distinctive thing
about the code here.

### Comment the reason, not the mechanism

```dart
// Yes — explains a decision the code cannot
// A one-minute ticker rather than a single Timer for the whole span:
// the badge then counts down visibly, which is the difference between
// a timer that is running and one the user has to take on faith.

// No — restates the line
// Create a periodic timer of one minute.
```

### Record the history that explains the shape

When code exists because of a bug, say so. The next reader will otherwise
"simplify" it back into the bug.

```dart
// The chips existed for several releases before anything was wired
// behind them: choosing "30 min" changed a highlight and nothing else.
```

### Say what was rejected, when the alternative is tempting

```dart
// Deliberately a host test rather than the old "is this a torrent"
// test. A torrent source is not inherently uncastable: plenty resolve
// through a debrid or a torrent server on another machine.
```

### Do not comment the obvious

No `// increment i`, no `// return the result`, no doc comment that repeats
the signature. A doc comment earns its place by adding a constraint, a
reason, or a warning.

---

## 7. Errors and failure

### Optional features degrade, they do not crash

Cast, subtitles, media session, Discord RPC — all of these are extras. If one
fails, the app plays video anyway.

```dart
try {
  _handler = await AudioService.init(...);
} catch (e, st) {
  debugPrint('Media session unavailable: $e\n$st');
  _handler = null;
}
```

### Never swallow an error silently

`catch (_) {}` with no comment is a bug. Either log it, or comment why the
failure is genuinely uninteresting at that site.

### `debugPrint`, never `print`

`avoid_print` is a warning in `analysis_options.yaml` because 71 bare
`print()` calls were leaking resolved stream URLs into release logs. Tests
relax this rule on purpose — a scraper smoke test prints its findings.

### Fail loudly in tests, quietly in production

A test that cannot reach its fixture should fail. A production path that
cannot reach a subtitle provider should return an empty list and move on.

---

## 8. Tests

### Mirror the `lib/` path

`lib/services/subtitles/subtitle_service.dart` →
`test/services/subtitle_service_test.dart`.

### Test behavior, not implementation

Assert what the user gets, not which private method ran. When a test needs an
internal, expose it with `@visibleForTesting` rather than widening the API.

### Name the test as a sentence about behavior

```dart
test('collapses the same subtitle arriving from two providers', () { ... });
testWidgets('right arrow moves one step up', (tester) async { ... });
```

### Comment the test's reason when it is not obvious

A test that exists because of a specific past bug should say which one. The
sleep timer suite does this: it explains that the chips were decorative for
several releases, which is why the test drives the real service.

### Network tests are tagged

Live-network tests carry the `network` tag (`dart_test.yaml`), and CI runs
`flutter test --exclude-tags network`. A new test that hits the network must
be tagged, or CI becomes flaky for everyone.

### Widget tests must not leave timers pending

A started `Timer.periodic` is rejected at teardown. Cancel it in the test, or
drive it with `fakeAsync`.

### Probing for overflow at 3x text scale

`test/text_scale_overflow_test.dart` renders a widget at scale 3.0 on a
360px-wide view and asserts nothing reached the binding. Flutter raises an
overflow as an exception carrying an exact pixel count, so a failure names the
widget and the amount. Add a case per widget.

**Do not audit by grepping `height:`.** It was tried and it does not survive
contact: a span-based scan pairing each fixed height with the largest
`fontSize` inside it returns 165 hits, and the loudest are `height: 4` spacers
that merely sit in the same subtree as a `fontSize: 22` title. A static scan
cannot tell "box that wraps this text" from "box that happens to be near it",
so the ranking is noise.

Two things the probe gets wrong if you let it:

- **A page with a looping animation never settles.** `pumpAndSettle` times out
  on the details pages' ambient background rather than reporting anything about
  layout. Overflow is raised during layout on the first frame, so those cases
  need `pumpAtScale(settle: false)`.
- **Pump it where it actually lives.** A bare pump of the player menu reported
  1891px of vertical overflow and `SectionHeader` 790px. Neither can happen in
  production — `PlayerMenuAnchor` bounds and scrolls the card, and a browse
  page is a scrollable. A probe that reports an overflow production cannot
  have is not finding a bug; it is finding the test's own scaffolding, and it
  costs exactly the time it takes to work that out.

### Invariant tests that scan source

Four tests read `lib/` as text instead of pumping it, because the code that
stays wrong longest is on pages nothing can construct: the portals modal and
the channel sheet both fetch over the network.

| Test                           | Invariant                                |
|:-------------------------------|:-----------------------------------------|
| `no_hardcoded_text_test`       | No `Text()` holds an English sentence    |
| `icon_button_tooltip_test`     | Every icon-only button carries a tooltip |
| `rtl_directional_padding_test` | No padding names a physical edge         |
| `american_spelling_test`       | One spelling of every word               |

Each keeps an allowlist keyed by file, and an entry in one is a decision that
the case is genuinely not what the test is looking for — a unit, an API token,
a shell command — never a way to defer the fix. Each skips
`lib/l10n/app_localizations*`, which is generated: the spelling scan learned
that the hard way, passing over `lib/` while CI failed on a generated doc
comment copied out of an ARB `@description`.

---

## 9. Tooling and the commit

### Before every commit

```bash
flutter analyze --fatal-infos
flutter test --exclude-tags network
```

Both must be clean. CI runs exactly these, plus an Android APK build.

### Lints that are on

From `analysis_options.yaml`: `prefer_single_quotes`,
`prefer_const_constructors`, `prefer_const_declarations`,
`prefer_const_literals_to_create_immutables`, and `avoid_print` promoted to a
warning.

`const` is not optional here — it is a lint, and it is also the cheapest
efficiency win available.

### Commit messages

Conventional-commit style, imperative subject, body explaining the *why*:

```
Fix flatpak suspend + shortcut focus loss; retry failed catalogs

- Flatpak: grant --talk to org.freedesktop.ScreenSaver so wakelock_plus's
  Inhibit call actually lands; the sandbox silently dropped it before.
```

### Keep the docs current

- `CHANGELOG.md` — a `[Unreleased]` entry for anything user-visible.
- `docs/ROADMAP.md` — **pending work only**. Anything that shipped belongs in
  the changelog, any rule for writing code belongs in this file, and settled
  scope decisions live under §12 below. The roadmap is a list of what is left,
  not a record of what happened.

---

## 10. For AI agents

The rules above apply to you. These are the ones that matter most in
practice.

### Read before you write

Open the file, and open one neighbour that does the same kind of thing. Match
it. The fastest way to make this codebase worse is to introduce a second
convention for something that already has one.

### Match the comment voice

Prose, explaining why, referencing history when it explains the shape. Do not
add `// TODO: implement` or restate the signature.

### Do not reformat what you did not change

A diff that touches 400 lines to change 4 is a diff nobody can review. Leave
the surrounding code alone.

### Prefer editing to rewriting

A targeted edit preserves the comments and the decisions embedded in them. A
rewrite silently discards both.

### Verify, do not assume

Run `flutter analyze --fatal-infos` and the test suite. A change that
compiles is not a change that works. If you cannot run something, say so
rather than claiming it passes.

### Say when you are unsure

"I could not verify this against a real receiver" is a useful sentence. A
confident claim about untested behavior is not.

### Do not add a dependency for something small

A date format, a string helper, a small parser — write it. Every dependency
is a supply-chain surface, a build-time cost, and a future upgrade.

### Leave the triangle balanced

If you find yourself writing something clever to save a millisecond in a
function that runs once per screen, stop. If you find yourself writing
something obvious that runs per frame, measure it.

---

## 11. Review checklist

- [ ] Correct on every platform it ships to, including the empty and error cases.
- [ ] Names say what the thing is or does.
- [ ] Functions do one job and are named for it.
- [ ] Guard clauses, not nesting.
- [ ] No nested ternaries.
- [ ] Comments explain why, in the repo's voice.
- [ ] American spelling throughout (`color`, `behavior`, `catalog`), except
      where an external API spells it otherwise.
- [ ] Dependencies point inward.
- [ ] Shared primitives reused, not re-implemented.
- [ ] User-facing strings via `context.l10n` (bare-pumped widgets) or
      `AppLocalizations.of(context)` (real screens).
- [ ] Failures degrade; nothing optional can crash startup.
- [ ] `debugPrint`, not `print`.
- [ ] Tests mirror the `lib/` path and assert behavior.
- [ ] Network tests tagged `network`.
- [ ] `flutter analyze --fatal-infos` clean.
- [ ] `flutter test --exclude-tags network` green.
- [ ] `CHANGELOG.md` updated if user-visible.
