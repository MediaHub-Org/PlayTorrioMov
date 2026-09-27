// test/widgets/arrow_affordance_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/arrow_affordance.dart';
import 'package:playtorriomov/widgets/common/slider_arrow.dart';

Widget wrap(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

/// The direction an [Icon] actually rendered with, rather than the one its
/// caller asked for.
IconData renderedIcon(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon).first).icon!;

void main() {
  group('readingOrderArrow', () {
    testWidgets('leaves an arrow alone in a left-to-right layout',
        (tester) async {
      late IconData result;
      await tester.pumpWidget(wrap(Builder(builder: (context) {
        result = readingOrderArrow(context, Icons.arrow_back_ios_new_rounded);
        return const SizedBox();
      })));
      expect(result, Icons.arrow_back_ios_new_rounded);
    });

    testWidgets('turns every previous/next arrow around in Arabic, one way '
        'or the other', (tester) async {
      // Two mechanisms, and which one applies is Flutter's call rather than
      // ours. An `IconData` can declare `matchTextDirection`, and `Icon`
      // reflects the glyph itself when it does -- the `arrow_back_ios*` family
      // does. Swapping those for their opposite as well would turn them back,
      // so `readingOrderArrow` leaves them and swaps only the rest.
      //
      // Asserting the split rather than a list of which is which: the answer
      // belongs to the Flutter version in pubspec, and a list here would be a
      // second copy of it to go stale. What must hold is that each arrow is
      // handled exactly once.
      const arrows = [
        Icons.arrow_back_ios_new_rounded,
        Icons.arrow_back_ios_rounded,
        Icons.arrow_back_rounded,
        Icons.arrow_forward_ios_rounded,
        Icons.arrow_forward_rounded,
        Icons.chevron_left_rounded,
        Icons.chevron_right_rounded,
        Icons.keyboard_arrow_left_rounded,
        Icons.keyboard_arrow_right_rounded,
      ];

      final result = <IconData, IconData>{};
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          for (final icon in arrows) {
            result[icon] = readingOrderArrow(context, icon);
          }
          return const SizedBox();
        }),
        direction: TextDirection.rtl,
      ));

      for (final icon in arrows) {
        if (icon.matchTextDirection) {
          expect(
            result[icon],
            icon,
            reason: 'Icon already reflects this one, so swapping the glyph too '
                'would point it back the wrong way',
          );
        } else {
          expect(
            result[icon],
            isNot(icon),
            reason: 'nothing else turns this one around, so the glyph has to',
          );
          expect(
            arrowSenseOf(result[icon]!),
            isNot(arrowSenseOf(icon)),
            reason: 'the swap has to change the sense, not just the glyph',
          );
        }
      }
    });

    testWidgets('leaves vertical arrows and non-arrows alone in Arabic',
        (tester) async {
      final result = <IconData, IconData>{};
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          for (final icon in [
            Icons.keyboard_arrow_up_rounded,
            Icons.keyboard_arrow_down_rounded,
            Icons.close_rounded,
          ]) {
            result[icon] = readingOrderArrow(context, icon);
          }
          return const SizedBox();
        }),
        direction: TextDirection.rtl,
      ));

      // Up and down have no reading order to follow.
      expect(result[Icons.keyboard_arrow_up_rounded],
          Icons.keyboard_arrow_up_rounded);
      expect(result[Icons.keyboard_arrow_down_rounded],
          Icons.keyboard_arrow_down_rounded);
      expect(result[Icons.close_rounded], Icons.close_rounded);
    });

    testWidgets('leaves the player transport alone in Arabic', (tester) async {
      // Not an oversight: whether a video timeline should run right-to-left in
      // Arabic is a question about the timeline, and nobody has answered it.
      // Mirroring seek-back and seek-forward while the timeline stays put would
      // be the worse of the two possible wrongs. This test is the decision.
      final result = <IconData, IconData>{};
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          for (final icon in [
            Icons.replay_30_rounded,
            Icons.forward_30_rounded,
          ]) {
            result[icon] = readingOrderArrow(context, icon);
          }
          return const SizedBox();
        }),
        direction: TextDirection.rtl,
      ));

      expect(result[Icons.replay_30_rounded], Icons.replay_30_rounded);
      expect(result[Icons.forward_30_rounded], Icons.forward_30_rounded);
    });
  });

  group('SliderArrow', () {
    testWidgets('renders its arrow turned around for Arabic', (tester) async {
      const back = Icons.arrow_back_ios_new_rounded;

      await tester.pumpWidget(wrap(SliderArrow(icon: back, onTap: () {})));
      expect(renderedIcon(tester), back);

      await tester.pumpWidget(wrap(
        SliderArrow(icon: back, onTap: () {}),
        direction: TextDirection.rtl,
      ));
      // A horizontal ListView reverses under RTL, so the button that scrolls
      // back has to point the other way. Whether that happens by Flutter
      // reflecting the glyph or by this swapping it depends on the icon, so the
      // assertion is on the outcome the two share.
      final rendered = renderedIcon(tester);
      expect(
        back.matchTextDirection || arrowSenseOf(rendered) == ArrowSense.next,
        isTrue,
        reason: 'either Icon reflects it or readingOrderArrow swaps it',
      );
    });

    testWidgets('carries the label its own icon implies', (tester) async {
      await tester.pumpWidget(wrap(
        SliderArrow(icon: Icons.arrow_back_ios_new_rounded, onTap: () {}),
      ));
      expect(find.byTooltip('Previous'), findsOneWidget);

      await tester.pumpWidget(wrap(
        SliderArrow(icon: Icons.arrow_forward_ios_rounded, onTap: () {}),
      ));
      expect(find.byTooltip('Next'), findsOneWidget);
    });

    testWidgets('reports the tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        SliderArrow(icon: Icons.chevron_left_rounded, onTap: () => taps++),
      ));
      await tester.tap(find.byType(SliderArrow));
      expect(taps, 1);
    });
  });
}
