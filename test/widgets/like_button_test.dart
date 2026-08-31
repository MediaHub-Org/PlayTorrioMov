// test/widgets/like_button_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/widgets/common/like_button.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

Icon _icon(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon).first);

void main() {
  group('LikeButton', () {
    testWidgets('the pill keeps its icon white against the red fill',
        (tester) async {
      // The two presentations look like they disagree — the pill turns its
      // icon white, the bare icon turns it red. They do not: the pill has a
      // red fill behind the icon, so a red icon would vanish into it.
      await tester.pumpWidget(wrap(
        LikeButton(isLiked: true, onTap: () {}),
      ));
      expect(_icon(tester).color, Colors.white);

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, kLikedColor);
    });

    testWidgets('the bare icon carries the colour itself', (tester) async {
      await tester.pumpWidget(wrap(
        LikeButton(
          isLiked: true,
          onTap: () {},
          style: LikeButtonStyle.icon,
        ),
      ));
      expect(_icon(tester).color, kLikedColor);
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('unliked is an outline in both styles', (tester) async {
      for (final style in LikeButtonStyle.values) {
        await tester.pumpWidget(wrap(
          LikeButton(isLiked: false, onTap: () {}, style: style),
        ));
        expect(_icon(tester).icon, Icons.favorite_border_rounded,
            reason: '$style should show an outline when not liked');
      }
    });

    testWidgets('tapping reports through', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        LikeButton(isLiked: false, onTap: () => taps++),
      ));
      await tester.tap(find.byType(LikeButton));
      expect(taps, 1);
    });

    testWidgets('carries a toggle semantics label for screen readers',
        (tester) async {
      // The bare-icon style has no visible text, so without this a screen
      // reader announces an unlabelled button.
      await tester.pumpWidget(wrap(
        LikeButton(
          isLiked: false,
          onTap: () {},
          style: LikeButtonStyle.icon,
        ),
      ));
      expect(
        tester.getSemantics(find.byType(LikeButton).first).label,
        'Add to liked',
      );
    });
  });

  test('no page hand-rolls its own liked toggle', () {
    // Five content types each had their own: two pill variants, a bare
    // IconButton and two list-row hearts, in three different reds. This
    // catches the sixth.
    //
    // The signal is the *ternary* between the filled and outline heart, which
    // is what a toggle looks like. A lone `Icons.favorite_rounded` is a tab
    // icon or an empty-state glyph and is left alone — flagging those would
    // make the rule a nuisance rather than a guard.
    final toggle = RegExp(
      r'favorite_rounded[\s\S]{0,80}favorite_border_rounded',
    );
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.endsWith('like_button.dart')) continue;
      // Settings pages render hearts as style previews of the control, not
      // as a like on a piece of content.
      if (file.path.contains('/settings/')) continue;
      final source = file.readAsStringSync();
      // The fullscreen music player routes its like through the studio's
      // configurable hover physics, which LikeButton would drop. It uses
      // kLikedColor and carries the same semantics, so it follows the rules
      // without being the widget.
      if (source.contains('MusicInteractivePhysicsButton')) continue;
      if (toggle.hasMatch(source)) offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: 'use LikeButton so the icon, colour and semantics stay in step');
  });
}
