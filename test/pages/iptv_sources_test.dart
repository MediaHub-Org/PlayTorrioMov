import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/pages/iptv/iptv_sources_page.dart';

void main() {
  group('IptvSourcesPage view toggle', () {
    testWidgets('shows one list at a time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IptvSourcesPage())),
      );
      await tester.pumpAndSettle();

      // Portals first; the playlists section sits behind the toggle.
      expect(find.textContaining('Generate Portals'), findsWidgets);
      expect(find.textContaining('Add M3U'), findsNothing);

      await tester.tap(find.textContaining('M3U').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Generate Portals'), findsNothing);
      expect(find.textContaining('Add M3U'), findsOneWidget);
    });
  });
}
