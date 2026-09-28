import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';
import 'package:playtorriomov/services/tv_type.dart';

void main() {
  setUp(() {
    TvModeService.isTv.value = false;
  });

  group('TvType.scale', () {
    test('leaves fontSize unchanged off TV', () {
      expect(TvType.scale(10.5), 10.5);
    });

    test('scales fontSize up on TV', () {
      TvModeService.isTv.value = true;
      expect(TvType.scale(10.5), closeTo(14.7, 0.001));
    });

    test('the worst undersized case clears 11px on TV', () {
      TvModeService.isTv.value = true;
      expect(TvType.scale(8.5), greaterThan(11));
    });
  });
}
