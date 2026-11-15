import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/core/utils/now_playing.dart';
import 'package:malaysia_radio_player/features/settings/settings_controller.dart';
import 'package:malaysia_radio_player/services/player_types.dart';
import 'package:provider/provider.dart';

import 'harness.dart';

void main() {
  testWidgets('home shows sections and tapping a card plays it with mini player', (tester) async {
    final h = await pumpApp(tester);
    expect(find.text('Featured Radio'), findsOneWidget);
    expect(find.text('National Radio'), findsOneWidget);
    expect(find.byKey(const Key('mini-player-title')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('Featured Radio-astro-hitz')));
    await tester.pumpAndSettle();
    expect(h.playback.calls, ['play:astro-hitz']);
    expect(find.byKey(const Key('mini-player-title')), findsOneWidget);
    expect(find.text('Playing'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-play-pause')));
    await tester.pumpAndSettle();
    expect(h.playback.calls.last, 'pause');
    expect(find.text('Paused'), findsOneWidget);

    h.playback.emit(h.playback.snapshot.copyWith(status: PlayerStatus.buffering));
    await tester.pump();
    await tester.pump();
    expect(find.text('Buffering…'), findsOneWidget);
    h.playback.emit(h.playback.snapshot.copyWith(status: PlayerStatus.offline));
    await tester.pump();
    await tester.pump();
    expect(find.text('Offline'), findsOneWidget);
    h.playback.emit(h.playback.snapshot.copyWith(status: PlayerStatus.error, message: 'x'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Error'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-stop')));
    await tester.pumpAndSettle();
    expect(h.playback.calls.last, 'stop');
  });

  testWidgets('full player opens and shows controls + volume', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('Featured Radio-rtm-nasional-fm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mini-player-title')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('full-player-title')), findsOneWidget);
    expect(find.byKey(const Key('volume-slider')), findsOneWidget);
    await tester.tap(find.byKey(const Key('full-play-pause')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.playback.calls.last, 'pause');
    await tester.drag(find.byKey(const Key('volume-slider')), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.player.volume, lessThan(0.2));
    // stop the infinite wave animation before teardown
    await tester.tap(find.byKey(const Key('full-stop')));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('RDS-style now playing: shown in mini + full player, hidden when turned off', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('Featured Radio-rtm-nasional-fm')));
    await tester.pumpAndSettle();
    // No metadata yet -> nothing shown.
    expect(find.byKey(const Key('mini-now-playing')), findsNothing);

    h.playback.emit(h.playback.snapshot.copyWith(nowPlaying: NowPlaying.parse('Siti Nurhaliza - Cindai')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Siti Nurhaliza - Cindai'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-player-title')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('now-playing-panel')), findsOneWidget);
    expect(find.text('KINI BERSIARAN'), findsOneWidget);
    expect(find.byKey(const Key('now-playing-title')), findsOneWidget);
    expect(find.text('Cindai'), findsOneWidget);
    expect(find.text('Siti Nurhaliza'), findsOneWidget);

    // Metadata change updates the panel.
    h.playback.emit(h.playback.snapshot.copyWith(nowPlaying: NowPlaying.parse('Berita Nasional')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Berita Nasional'), findsWidgets);
    expect(find.text('Cindai'), findsNothing);

    // Turning the setting off hides it everywhere.
    final ctx = tester.element(find.byKey(const Key('full-player-title')));
    await tester.runAsync(() => Provider.of<SettingsController>(ctx, listen: false).setShowNowPlaying(false));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('now-playing-panel')), findsNothing);
    expect(find.text('Berita Nasional'), findsNothing);

    await tester.tap(find.byKey(const Key('full-stop')));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
