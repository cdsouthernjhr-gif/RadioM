import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/now_playing.dart';
import '../../core/utils/platform_bridge.dart';
import '../../core/utils/url_validator.dart';
import '../../data/models/radio_station.dart';
import '../../services/player_types.dart';
import '../../services/storage_service.dart';
import '../home/library_controller.dart';

enum PlayRequestResult { started, openedWebPlayer, failed }

class PlayerController extends ChangeNotifier {
  PlayerController({required this.playback, required this.storage, required this.library}) {
    playback.autoReconnect = storage.autoReconnect;
    _sub = playback.snapshots.listen((s) {
      _snapshot = s;
      notifyListeners();
    });
    _snapshot = playback.snapshot;
    _volume = storage.volume;
    unawaited(playback.setVolume(_volume));
  }

  final RadioPlayback playback;
  final StorageService storage;
  final LibraryController library;
  late final StreamSubscription<PlayerSnapshot> _sub;
  late PlayerSnapshot _snapshot;
  late double _volume;
  bool _askedNotification = false;

  PlayerSnapshot get snapshot => _snapshot;
  RadioStation? get station => _snapshot.station;
  PlayerStatus get status => _snapshot.status;
  double get volume => _volume;

  /// Stream metadata (RDS-like RadioText); null if hidden or not sent.
  NowPlaying? get nowPlaying => storage.showNowPlaying ? _snapshot.nowPlaying : null;
  bool get isActive => _snapshot.station != null && _snapshot.status != PlayerStatus.idle;

  set autoReconnect(bool v) => playback.autoReconnect = v;

  Future<PlayRequestResult> play(RadioStation station) async {
    if (!station.canPlayInApp) {
      return await openWebPlayer(station) ? PlayRequestResult.openedWebPlayer : PlayRequestResult.failed;
    }
    if (!_askedNotification) {
      _askedNotification = true;
      unawaited(PlatformBridge.requestNotificationPermission());
    }
    unawaited(library.addRecent(station.id));
    await playback.playStation(station);
    return PlayRequestResult.started;
  }

  Future<void> toggle() async {
    if (_snapshot.status == PlayerStatus.playing || _snapshot.status.isBusy) {
      await playback.pause();
    } else if (_snapshot.station != null) {
      await playback.resume();
    }
  }

  Future<void> stop() => playback.stop();

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await playback.setVolume(_volume);
    await storage.setVolume(_volume);
  }

  Future<void> autoPlayLastIfEnabled() async {
    if (!storage.autoPlayLast) return;
    final id = storage.lastStationId;
    final st = id == null ? null : library.byId(id);
    if (st != null && st.canPlayInApp) await play(st);
  }

  /// Opens the broadcaster's official site in an external browser
  /// (falls back to an in-app browser view). HTML is never played as audio.
  static Future<bool> openWebPlayer(RadioStation station) async {
    final uri = UrlValidator.parseHttpUrl(station.website);
    if (uri == null) return false;
    for (final mode in const [LaunchMode.externalApplication, LaunchMode.inAppBrowserView, LaunchMode.platformDefault]) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
