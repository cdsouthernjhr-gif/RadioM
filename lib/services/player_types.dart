import '../core/utils/now_playing.dart';
import '../data/models/radio_station.dart';

enum PlayerStatus { idle, loading, buffering, playing, paused, reconnecting, error, offline }

extension PlayerStatusLabel on PlayerStatus {
  String get label => switch (this) {
        PlayerStatus.idle => 'Sedia',
        PlayerStatus.loading => 'Memuatkan…',
        PlayerStatus.buffering => 'Buffering…',
        PlayerStatus.playing => 'Playing',
        PlayerStatus.paused => 'Paused',
        PlayerStatus.reconnecting => 'Menyambung semula…',
        PlayerStatus.error => 'Error',
        PlayerStatus.offline => 'Offline',
      };

  bool get isBusy =>
      this == PlayerStatus.loading || this == PlayerStatus.buffering || this == PlayerStatus.reconnecting;
}

class PlayerSnapshot {
  const PlayerSnapshot({
    this.station,
    this.status = PlayerStatus.idle,
    this.message,
    this.streamUrl,
    this.formatLabel,
    this.reconnectAttempt = 0,
    this.nowPlaying,
  });

  final RadioStation? station;
  final PlayerStatus status;
  final String? message;
  final String? streamUrl;
  final String? formatLabel;
  final int reconnectAttempt;

  /// Song / programme text from the stream's own metadata (ICY StreamTitle),
  /// the internet-radio counterpart of FM RDS RadioText. Null when the
  /// station sends none.
  final NowPlaying? nowPlaying;

  PlayerSnapshot copyWith({
    RadioStation? station,
    PlayerStatus? status,
    String? message,
    bool clearMessage = false,
    String? streamUrl,
    String? formatLabel,
    int? reconnectAttempt,
    NowPlaying? nowPlaying,
    bool clearNowPlaying = false,
  }) =>
      PlayerSnapshot(
        station: station ?? this.station,
        status: status ?? this.status,
        message: clearMessage ? null : (message ?? this.message),
        streamUrl: streamUrl ?? this.streamUrl,
        formatLabel: formatLabel ?? this.formatLabel,
        reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
        nowPlaying: clearNowPlaying ? null : (nowPlaying ?? this.nowPlaying),
      );
}

/// Playback abstraction used by the UI (lets widget tests use a fake).
abstract class RadioPlayback {
  PlayerSnapshot get snapshot;
  Stream<PlayerSnapshot> get snapshots;
  double get volume;
  bool autoReconnect = true;

  Future<void> playStation(RadioStation station);
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double v);
}

/// Remembers which stream URL last worked for a station so the next start
/// skips streams known to fail on this device (e.g. HTTPS endpoints that time
/// out on Android 6.0).
abstract class StreamPreferenceStore {
  String? preferredStream(String stationId);
  Future<void> setPreferredStream(String stationId, String url);
}
