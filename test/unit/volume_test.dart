import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/features/home/library_controller.dart';
import 'package:malaysia_radio_player/features/player/player_controller.dart';

import '../helpers.dart';

void main() {
  Future<(PlayerController, FakePlayback)> make({double volume = 0.5}) async {
    final storage = await makeStorage(prefs: {'volume': volume});
    final lib = LibraryController(
      repository: makeRepository(storage, MockRemote(version: 1), bundled: fixture('sample_db.json')),
      storage: storage,
      connectivity: FakeConnectivity(),
    );
    final playback = FakePlayback();
    final pc = PlayerController(playback: playback, storage: storage, library: lib);
    await Future<void>.delayed(Duration.zero);
    return (pc, playback);
  }

  test('volume up / down in 10% steps, clamped to 0–100%', () async {
    final (pc, pb) = await make(volume: 0.5);
    await pc.volumeUp();
    expect(pc.volume, 0.6);
    expect(pb.volume, 0.6);
    for (var i = 0; i < 10; i++) {
      await pc.volumeUp();
    }
    expect(pc.volume, 1.0);
    for (var i = 0; i < 15; i++) {
      await pc.volumeDown();
    }
    expect(pc.volume, 0.0);
    expect(pc.storage.volume, 0.0, reason: 'volume is remembered');
  });

  test('mute silences the player and restores the previous volume', () async {
    final (pc, pb) = await make(volume: 0.7);
    await pc.toggleMute();
    expect(pc.muted, isTrue);
    expect(pb.volume, 0.0);
    expect(pc.volume, 0.7, reason: 'chosen level is kept while muted');
    await pc.toggleMute();
    expect(pc.muted, isFalse);
    expect(pb.volume, 0.7);
  });

  test('changing the volume while muted unmutes', () async {
    final (pc, pb) = await make(volume: 0.4);
    await pc.toggleMute();
    await pc.volumeUp();
    expect(pc.muted, isFalse);
    expect(pb.volume, 0.5);
  });

  test('unmuting at 0% restores an audible level', () async {
    final (pc, pb) = await make(volume: 0.0);
    await pc.toggleMute();
    await pc.toggleMute();
    expect(pc.muted, isFalse);
    expect(pb.volume, 0.5);
  });
}
