// test/rtl_directional_padding_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #68 ships Arabic, so every layout in `lib/` is rendered right-to-left for
/// some users. `Row`, `ListView` and the Material widgets flip themselves
/// under `Directionality`. Physical padding does not: `EdgeInsets.only(left:)`
/// is still the left edge in Arabic, so a leading inset becomes a trailing one
/// and the content hugs the wrong side of the screen.
///
/// This is the half of an RTL audit a test can hold. The other half —
/// whether an icon or a custom painter points the right way — needs eyes on a
/// device, and is recorded in the roadmap rather than pretended at here.
///
/// Unlike the `height:` scan #69 tried and abandoned, this pattern is exact:
/// `EdgeInsets.only(left:` names one physical edge and nothing else, so there
/// is no nesting to confuse it and no false positives to triage.
void main() {
  test('no padding names a physical edge instead of a direction', () {
    // `EdgeInsetsDirectional.only(start:/end:)` is the fix, and it is a drop-in
    // — `padding` and `margin` take `EdgeInsetsGeometry`, which both satisfy.
    final physical = RegExp(r'EdgeInsets\.only\(\s*(?:[^()]*?,\s*)?(left|right):');

    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (physical.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'use EdgeInsetsDirectional.only(start:/end:) — a physical edge '
          'does not flip for Arabic, so this inset lands on the wrong side',
    );
  });

  test('no alignment places content by physical edge instead of reading order',
      () {
    // The harder half of the same question, and the reason it was left out of
    // the first pass: unlike padding, not every physical `Alignment` is wrong.
    // Reading all 94 of them split cleanly in three:
    //
    //  * **Content in reading order** — a hero's title block, a logo in its
    //    corner, a trailing action button, a label in its own box, a side
    //    drawer, a rail's scroll arrows and the fade behind them. 39 sites;
    //    all `AlignmentDirectional` now.
    //  * **Artwork** — a gradient's `begin:`/`end:`. A scrim over a poster
    //    fades from an edge of the picture, and pictures do not mirror. Out of
    //    scope here, which is why this looks only at `alignment:`.
    //  * **A position along a value track** — the seek bar, the seek feedback,
    //    a progress fill, the volume fill, the skip countdown. Allowed below,
    //    because whether a video timeline runs right-to-left in Arabic is a
    //    design question about the timeline and nobody has answered it. They
    //    are one decision, not ten oversights, and they move together or not
    //    at all.
    final physical = RegExp(
      r'alignment:.*\bAlignment\.'
      r'(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b',
    );

    // `mirroredIfRtl` is the escape hatch for a widget whose `alignment` is
    // typed `Alignment` rather than `AlignmentGeometry`, so an
    // `AlignmentDirectional` there is a type error rather than a fix --
    // `CachedNetworkImage` is the one in this codebase, on three hero logos.
    // It takes a physical alignment by design and mirrors it itself.
    final mirrored = RegExp(r'mirroredIfRtl\(');

    /// Files whose alignment marks a position along a value track.
    const valueTracks = {
      'lib/pages/iptv/iptv_player_page.dart',
      'lib/pages/player/player_screen.dart',
      'lib/widgets/home/continue_watching_slider.dart',
      'lib/widgets/player/player_seek_bar.dart',
      'lib/widgets/player/player_seek_feedback.dart',
      'lib/widgets/player/player_skip_button.dart',
      'lib/widgets/player/player_volume_control.dart',
    };

    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (valueTracks.contains(file.path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (physical.hasMatch(lines[i]) && !mirrored.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'use AlignmentDirectional.centerStart/centerEnd — or add the '
          'file above if this alignment marks a position along a track '
          'rather than placing content',
    );
  });
}
