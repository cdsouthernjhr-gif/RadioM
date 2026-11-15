import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('directory search, A-Z sort and favorites', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.text('Direktori'));
    await tester.pumpAndSettle();
    expect(find.text('6 stesen'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), 'kelantan');
    await tester.pumpAndSettle();
    expect(find.text('1 stesen'), findsOneWidget);
    expect(find.byKey(const ValueKey('dir-rtm-kelantan-fm')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), '');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('sort-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sort-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Z-A'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Komersial'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Komersial'));
    await tester.pumpAndSettle();
    expect(find.text('2 stesen'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('dir-astro-hitz')), matching: find.byIcon(Icons.favorite_border)));
    await tester.pumpAndSettle();
    expect(h.library.isFavorite('astro-hitz'), isTrue);

    await tester.tap(find.text('Kegemaran'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fav-astro-hitz')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fav-astro-hitz')));
    await tester.pumpAndSettle();
    expect(h.playback.calls, ['play:astro-hitz']);
  });

  testWidgets('web_player station is not played as audio', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.text('Direktori'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dir-astro-era')));
    await tester.pumpAndSettle();
    expect(h.playback.calls, isEmpty);
    expect(find.textContaining('ERA'), findsWidgets);
  });
}
