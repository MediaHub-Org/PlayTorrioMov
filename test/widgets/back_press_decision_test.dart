// test/widgets/back_press_decision_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/back_press_decision.dart';

BackAction decide({
  bool overlay = false,
  bool controls = false,
  bool armed = false,
  bool tv = true,
  bool loading = false,
}) => decideBackPress(
  hasOverlayOpen: overlay,
  controlsVisible: controls,
  exitArmed: armed,
  isTv: tv,
  isLoading: loading,
);

void main() {
  test('an open panel is closed first, whatever else is showing', () {
    for (final controls in [true, false]) {
      for (final armed in [true, false]) {
        expect(
          decide(overlay: true, controls: controls, armed: armed),
          BackAction.closeOverlay,
        );
      }
    }
    // Off a TV too: a phone's Back closes the panel rather than the film.
    expect(decide(overlay: true, tv: false), BackAction.closeOverlay);
  });

  test('on a TV the bars go next, then a second press leaves', () {
    expect(decide(controls: true), BackAction.hideControls);
    expect(decide(), BackAction.armExit);
    expect(decide(armed: true), BackAction.exit);
  });

  test('showing the bars again after arming puts them away before leaving', () {
    expect(decide(controls: true, armed: true), BackAction.hideControls);
  });

  test('off a TV Back leaves at once once nothing is open', () {
    expect(decide(tv: false, controls: true), BackAction.exit);
    expect(decide(tv: false), BackAction.exit);
  });

  test('a spinner is left at once, with nothing to protect', () {
    expect(decide(loading: true, controls: true), BackAction.exit);
    expect(decide(loading: true), BackAction.exit);
    // But a panel over it still closes first.
    expect(decide(loading: true, overlay: true), BackAction.closeOverlay);
  });
}
