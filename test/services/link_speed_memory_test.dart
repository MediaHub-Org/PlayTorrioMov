// The connection's ceiling is learned from trouble only. A fast start proves
// nothing about it, so with no stall there is no estimate and no cap.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/link_speed_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LinkSpeedMemory.forget();
  });

  test('knows nothing until something goes wrong', () {
    expect(LinkSpeedMemory.kbps.value, isNull);
    expect(LinkSpeedMemory.sustainableKbps, isNull);
  });

  test('a stall sets the estimate, with a margin under it', () async {
    await LinkSpeedMemory.recordStall(10000);

    expect(LinkSpeedMemory.kbps.value, 10000);
    expect(LinkSpeedMemory.sustainableKbps, 7500);
  });

  test('a second stall is averaged, not trusted outright', () async {
    await LinkSpeedMemory.recordStall(10000);
    await LinkSpeedMemory.recordStall(4000);

    expect(LinkSpeedMemory.kbps.value, 7000);
  });

  test('a rate too low to be a link is ignored', () async {
    await LinkSpeedMemory.recordStall(100);

    expect(LinkSpeedMemory.kbps.value, isNull);
  });

  test('clean playback lifts the estimate', () async {
    await LinkSpeedMemory.recordStall(8000);
    await LinkSpeedMemory.recordSmooth();

    expect(LinkSpeedMemory.kbps.value, 10000);
  });

  test('clean playback with nothing known changes nothing', () async {
    await LinkSpeedMemory.recordSmooth();

    expect(LinkSpeedMemory.kbps.value, isNull);
  });

  test('enough clean playback forgets the cap altogether', () async {
    await LinkSpeedMemory.recordStall(190000);
    await LinkSpeedMemory.recordSmooth();

    expect(LinkSpeedMemory.kbps.value, isNull,
        reason: 'nothing here needs more than the ceiling');
  });

  test('survives a restart', () async {
    await LinkSpeedMemory.recordStall(6000);
    LinkSpeedMemory.kbps.value = null;

    await LinkSpeedMemory.initialize();

    expect(LinkSpeedMemory.kbps.value, 6000);
  });
}
