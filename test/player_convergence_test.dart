import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Live TV player is meant to be the Movies/Series/Anime player with
/// fewer parts, not a second player that happens to look similar. Nothing
/// in a widget test can express that, because the drift is always the same
/// shape: a control gets hand-rolled on one page instead of reaching for
/// the shared widget. So these read the source.
String _read(String path) => File(path).readAsStringSync();

void main() {
  const mainPlayer = 'lib/pages/player/player_screen.dart';
  const livePlayer = 'lib/pages/iptv/iptv_player_page.dart';

  group('the two players share their chrome', () {
    test('Live TV builds its controls from the shared widgets', () {
      final source = _read(livePlayer);
      for (final widget in const [
        'PlayerIconButton', // buttons
        'PlayerCenterControls', // play/pause and seek
        'PlayerVolumeControl', // volume, including the boost range
        'SleepTimerMenu', // the moon button's popover
        'PlayerAspectMenu', // the panel it steps into
        'PlayerMenuAnchor', // where popovers sit
      ]) {
        expect(
          source,
          contains(widget),
          reason:
              '$widget is how the other player draws this. A local copy is '
              'how the two drifted apart in the first place.',
        );
      }
    });

    test('neither player hand-places a popover', () {
      // Every menu goes through PlayerMenuAnchor, which bounds it top and
      // bottom. A hand-written Positioned is how the speed menu ended up
      // off the top of a landscape phone: bottom-anchored with no top
      // bound, height it did not have went out of the viewport.
      final handPlaced = RegExp(
        r'Positioned\((?:[^()]|\([^()]*\))*?child:\s*Player(Settings|Speed|Aspect|Audio|Subtitle)Menu',
        dotAll: true,
      );

      for (final path in const [mainPlayer, livePlayer]) {
        expect(
          handPlaced.hasMatch(_read(path)),
          isFalse,
          reason: '$path: wrap it in PlayerMenuAnchor instead',
        );
      }
    });

    test('no player menu carries a close button', () {
      // Tapping off the panel dismisses it and the back arrow returns to
      // the settings root, so an X is a third way to do what those two
      // already do -- and it costs the header's right end, which on a
      // narrow card is the room the title needed.
      final menus = Directory('lib/widgets/player')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_menu.dart'));

      expect(menus, isNotEmpty, reason: 'the glob stopped matching anything');

      for (final menu in menus) {
        expect(
          menu.readAsStringSync(),
          isNot(contains('Icons.close_rounded')),
          reason: '${menu.path}: the barrier behind the menu already closes it',
        );
      }
    });

    test('Live TV keeps no bespoke aspect-ratio control', () {
      // It was a bordered pill reading FIT / ZOOM / STRETCH -- the last
      // control on the page with no counterpart in the other player. The
      // pill became the shared aspect menu, reached from a transport-bar
      // button; the gear it used to sit behind became the sleep timer, the
      // one thing the shared settings menu still held.
      final source = _read(livePlayer);
      expect(source, isNot(contains("'ZOOM'")));
      expect(source, contains('Icons.bedtime_rounded'));
    });
  });
}
