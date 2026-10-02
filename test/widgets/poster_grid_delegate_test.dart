import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/app_units.dart';
import 'package:playtorriomov/widgets/movie/movie_card.dart';

void main() {
  SliverGridLayout layoutFor(double width, int columns, {double scale = 1}) {
    final delegate = posterGridDelegate(
      contentWidth: width,
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 20,
      scale: scale,
    );
    return delegate.getLayout(
      SliverConstraints(
        axisDirection: AxisDirection.down,
        growthDirection: GrowthDirection.forward,
        userScrollDirection: ScrollDirection.idle,
        scrollOffset: 0,
        precedingScrollExtent: 0,
        overlap: 0,
        remainingPaintExtent: 800,
        crossAxisExtent: width,
        crossAxisDirection: AxisDirection.right,
        viewportMainAxisExtent: 800,
        remainingCacheExtent: 800,
        cacheOrigin: 0,
      ),
    );
  }

  test('the poster stays 1.48x its width at every column count', () {
    for (final (width, columns) in [(360.0, 3), (700.0, 4), (1200.0, 6), (1920.0, 7)]) {
      final layout = layoutFor(width, columns);
      final geometry = layout.getGeometryForChildIndex(0);
      final posterHeight =
          geometry.mainAxisExtent - AppRem.cardText * AppUnits.remPixels;
      expect(posterHeight / geometry.crossAxisExtent, closeTo(1.48, 0.001),
          reason: '$columns columns in $width px');
    }
  });

  test('a phone grid is no longer a near-square poster', () {
    // The regression: childAspectRatio 0.62 at 3 columns left ~1.0.
    final geometry = layoutFor(328, 3).getGeometryForChildIndex(0);
    final posterHeight =
        geometry.mainAxisExtent - AppRem.cardText * AppUnits.remPixels;
    expect(posterHeight, greaterThan(geometry.crossAxisExtent * 1.4));
  });

  test('a larger text size grows the text block, not the poster ratio', () {
    final small = layoutFor(328, 3).getGeometryForChildIndex(0);
    final large = layoutFor(328, 3, scale: 1.3).getGeometryForChildIndex(0);
    expect(large.mainAxisExtent, greaterThan(small.mainAxisExtent));
    expect(large.crossAxisExtent, small.crossAxisExtent);
  });
}
