import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Simulates an Android TV remote (D-pad + DPAD_CENTER/select).
void main() {
  String? focusedStationKey() {
    final f = FocusManager.instance.primaryFocus?.context;
    if (f == null) return null;
    String? key;
    f.visitAncestorElements((e) {
      final k = e.widget.key;
      if (k is ValueKey<String> && (k.value.contains('-'))) {
        key = k.value;
        return false;
      }
      return true;
    });
    return key;
  }

  testWidgets('TV layout uses NavigationRail and D-pad moves focus between cards', (tester) async {
    final h = await pumpApp(tester, isTv: true, size: const Size(1280, 720));
    expect(find.byKey(const Key('nav-rail')), findsOneWidget);
    expect(find.byKey(const Key('nav-bar')), findsNothing);

    // First card is autofocused for remote users.
    expect(focusedStationKey(), 'Featured Radio-rtm-nasional-fm');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focusedStationKey(), 'Featured Radio-astro-hitz');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedStationKey(), startsWith('National Radio-'));

    // DPAD_CENTER / select activates the focused card.
    final target = focusedStationKey()!.split('National Radio-').last;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(h.playback.calls, ['play:$target']);
    expect(find.byKey(const Key('mini-player-title')), findsOneWidget);

    // Enter key also activates.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.playback.calls.length, 2);

    // Left from the first column reaches the navigation rail.
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
    }
    final railHasFocus = find
        .descendant(of: find.byKey(const Key('nav-rail')), matching: find.byWidgetPredicate((w) => w is Focus))
        .evaluate()
        .any((e) => (e.widget as Focus).focusNode?.hasFocus ?? Focus.of(e).hasFocus);
    expect(railHasFocus, isTrue);
  });

  testWidgets('media play/pause key toggles playback', (tester) async {
    final h = await pumpApp(tester, isTv: true, size: const Size(1280, 720));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(h.playback.calls, ['play:rtm-nasional-fm']);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pumpAndSettle();
    expect(h.playback.calls.last, 'pause');
  });
}
