// test/widgets/subtitle_sample_placement_test.dart
//
// Opening Subtitle Appearance must not move the panel, and the sample it shows
// must sit where real subtitles will -- the exact centre of the picture for
// "center" -- even when the panel, over on the right, covers part of it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/player/player_settings.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';
import 'package:playtorriomov/widgets/player/subtitle_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player's arrangement, cut down to what decides where things sit: the
/// sample overlay and the subtitle panel in its anchor, stacked as the player
/// screen stacks them.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool sample = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        SubtitleOverlay(lines: const Stream.empty(), showSample: sample),
        PlayerMenuAnchor(
          child: PlayerSubtitleMenu(
            isSubtitleEnabled: false,
            onSelectVariant: (_) {},
            onSelectEmbedded: (_) {},
            onEnable: () {},
            onDisable: () {},
            onOpenSyncBar: () {},
            onAppearanceOpenChanged: (open) {
              if (mounted) setState(() => sample = open);
            },
          ),
        ),
      ],
    );
  }
}

/// Where the panel stands before Appearance is opened, and where panel and
/// sample stand after.
Future<({Rect before, Rect panel, Rect text})> openAppearance(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _Harness()),
    ),
  );
  await tester.pump();
  final before = tester.getRect(find.byType(PlayerGlassCard));

  await tester.tap(find.byIcon(Icons.tune_rounded));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  return (
    before: before,
    panel: tester.getRect(find.byType(PlayerGlassCard)),
    text: tester.getRect(
      find.descendant(
        of: find.byType(SubtitleOverlay),
        matching: find.byType(Text),
      ),
    ),
  );
}

/// The real subtitle face. Without it the tests draw in Ahem, where every
/// glyph is a full em wide, and the two-line sample comes out three times the
/// size it really is.
Future<void> loadPoppins() async {
  final loader = FontLoader('Poppins');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Poppins-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(loadPoppins);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const sizes = <String, Size>{
    'desktop 1280x720': Size(1280, 720),
    'small window 900x600': Size(900, 600),
    'tablet 1024x768': Size(1024, 768),
    'phone portrait 390x844': Size(390, 844),
    'small phone 360x640': Size(360, 640),
    'phone landscape 844x390': Size(844, 390),
  };

  for (final entry in sizes.entries) {
    testWidgets('${entry.key}: the panel stays put and the sample is centred',
        (tester) async {
      final r = await openAppearance(tester, entry.value);

      expect(r.panel, r.before, reason: 'opening Appearance moved the panel');
      expect(
        r.text.center.dx,
        closeTo(entry.value.width / 2, 0.5),
        reason: 'the sample is off the centre of the picture',
      );
    });
  }

  testWidgets('the sample follows the side and vertical position settings',
      (tester) async {
    PlayerSettings.subAlignX.value = 'left';
    PlayerSettings.subPos.value = 0;
    addTearDown(() {
      PlayerSettings.subAlignX.value = 'center';
      PlayerSettings.subPos.value = 100;
    });

    final r = await openAppearance(tester, const Size(1280, 720));

    expect(r.text.left, lessThan(64), reason: 'left hugs the left edge');
    expect(r.text.top, lessThan(8), reason: 'position 0 is the top of the picture');
  });
}
