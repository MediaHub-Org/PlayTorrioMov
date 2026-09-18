# AGENTS.md

Instructions for AI agents working in this repository. The full guide is
[docs/CONVENTIONS.md](docs/CONVENTIONS.md) — read it before a non-trivial
change. This file is the short version.

## The triangle

Priority order, highest first:

1. **Correctness** — never traded. A fast wrong answer is a bug.
2. **Clarity** — the default. Only spent when efficiency is *measured*.
3. **Efficiency** — required, but met with evidence, not cleverness.

Comfort is the output when all three hold, not a fourth thing to balance.

## Non-negotiables

- `flutter analyze --fatal-infos` must be clean.
- `flutter test --exclude-tags network` must be green.
- `debugPrint`, never `print` (`avoid_print` is a warning here).
- `const` wherever the lints ask for it.
- User-facing strings: `context.l10n` in widgets tests pump bare,
  `AppLocalizations.of(context)` on real screens.
- Network tests carry the `network` tag.
- Widget tests must not leave a pending `Timer`.

## Match the codebase

- Read the file and one neighbour before editing. Match them.
- Comments explain **why**, in prose, and reference history when it explains
  the shape. Do not restate the signature.
- Prefer targeted edits over rewrites — a rewrite discards the comments and
  the decisions in them.
- Do not reformat code you did not change.
- Do not add a dependency for something small.

## Structure

```
lib/models/   plain data, depends on nothing
lib/services/ state and I/O, one folder per domain
lib/widgets/  reusable UI
lib/pages/    routed screens
```

Dependencies point inward: `pages → widgets → services → models`.

## Naming

- Files: `snake_case.dart`, named for the primary type.
- `_menu.dart` is load-bearing — a test globs `lib/widgets/player/*_menu.dart`
  and asserts no close button. Do not rename a menu out of that pattern.
- Types `UpperCamelCase`; variables and functions `lowerCamelCase`.
- Functions start with a verb and say what, not how.
- Booleans read as questions: `isPlaying`, `canCastUrl`.
- Callbacks: `onClose`, `onRateSelected`.
- Private members get `_`; tests use `@visibleForTesting`, not a rename.
- American spelling everywhere (`color`, `behavior`, `catalog`, `gray`),
  including comments and docs — except an external API's own spelling
  (AniList's `favourites`, its `CANCELLED` status).

## Control flow

- Guard clauses over nesting.
- `switch` expressions for mapping.
- No nested ternaries.
- Collection methods for transforms; `for` loops when you need `break`,
  `continue`, or `await`.
- Do not optimize a loop before measuring it.

## Failure

- Optional features (cast, subtitles, media session) degrade, never crash.
- Never swallow an error silently — log it or comment why it is uninteresting.
- Fail loudly in tests, quietly in production.

## Before you finish

1. Run the analyzer and the test suite. Report what you actually ran.
2. Update `CHANGELOG.md` if the change is user-visible.
3. Update `docs/ROADMAP.md` if you settled a decision or found a new break.
4. Say when you could not verify something. "Untested against a real
   receiver" is useful; a confident claim about untested behavior is not.
