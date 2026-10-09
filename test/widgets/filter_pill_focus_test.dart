// "Sources of media" pills lost focus. The add-on pill is only in the row once
// the sources span more than one add-on, which is not known until the search
// is part-way through, so a pill appears *before* the one a remote may already
// be on. Children in a Row with no keys are matched by position, so the pill
// that moved up a slot was torn down and rebuilt as its neighbor, and focus
// fell off the row.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/pages/player/watch_screen.dart';
import 'package:playtorriomov/widgets/common/focus_fill.dart';
import 'package:playtorriomov/widgets/common/hover_button.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';

Widget pill(String label, {Key? key}) => HoverButton(
  key: key,
  onTap: () {},
  child: SizedBox(width: 60, height: 36, child: Center(child: Text(label))),
);

Widget rail(List<Widget> pills) => MaterialApp(
  home: Scaffold(body: FilterPillRail(children: pills)),
);

bool focused(WidgetTester tester, String label) =>
    Focus.of(tester.element(find.text(label))).hasPrimaryFocus;

void main() {
  testWidgets('keyed pills keep focus when a pill appears before them', (
    tester,
  ) async {
    Widget row({required bool withAddon}) => rail([
      pill('Audio', key: const ValueKey('audio')),
      pill('Quality', key: const ValueKey('quality')),
      if (withAddon) pill('Addon', key: const ValueKey('addon')),
      pill('Size', key: const ValueKey('size')),
    ]);

    await tester.pumpWidget(row(withAddon: false));
    Focus.of(tester.element(find.text('Size'))).requestFocus();
    await tester.pump();
    expect(focused(tester, 'Size'), isTrue);

    await tester.pumpWidget(row(withAddon: true));
    await tester.pump();

    expect(focused(tester, 'Size'), isTrue,
        reason: 'the pill the remote was on is still the one in focus');
  });

  testWidgets('without keys the same change drops focus (the bug)', (
    tester,
  ) async {
    Widget row({required bool withAddon}) => rail([
      pill('Audio'),
      pill('Quality'),
      if (withAddon) pill('Addon'),
      pill('Size'),
    ]);

    await tester.pumpWidget(row(withAddon: false));
    Focus.of(tester.element(find.text('Size'))).requestFocus();
    await tester.pump();

    await tester.pumpWidget(row(withAddon: true));
    await tester.pump();

    expect(focused(tester, 'Size'), isFalse,
        reason: 'documents why the pills carry keys');
  });

  testWidgets('a filter menu opens on the selected row', (tester) async {
    // The menu is a dialog route, which hands focus to nothing in it. The
    // scope that takes focus on open, and the selected row asking for it,
    // put a remote where the choice is.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerFocusOnOpen(
          child: Column(
            children: [
              for (final label in ['All', 'Small', 'Large'])
                FocusFill(
                  radius: 8,
                  child: InkWell(
                    autofocus: label == 'Small',
                    onTap: () {},
                    child: SizedBox(height: 40, child: Text(label)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(focused(tester, 'Small'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(tester, 'Large'), isTrue,
        reason: 'the arrows move within the menu');
  });
}
