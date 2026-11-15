import 'dart:typed_data';

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

  testWidgets('TV box: pressing the playing station again opens the full player (logo)', (tester) async {
    final h = await pumpApp(tester, isTv: true, size: const Size(1280, 720));
    final card = find.byKey(const ValueKey('Featured Radio-rtm-nasional-fm'));
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(h.playback.calls, ['play:rtm-nasional-fm']);
    expect(find.byKey(const Key('full-player-title')), findsNothing);

    // Second press (remote OK button) on the same station.
    await tester.tap(card);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('full-player-title')), findsOneWidget);
    expect(h.playback.calls, ['play:rtm-nasional-fm'], reason: 'stream is not restarted');
    await tester.tap(find.byKey(const Key('full-stop')));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('paused station: second press resumes and opens the full player', (tester) async {
    final h = await pumpApp(tester);
    final card = find.byKey(const ValueKey('Featured Radio-rtm-nasional-fm'));
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mini-play-pause')));
    await tester.pumpAndSettle();
    expect(h.playback.calls.last, 'pause');
    await tester.tap(card);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.playback.calls.last, 'resume');
    expect(find.byKey(const Key('full-player-title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('full-stop')));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('full player volume up/down and mute buttons', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('Featured Radio-rtm-nasional-fm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mini-player-title')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('volume-down')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.player.volume, 0.9);
    expect(find.text('90%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('volume-mute')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.player.muted, isTrue);
    expect(h.playback.volume, 0.0);
    expect(find.text('Bisu'), findsOneWidget);
    await tester.tap(find.byKey(const Key('volume-up')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.player.muted, isFalse);
    expect(h.player.volume, 1.0);
    await tester.tap(find.byKey(const Key('full-stop')));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('custom logo is shown and can be deleted from the full player', (tester) async {
    final h = await pumpApp(tester);
    await tester.runAsync(() => h.logos.setFromBytes('rtm-nasional-fm',
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0])));
    await tester.pump();
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            (w.image is FileImage || (w.image is ResizeImage && (w.image as ResizeImage).imageProvider is FileImage))),
        findsWidgets);

    await tester.tap(find.byKey(const ValueKey('Featured Radio-rtm-nasional-fm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mini-player-title')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const Key('full-logo-edit')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Menggunakan logo anda sendiri'), findsOneWidget);
    expect(find.byKey(const Key('logo-pick-device')), findsOneWidget);
    expect(find.byKey(const Key('logo-from-url')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('logo-delete')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.logos.has('rtm-nasional-fm'), isFalse);
    expect(find.text('Menggunakan logo asal'), findsOneWidget);
    expect(find.byKey(const Key('logo-delete')), findsNothing);
  });
}
