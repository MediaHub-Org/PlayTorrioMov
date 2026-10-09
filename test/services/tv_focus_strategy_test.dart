// On a TV focus is always drawn. Flutter drops to touch mode on any pointer
// event, and in touch mode the Material controls draw no focus at all, so a
// remote app or an air mouse left the TV with nothing visibly selected.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => TvModeService.applyFocusStrategy(false));

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
