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

    testWidgets('swaps a previous/next arrow in a right-to-left layout',
        (tester) async {
      final swapped = <IconData, IconData>{};
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          for (final icon in [
            Icons.arrow_back_ios_new_rounded,
            Icons.arrow_forward_ios_rounded,
            Icons.chevron_left_rounded,
            Icons.keyboard_arrow_right_rounded,
          ]) {
            swapped[icon] = readingOrderArrow(context, icon);
          }
          return const SizedBox();
        }),
        direction: TextDirection.rtl,
      ));

      expect(swapped[Icons.arrow_back_ios_new_rounded],
          Icons.arrow_forward_ios_rounded);
      expect(swapped[Icons.arrow_forward_ios_rounded],
          Icons.arrow_back_ios_new_rounded);
      expect(swapped[Icons.chevron_left_rounded], Icons.chevron_right_rounded);
      expect(swapped[Icons.keyboard_arrow_right_rounded],
          Icons.keyboard_arrow_left_rounded);
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
    testWidgets('points the way its rail scrolls, in either direction',
        (tester) async {
      await tester.pumpWidget(wrap(
        SliderArrow(icon: Icons.arrow_back_ios_new_rounded, onTap: () {}),
      ));
      expect(renderedIcon(tester), Icons.arrow_back_ios_new_rounded);

      await tester.pumpWidget(wrap(
        SliderArrow(icon: Icons.arrow_back_ios_new_rounded, onTap: () {}),
        direction: TextDirection.rtl,
      ));
      expect(
        renderedIcon(tester),
        Icons.arrow_forward_ios_rounded,
        reason: 'a horizontal ListView reverses under RTL, so the button that '
            'scrolls back has to point the other way',
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
