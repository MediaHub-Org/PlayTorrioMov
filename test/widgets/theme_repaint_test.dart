import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';
import 'package:playtorriomov/widgets/common/section_top_bar.dart';

/// The app's chrome is handed down as `const` — `home: const HubPage()` in
/// main.dart, `const SectionTopBar()` in AdaptiveNavShell. A const widget with
/// no arguments is canonicalised to one instance, so on the next build Flutter
/// finds the identical widget in the same slot, reuses the element and never
/// calls `build` on it. These bars paint from `AppColors`, which reads globals
/// rather than an inherited widget, so nothing else marked them dirty either:
/// the bar kept whichever theme it was first built under until something
/// unrelated forced a rebuild, which is why navigating away and back "fixed"
/// it.
///
/// `AppColors.dependOn(context)` is the subscription that makes them repaint.
/// This test fails without it.
class _ConstHost extends StatelessWidget {
  const _ConstHost();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Column(children: [SectionTopBar()]));
}

/// Mirrors main.dart: a MaterialApp that rebuilds on the theme notifier, with
/// a const child. The const child is the whole point — without it the rebuild
/// would reach the bar anyway and there would be nothing to catch.
class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeService.themeMode,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppThemeService.createThemeData(
          AppThemeService.palettes[0],
          Brightness.light,
        ),
        darkTheme: AppThemeService.createThemeData(
          AppThemeService.palettes[0],
          Brightness.dark,
        ),
        themeMode: mode,
        home: const _ConstHost(),
      ),
    );
  }
}

Color _barColour(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(SectionTopBar),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('a const-built bar repaints when the theme changes',
      (tester) async {
    // Wide enough to be a desktop tier: SectionTopBar draws nothing on mobile,
    // where the same sections live in the bottom tab bar instead.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final original = AppThemeService.themeMode.value;
    addTearDown(() => AppThemeService.themeMode.value = original);

    AppThemeService.themeMode.value = ThemeMode.dark;
    await tester.pumpWidget(const _App());
    final dark = _barColour(tester);

    AppThemeService.themeMode.value = ThemeMode.light;
    await tester.pumpAndSettle();
    final light = _barColour(tester);

    expect(
      light,
      isNot(dark),
      reason: 'the bar is still painting the theme it was first built under',
    );

    // And back, so this is a subscription rather than a one-shot.
    AppThemeService.themeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(_barColour(tester), dark);
  });

  test('every widget that paints from AppColors subscribes to the theme', () {
    // The behavioural test above covers one bar. This covers the rule, which
    // is what stops the next const-built widget reintroducing the bug: if a
    // class reads these tokens and has a build(), it has to say so.
    //
    // Scoped to classes that read AppColors *in their own body* — a file can
    // hold several widgets and only some of them paint.
    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final src = file.readAsStringSync();
      if (!src.contains('AppColors.')) continue;

      for (final match
          in RegExp(r'^(?:abstract\s+)?class\s+(\w+)[^\n{]*\{', multiLine: true)
              .allMatches(src)) {
        final body = _classBody(src, match.start);
        if (body == null || !body.contains('AppColors.')) continue;
        if (!body.contains('Widget build(BuildContext context)')) continue;
        if (body.contains('AppColors.dependOn(context)')) continue;
        offenders.add('${file.path}: ${match.group(1)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these paint from AppColors but never subscribe, so a const '
          'parent will leave them on the theme they were first built under; '
          'add AppColors.dependOn(context) at the top of build',
    );
  });
}

/// The `{...}` of the class starting at [start], by brace matching.
String? _classBody(String src, int start) {
  final open = src.indexOf('{', start);
  if (open == -1) return null;
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}') {
      depth--;
      if (depth == 0) return src.substring(open, i);
    }
  }
  return null;
}
