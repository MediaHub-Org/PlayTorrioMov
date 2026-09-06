import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/iptv/favorite_channels_service.dart';
import 'package:playtorriomov/services/iptv/hardcoded_channels.dart';
import 'package:playtorriomov/widgets/iptv/iptv_channel_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FavoriteChannelsService.items.value = [];
  });

  testWidgets(
      'tapping the favorite heart toggles it without also opening the channel',
      (tester) async {
    var openTaps = 0;
    const channel = HardcodedChannel(
      id: 'test-channel',
      name: 'Test Channel',
      short: 'TC',
      category: 'Test',
      keywords: ['test'],
      gradient: [Colors.blue, Colors.red],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 300,
          child: IptvChannelCard(
            channel: channel,
            onTap: () => openTaps++,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(FavoriteChannelsService.isFavorite('test-channel'), isFalse);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(FavoriteChannelsService.isFavorite('test-channel'), isTrue,
        reason: 'tapping the heart should toggle the favorite');
    expect(openTaps, 0, reason: 'tapping the heart should NOT also open the channel');
  });
}
