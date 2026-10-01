// test/widgets/details_poster_fit_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/app_units.dart';
import 'package:playtorriomov/widgets/details/details_metrics.dart';
import 'package:playtorriomov/widgets/details/details_poster_fit.dart';

Future<double> posterWidthAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: DetailsPosterFit(child: SizedBox(key: Key('poster'), height: 10)),
        ),
      ),
    ),
  );
  return tester.getSize(find.byKey(const Key('poster'))).width;
}

void main() {
  testWidgets('a tall window keeps the full poster column', (tester) async {
    const full = AppUnits.remPixels * DetailsDim.desktopPoster;
    expect(await posterWidthAt(tester, const Size(1920, 1080)), full);
  });

  testWidgets('a 960x540 TV layout shrinks the poster so Play stays on screen',
      (tester) async {
    const full = AppUnits.remPixels * DetailsDim.desktopPoster;
    final width = await posterWidthAt(tester, const Size(960, 540));

    expect(width, lessThan(full));
    // Poster (2:3) plus what sits under it must fit under the top gap: the
    // gap is the back button's footprint, so the page needs at least this.
    const below = AppUnits.remPixels * DetailsDim.belowPoster;
    const topGap = AppUnits.remPixels *
            (DetailsDim.backButton + DetailsSpace.md) +
        8; // AppSpacing.sm, the status-bar-less floating inset
    expect(width * 3 / 2 + below + topGap, lessThanOrEqualTo(540.5));
  });

  testWidgets('a very short window stops at a floor, not zero', (tester) async {
    const floor = AppUnits.remPixels * DetailsDim.posterFloor;
    expect(await posterWidthAt(tester, const Size(900, 200)), floor);
  });
}
