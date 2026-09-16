// lib/l10n/l10n.dart
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// The app's strings, falling back to English when no delegate is in scope.
///
/// `AppLocalizations.of(context)` is generated with `nullable-getter: false`
/// (see `l10n.yaml`), so it force-unwraps and *throws* rather than returning
/// null when no delegate is registered. That is the right default for a real
/// screen -- a missing delegate in the app is a bug -- but it is wrong for a
/// widget that existing tests pump in a bare `MaterialApp`, which is most of
/// them. Those tests are not asserting anything about translation, and
/// rewriting each one to register four delegates would be a lot of noise for
/// no coverage.
///
/// So: use `context.l10n` in widgets that tests pump bare, and the generated
/// `AppLocalizations.of(context)` where a delegate is guaranteed. The English
/// fallback is the same string the widget rendered before it was translated,
/// so a bare-pumped test sees exactly what it saw before.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
}
