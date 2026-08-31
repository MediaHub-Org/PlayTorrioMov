import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/app_breakpoints.dart';

void main() {
  group('AppBreakpoints.tierForWidth', () {
    test('below 600 is mobile', () {
      expect(AppBreakpoints.tierForWidth(599), ScreenTier.mobile);
    });

    test('600 is tablet (lower bound inclusive)', () {
      expect(AppBreakpoints.tierForWidth(600), ScreenTier.tablet);
    });

    test('899 is tablet (upper bound)', () {
      expect(AppBreakpoints.tierForWidth(899), ScreenTier.tablet);
    });

    test('900 is desktop (lower bound inclusive)', () {
      expect(AppBreakpoints.tierForWidth(900), ScreenTier.desktop);
    });

    test('very wide is desktop', () {
      expect(AppBreakpoints.tierForWidth(2560), ScreenTier.desktop);
    });
  });
}
