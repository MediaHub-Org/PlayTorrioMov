// test/widgets/subtitle_sample_placement_test.dart
//
// The sample subtitle shown while Subtitle Appearance is open must not sit
// under the panel that is open over it -- that panel is where the viewer is
// looking, and a sample they cannot see judges nothing.
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
/// sample overlay, the transport bar's band along the bottom, and the
/// subtitle panel in its anchor -- the same three the player screen stacks.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool sample = false;

  @override
  Widget build(BuildContext context) {
    // The same two lines the player screen runs.
    final insets = sample ? PlayerSubtitleMenu.sampleInsets(context) : null;
    return Stack(
      children: [
        const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        SubtitleOverlay(
          lines: const Stream.empty(),
          showSample: sample && insets != null,
          avoid: insets ?? EdgeInsets.zero,
        ),
        PlayerMenuAnchor(
          alignTop: sample,
          child: PlayerSubtitleMenu(
            groups: const [],
            isSubtitleEnabled: false,
            movieTitle: 'A Movie',
            delaySec: 0,
            onSelectVariant: (_) {},
            onSelectEmbedded: (_) {},
            onToggleOff: () {},
            onOpenSyncBar: () {},
            onAutoPick: () {},
            onClose: () {},
            onAppearanceOpenChanged: (open) {
              if (mounted) setState(() => sample = open);
            },
          ),
        ),
      ],
    );
  }
}

Future<({Rect panel, Rect? text, double transportTop})> openAppearance(
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

  await tester.tap(find.byIcon(Icons.tune_rounded));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final text = find.descendant(
    of: find.byType(SubtitleOverlay),
    matching: find.byType(Text),
  );
  return (
    panel: tester.getRect(find.byType(PlayerGlassCard)),
    // Null: no room worth using, and the pinned preview stands in.
    text: text.evaluate().isEmpty ? null : tester.getRect(text),
    transportTop: size.height -
        PlayerMenuAnchor.transportClearance(tester.element(find.byType(Scaffold))),
  );
}

/// The real subtitle face. Without it the tests draw in Ahem, where every
/// glyph is a full em wide, and a two-line sample comes out three times the
/// size it really is -- overlaps that never happen, hiding the ones that do.
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
    for (final pos in [100.0, 50.0, 0.0]) {
      testWidgets('${entry.key}, vertical position ${pos.round()}', (tester) async {
        PlayerSettings.subPos.value = pos;
        addTearDown(() => PlayerSettings.subPos.value = 100.0);

        final r = await openAppearance(tester, entry.value);
        final text = r.text;
        // ignore: avoid_print
        print('${entry.key} pos=${pos.round()} panel=${r.panel} text=$text');
        if (text == null) return;

        expect(r.panel.overlaps(text), isFalse, reason: 'the sample sits under the panel');
        expect(text.bottom, lessThanOrEqualTo(r.transportTop), reason: 'the sample sits under the transport bar');
        expect(text.top, greaterThanOrEqualTo(0));
        expect(text.left, greaterThanOrEqualTo(0));
        expect(text.right, lessThanOrEqualTo(entry.value.width));
      });
    }
  }

  testWidgets('a phone held sideways has no room, so no sample is drawn', (tester) async {
    final r = await openAppearance(tester, const Size(844, 390));
    expect(r.text, isNull);
  });
}
