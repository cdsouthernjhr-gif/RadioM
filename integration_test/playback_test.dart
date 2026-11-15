// On-device integration tests. Run on a real Android device or emulator:
//   flutter test integration_test/playback_test.dart -d <device>
//
// They use REAL network streams from the bundled database and the REAL
// just_audio/ExoPlayer + audio_service stack. Results are printed as
// "IT_RESULT ..." lines. Markers "IT_MARKER:<name>" let a host script
// (tool/ci_emulator_driver.sh) press HOME or toggle the network.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:malaysia_radio_player/bootstrap.dart';
import 'package:malaysia_radio_player/core/network/logo_cache.dart';
import 'package:malaysia_radio_player/data/models/radio_station.dart';
import 'package:malaysia_radio_player/services/player_types.dart';

const hostDriven = bool.fromEnvironment('HOST_DRIVER');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late AppServices app;

  Future<PlayerStatus> waitFor(bool Function(PlayerStatus) cond, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final s = app.handler.snapshot.status;
      if (cond(s)) return s;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return app.handler.snapshot.status;
  }

  RadioStation single(String id, bool Function(StreamSource) pick) {
    final st = app.library.byId(id)!;
    final s = st.streams.firstWhere(pick);
    return RadioStation(
      id: st.id,
      name: st.name,
      category: st.category,
      streamType: st.streamType,
      streams: [s],
      network: st.network,
    );
  }

  Future<void> expectPlays(String label, RadioStation station, {bool assertOk = true}) async {
    await app.handler.playStation(station);
    final s = await waitFor((s) => s == PlayerStatus.playing || s == PlayerStatus.error, const Duration(seconds: 45));
    var stable = s == PlayerStatus.playing;
    if (stable) {
      // Must keep playing (not drop to error) for 10 s.
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (app.handler.snapshot.status == PlayerStatus.error) stable = false;
      }
    }
    debugPrint('IT_RESULT test=$label station=${station.id} url=${station.streams.single.url} '
        'status=${app.handler.snapshot.status.name} stable=$stable msg=${app.handler.snapshot.message}');
    final msg = app.handler.snapshot.message;
    await app.handler.stop();
    if (assertOk) expect(stable, isTrue, reason: '$label ${station.id}: $msg');
  }

  setUpAll(() async {
    app = await bootstrap();
    await app.library.init();
  });

  testWidgets('app starts and loads the station database', (tester) async {
    await tester.pumpWidget(app.buildApp());
    await tester.pump(const Duration(seconds: 2));
    expect(app.library.stations.length, greaterThan(50));
    debugPrint('IT_RESULT test=database stations=${app.library.stations.length} '
        'direct=${app.library.database!.directCount} source=${app.library.database!.source.name}');
  });

  testWidgets('station logos load over HTTPS (Android 6 trust store)', (tester) async {
    var ok = 0, failed = 0;
    for (final st in app.library.stations.where((s) => s.logo != null)) {
      try {
        await LogoCache.instance.getSingleFile(st.logo!).timeout(const Duration(seconds: 20));
        ok++;
        debugPrint('IT_RESULT test=logo station=${st.id} ok=true');
      } catch (e) {
        failed++;
        final m = e.toString().replaceAll('\n', ' ');
        debugPrint('IT_RESULT test=logo station=${st.id} ok=false error=${m.length > 140 ? m.substring(0, 140) : m}');
      }
    }
    debugPrint('IT_RESULT test=logos ok=$ok failed=$failed');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('direct MP3 playback', (tester) async {
    await expectPlays('mp3', single('rtm-nasional-fm', (s) => s.format == StreamFormat.mp3));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('AAC playback over HTTPS (revma CDN)', (tester) async {
    await expectPlays('aac-revma-https', single('astro-hitz', (s) => s.url.startsWith('https://')));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('AAC (streamtheworld) playback', (tester) async {
    await expectPlays('aac-stw', single('rtm-traxx-fm', (s) => s.format == StreamFormat.aac));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('HLS playback over HTTPS (revma CDN)', (tester) async {
    await expectPlays(
        'hls-revma-https', single('astro-my', (s) => s.format == StreamFormat.hls && s.url.startsWith('https://')));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('HTTP (cleartext) Icecast playback', (tester) async {
    await expectPlays('http-icecast', single('net-kcfm', (s) => s.url.startsWith('http://')));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('HTTP fallback for revma CDN streams (Astro / Media Prima)', (tester) async {
    await expectPlays('aac-http-fallback', single('astro-hitz', (s) => s.url.startsWith('http://')));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('HLS over HTTP (revma CDN)', (tester) async {
    await expectPlays('hls-http', single('astro-my', (s) => s.format == StreamFormat.hls && s.url.startsWith('http://')));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('full station with stream fallback order plays (HITZ)', (tester) async {
    final st = app.library.byId('astro-hitz')!;
    await app.handler.playStation(st);
    final s = await waitFor((s) => s == PlayerStatus.playing, const Duration(seconds: 120));
    debugPrint('IT_RESULT test=station-fallback station=${st.id} status=${s.name} '
        'url=${app.handler.snapshot.streamUrl} msg=${app.handler.snapshot.message}');
    await app.handler.stop();
    expect(s, PlayerStatus.playing);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('background playback continues after HOME', (tester) async {
    await app.handler.playStation(app.library.byId('rtm-radio-klasik')!);
    expect(await waitFor((s) => s == PlayerStatus.playing, const Duration(seconds: 45)), PlayerStatus.playing);
    debugPrint('IT_MARKER:background_ready');
    // Host presses HOME now; wait until the activity is really backgrounded.
    var wentBackground = false;
    for (var i = 0; i < 60 && !wentBackground; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final st = WidgetsBinding.instance.lifecycleState;
      wentBackground = st == AppLifecycleState.paused || st == AppLifecycleState.hidden;
    }
    // Then audio must keep playing in the background for 20 s.
    var ok = true;
    for (var i = 0; i < 80; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (app.handler.snapshot.status != PlayerStatus.playing &&
          app.handler.snapshot.status != PlayerStatus.buffering) ok = false;
    }
    debugPrint('IT_RESULT test=background hostDriven=$hostDriven wentBackground=$wentBackground '
        'lifecycle=${WidgetsBinding.instance.lifecycleState?.name} ok=$ok status=${app.handler.snapshot.status.name}');
    await app.handler.stop();
    expect(ok, isTrue);
    if (hostDriven) expect(wentBackground, isTrue, reason: 'HOME was not pressed / app not backgrounded');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('network disconnect and reconnect', (tester) async {
    if (!hostDriven) {
      debugPrint('IT_RESULT test=network skipped=true reason=needs-host-driver');
      return;
    }
    app.handler.autoReconnect = true;
    await app.handler.playStation(app.library.byId('rtm-traxx-fm')!);
    expect(await waitFor((s) => s == PlayerStatus.playing, const Duration(seconds: 45)), PlayerStatus.playing);
    debugPrint('IT_MARKER:net_ready'); // host disables network
    final lost = await waitFor(
        (s) => s == PlayerStatus.offline || s == PlayerStatus.reconnecting || s == PlayerStatus.error,
        const Duration(seconds: 90));
    debugPrint('IT_MARKER:net_lost status=${lost.name}'); // host re-enables network
    final back = await waitFor((s) => s == PlayerStatus.playing, const Duration(seconds: 150));
    debugPrint('IT_RESULT test=network lost=${lost.name} recovered=${back.name} '
        'attempts=${app.handler.snapshot.reconnectAttempt}');
    await app.handler.stop();
    expect(lost, isNot(PlayerStatus.playing), reason: 'disconnect should be detected');
    expect(back, PlayerStatus.playing, reason: 'should auto-reconnect');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
