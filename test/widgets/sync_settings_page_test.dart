// test/widgets/sync_settings_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/pages/settings/sync_settings_page.dart';

void main() {
  testWidgets('Simkl is offered; Trakt is switched off, not removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SyncSettingsPage()),
    );
    await tester.pump();

    // Simkl is the one sync service this app offers (see
    // docs/SYNC_AND_BACKUP.md): its card renders.
    expect(find.text('Simkl'), findsWidgets);

    // Trakt's card is a decision, not a deletion -- `TraktService` and
    // `TraktSettings` stay in the codebase, but nothing of theirs reaches
    // this page while `_traktSyncEnabled` is false.
    expect(find.text('Trakt.tv'), findsNothing);
  });
}
