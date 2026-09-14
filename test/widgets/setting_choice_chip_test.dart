// test/widgets/setting_choice_chip_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/setting_choice_chip.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SettingChoiceChip', () {
    testWidgets('fires only when it becomes the selection', (tester) async {
      // Material's onSelected also reports a chip being un-selected. Every
      // one of the ten call sites had written the same `if (selected)` guard
      // around its body, so the widget owns it -- and a row of these would
      // otherwise write the setting twice on one tap.
      var picks = 0;
      await tester.pumpWidget(
        wrap(
          SettingChoiceChip(
            label: 'Xtream Panels',
            selected: false,
            onSelect: () => picks++,
          ),
        ),
      );

      await tester.tap(find.text('Xtream Panels'));
      await tester.pumpAndSettle();
      expect(picks, 1);
    });

    testWidgets('tapping the chip that is already selected does nothing', (
      tester,
    ) async {
      var picks = 0;
      await tester.pumpWidget(
        wrap(
          SettingChoiceChip(
            label: 'M3U Playlists',
            selected: true,
            onSelect: () => picks++,
          ),
        ),
      );

      await tester.tap(find.text('M3U Playlists'));
      await tester.pumpAndSettle();
      expect(picks, 0);
    });

    testWidgets('renders at a phone width without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          Row(
            children: [
              SettingChoiceChip(
                label: 'Xtream Panels',
                selected: true,
                onSelect: () {},
              ),
              const SizedBox(width: 8),
              SettingChoiceChip(
                label: 'M3U Playlists',
                selected: false,
                onSelect: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('the Live TV chip styling lives in one place', () {
    // The audit counted 45 duplicated 12-line windows between the portals
    // modal and Live TV's settings page. All of it was this chip, written out
    // ten times across three files, every copy agreeing on the same six
    // styling properties. A scan rather than a widget test because what is
    // being pinned is that nobody writes an eleventh.
    const sources = [
      'lib/pages/iptv/iptv_portals_modal.dart',
      'lib/pages/settings/appearance/live_tv_settings_page.dart',
      'lib/pages/iptv/iptv_portal_browser_page.dart',
    ];

    test('no page builds a raw ChoiceChip with the accent styling', () {
      final offenders = <String>[];
      for (final path in sources) {
        final source = File(path).readAsStringSync();
        if (source.contains(
          'selectedColor: palette.primaryColor.withValues(alpha: 0.25)',
        )) {
          offenders.add(path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These files style a ChoiceChip by hand. Use SettingChoiceChip: '
            'that is what the duplication between them was.',
      );
    });

    test('both screens share one Default Starting Tab picker', () {
      // Same control, reachable from the modal and from settings. Two copies
      // is how the two drift apart.
      for (final path in [sources[0], sources[1]]) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('DefaultPortalTabPicker'),
          isTrue,
          reason: '$path should use the shared picker',
        );
        expect(
          source.contains('IptvSettings.setDefaultPortalTab'),
          isFalse,
          reason: '$path should not write the setting itself any more',
        );
      }
    });
  });
}
