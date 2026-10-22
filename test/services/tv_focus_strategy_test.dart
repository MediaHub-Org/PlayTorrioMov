// On a TV focus is always drawn. Flutter drops to touch mode on any pointer
// event, and in touch mode the Material controls draw no focus at all, so a
// remote app or an air mouse left the TV with nothing visibly selected.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(TvModeService.resetFocusPolicy);

  test('a fresh launch draws no focus until a key is pressed', () {
    TvModeService.installFocusPolicy();

    expect(
      FocusManager.instance.highlightStrategy,
      FocusHighlightStrategy.alwaysTouch,
    );
    expect(
      FocusManager.instance.highlightMode,
      FocusHighlightMode.touch,
    );
  });

  testWidgets('the first key moves a desktop viewer to keyboard focus', (
    tester,
  ) async {
    TvModeService.installFocusPolicy();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

    expect(
      FocusManager.instance.highlightStrategy,
      FocusHighlightStrategy.automatic,
    );
    expect(
      FocusManager.instance.highlightMode,
      FocusHighlightMode.traditional,
    );
  });

  testWidgets('on a TV the first key pins focus drawing on', (tester) async {
    TvModeService.isTv.value = true;
    addTearDown(() => TvModeService.isTv.value = false);
    TvModeService.installFocusPolicy();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

    expect(
      FocusManager.instance.highlightStrategy,
      FocusHighlightStrategy.alwaysTraditional,
    );
  });

  test('a TV pins focus drawing on, whatever last touched it', () {
    TvModeService.applyFocusStrategy(true);

    expect(
      FocusManager.instance.highlightStrategy,
      FocusHighlightStrategy.alwaysTraditional,
    );
    expect(
      FocusManager.instance.highlightMode,
      FocusHighlightMode.traditional,
    );
  });

  test('anything else leaves Flutter to decide', () {
    TvModeService.applyFocusStrategy(true);
    TvModeService.applyFocusStrategy(false);

    expect(
      FocusManager.instance.highlightStrategy,
      FocusHighlightStrategy.automatic,
    );
  });
}
