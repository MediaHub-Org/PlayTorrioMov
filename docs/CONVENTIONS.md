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
Unmeasured micro-optimisation is how clarity gets spent for nothing.

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
3. **Is it efficient enough?** If a measurement says no, optimise — and
   leave the measurement in the comment.

---

## 2. Naming

Names are the cheapest documentation and the first thing a reader sees.

### Files

`snake_case.dart`, and the name matches the primary type it holds.

| File | Holds |
|:--|:--|
| `player_transport.dart` | `PlayerTransport` |
| `sleep_timer_service.dart` | `SleepTimerService` |
| `subtitle_languages.dart` | the language tables and their helpers |

Suffixes carry meaning, and some are load-bearing:

| Suffix | Meaning | Enforced by |
|:--|:--|:--|
| `_menu.dart` | a player popover panel | `test/player_convergence_test.dart` globs `lib/widgets/player/*_menu.dart` |
| `_service.dart` | a singleton or static service | convention |
| `_provider.dart` | a subtitle scraper | convention |
| `_model.dart` | a plain data type | convention |
| `_page.dart` | a routed screen | convention |
| `_test.dart` | a test, mirroring the `lib/` path | convention |

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

### Do not optimise a loop before measuring it

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
  l10n/        generated localisations + the context.l10n accessor
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

### Localisation

Two accessors, and the choice is deliberate:

- `context.l10n` — falls back to English when no delegate is in scope. Use
  it in **widgets that tests pump bare**, which is most of them.
- `AppLocalizations.of(context)` — force-unwraps and throws without a
  delegate. Use it on **real screens**, where a missing delegate is a bug
  worth failing on.

English is the fallback, so a missing key degrades rather than crashes. The
reasoning is written out in `lib/l10n/l10n.dart`.

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

### Test behaviour, not implementation

Assert what the user gets, not which private method ran. When a test needs an
internal, expose it with `@visibleForTesting` rather than widening the API.

### Name the test as a sentence about behaviour

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
- `docs/ROADMAP.md` — known-broken things, and decisions that are settled so
  they stop being re-litigated.

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
confident claim about untested behaviour is not.

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
- [ ] Dependencies point inward.
- [ ] Shared primitives reused, not re-implemented.
- [ ] User-facing strings via `context.l10n` (bare-pumped widgets) or
      `AppLocalizations.of(context)` (real screens).
- [ ] Failures degrade; nothing optional can crash startup.
- [ ] `debugPrint`, not `print`.
- [ ] Tests mirror the `lib/` path and assert behaviour.
- [ ] Network tests tagged `network`.
- [ ] `flutter analyze --fatal-infos` clean.
- [ ] `flutter test --exclude-tags network` green.
- [ ] `CHANGELOG.md` updated if user-visible.
