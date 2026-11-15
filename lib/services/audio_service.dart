import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../core/constants/app_constants.dart';
import '../data/models/radio_station.dart';
import 'connectivity_service.dart';
import 'player_types.dart';
import 'stream_resolver.dart';

/// Background radio player: just_audio (ExoPlayer) inside an audio_service
/// foreground service with a MediaSession (notification + lock screen
/// controls). Handles audio focus, "becoming noisy", stalls and reconnects.
class RadioAudioHandler extends BaseAudioHandler implements RadioPlayback {
  RadioAudioHandler({
    required StreamResolver resolver,
    required ConnectivityService connectivity,
    AudioPlayer? player,
  })  : _resolver = resolver,
        _connectivity = connectivity,
        _player = player ?? AudioPlayer(userAgent: AppConstants.userAgent) {
    _init();
  }

  final StreamResolver _resolver;
  final ConnectivityService _connectivity;
  final AudioPlayer _player;

  final _snapshots = StreamController<PlayerSnapshot>.broadcast();
  PlayerSnapshot _snapshot = const PlayerSnapshot();

  @override
  bool autoReconnect = true;

  /// True while the user wants audio (play pressed, not paused/stopped).
  bool _wantPlaying = false;
  int _attempt = 0;
  int _streamIndex = 0;
  int _session = 0; // increments for every new play request to cancel stale work
  Timer? _retryTimer;
  Timer? _stallTimer;
  StreamSubscription<bool>? _netSub;

  static const _maxReconnectAttempts = 8;
  static const _stallTimeout = Duration(seconds: 25);

  @override
  PlayerSnapshot get snapshot => _snapshot;
  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;
  @override
  double get volume => _player.volume;

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.becomingNoisyEventStream.listen((_) => pause()); // headphones unplugged
    } catch (_) {}

    _player.playbackEventStream.listen(_broadcastState, onError: _onPlayerError);
    _player.playerStateStream.listen(_onPlayerState, onError: (_) {});
    _netSub = _connectivity.onlineChanges.listen(_onConnectivity);
  }

  void _emit(PlayerSnapshot s) {
    _snapshot = s;
    if (!_snapshots.isClosed) _snapshots.add(s);
  }

  // ---------------- public API ----------------

  @override
  Future<void> playStation(RadioStation station) async {
    final session = ++_session;
    _retryTimer?.cancel();
    _wantPlaying = true;
    _attempt = 0;
    _streamIndex = 0;
    mediaItem.add(MediaItem(
      id: station.id,
      title: station.name,
      album: station.network ?? 'Malaysia Radio',
      artist: station.primaryFrequency ?? 'Radio Malaysia',
      artUri: station.logo == null ? null : Uri.tryParse(station.logo!),
    ));
    _emit(PlayerSnapshot(station: station, status: PlayerStatus.loading));
    await _start(station, session);
  }

  Future<void> _start(RadioStation station, int session) async {
    if (!await _connectivity.checkNow()) {
      _emit(_snapshot.copyWith(status: PlayerStatus.offline, message: 'Tiada sambungan internet'));
      return; // _onConnectivity resumes when back online
    }
    final streams = station.playableStreams;
    if (streams.isEmpty) {
      _wantPlaying = false;
      _emit(_snapshot.copyWith(status: PlayerStatus.error, message: 'Tiada strim audio untuk stesen ini'));
      return;
    }
    Object? lastError;
    for (var i = 0; i < streams.length; i++) {
      final idx = (_streamIndex + i) % streams.length;
      if (session != _session) return;
      try {
        final resolved = await _resolver.resolve(streams[idx]);
        if (session != _session) return;
        _emit(_snapshot.copyWith(
          status: PlayerStatus.loading,
          streamUrl: resolved.uri.toString(),
          formatLabel: resolved.format == StreamFormat.unknown ? streams[idx].format.label : resolved.format.label,
        ));
        final source = resolved.kind == StreamKind.hls
            ? HlsAudioSource(resolved.uri)
            : ProgressiveAudioSource(resolved.uri);
        await _player.setAudioSource(source, preload: true).timeout(const Duration(seconds: 30));
        if (session != _session) return;
        _streamIndex = idx;
        // play() completes only when playback pauses/stops, so don't await it.
        unawaited(_player.play().catchError((Object e) => _onPlayerError(e)));
        return;
      } on PlayerInterruptedException {
        return; // superseded by another request
      } catch (e) {
        lastError = e;
      }
    }
    if (session != _session) return;
    _handleFailure(station, session, lastError);
  }

  void _handleFailure(RadioStation station, int session, Object? error) {
    final reason = _describe(error);
    if (_wantPlaying && autoReconnect && _attempt < _maxReconnectAttempts) {
      _attempt++;
      final delay = Duration(seconds: math.min(30, 2 << (_attempt - 1)));
      _emit(_snapshot.copyWith(
          status: PlayerStatus.reconnecting,
          reconnectAttempt: _attempt,
          message: '$reason. Cuba semula dalam ${delay.inSeconds}s (cubaan $_attempt/$_maxReconnectAttempts)'));
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        if (session == _session && _wantPlaying) _start(station, session);
      });
    } else {
      _wantPlaying = false;
      _emit(_snapshot.copyWith(status: PlayerStatus.error, message: reason));
    }
  }

  String _describe(Object? e) {
    if (e == null) return 'Strim tidak dapat dimainkan';
    if (e is NotAudioException) return e.message;
    if (e is PlayerException) return 'Ralat pemain (${e.code}): ${e.message ?? 'format/sambungan'}';
    if (e is TimeoutException) return 'Sambungan tamat masa';
    final detail = e.toString();
    return 'Ralat sambungan strim (${detail.length > 120 ? detail.substring(0, 120) : detail})';
  }

  @override
  Future<void> resume() async {
    final st = _snapshot.station;
    if (st == null) return;
    if (_player.audioSource == null || _snapshot.status == PlayerStatus.error ||
        _snapshot.status == PlayerStatus.offline) {
      return playStation(st);
    }
    _wantPlaying = true;
    // Live radio: reconnect to the live edge instead of resuming stale buffer.
    if (_player.processingState == ProcessingState.idle) return playStation(st);
    unawaited(_player.play());
  }

  @override
  Future<void> pause() async {
    _wantPlaying = false;
    _retryTimer?.cancel();
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _session++;
    _wantPlaying = false;
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    await _player.stop();
    _emit(_snapshot.copyWith(status: PlayerStatus.idle, clearMessage: true));
    await super.stop();
  }

  @override
  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));

  // ---------------- audio_service callbacks (notification / lock screen) ----------------
  @override
  Future<void> play() => resume();

  @override
  Future<void> onTaskRemoved() => stop();

  // ---------------- internal listeners ----------------

  void _onPlayerState(PlayerState state) {
    final st = _snapshot.station;
    if (st == null) return;
    final ps = state.processingState;
    if (ps == ProcessingState.buffering || ps == ProcessingState.loading) {
      if (_snapshot.status != PlayerStatus.reconnecting) {
        _emit(_snapshot.copyWith(status: ps == ProcessingState.loading ? PlayerStatus.loading : PlayerStatus.buffering));
      }
      _armStallWatchdog();
    } else if (ps == ProcessingState.ready) {
      _stallTimer?.cancel();
      if (state.playing) {
        _attempt = 0;
        _emit(_snapshot.copyWith(status: PlayerStatus.playing, reconnectAttempt: 0, clearMessage: true));
      } else if (_snapshot.status != PlayerStatus.idle) {
        _emit(_snapshot.copyWith(status: PlayerStatus.paused));
      }
    } else if (ps == ProcessingState.completed && _wantPlaying) {
      // A live stream should never "complete": the server closed the connection.
      _handleFailure(st, _session, Exception('Strim terputus'));
    }
  }

  void _armStallWatchdog() {
    _stallTimer?.cancel();
    if (!_wantPlaying) return;
    final session = _session;
    _stallTimer = Timer(_stallTimeout, () {
      final st = _snapshot.station;
      if (st != null && session == _session && _wantPlaying &&
          _player.processingState != ProcessingState.ready) {
        _handleFailure(st, session, TimeoutException('buffering terlalu lama'));
      }
    });
  }

  void _onPlayerError(Object e, [StackTrace? _]) {
    final st = _snapshot.station;
    if (st == null) return;
    if (!_connectivity.isOnline) {
      _emit(_snapshot.copyWith(status: PlayerStatus.offline, message: 'Sambungan terputus'));
      return;
    }
    // Try the next stream for this station on the following attempt.
    _streamIndex++;
    _handleFailure(st, _session, e);
  }

  void _onConnectivity(bool online) {
    final st = _snapshot.station;
    if (st == null) return;
    if (!online) {
      if (_wantPlaying) {
        _emit(_snapshot.copyWith(status: PlayerStatus.offline, message: 'Sambungan internet terputus'));
      }
    } else if (_wantPlaying && autoReconnect &&
        (_snapshot.status == PlayerStatus.offline || _snapshot.status == PlayerStatus.error ||
            _snapshot.status == PlayerStatus.reconnecting)) {
      _attempt = 0;
      _retryTimer?.cancel();
      final session = ++_session;
      _emit(_snapshot.copyWith(status: PlayerStatus.reconnecting, message: 'Internet kembali, menyambung semula…'));
      _start(st, session);
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.play, MediaAction.pause, MediaAction.stop, MediaAction.playPause},
      androidCompactActionIndices: const [0, 1],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ));
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    await _netSub?.cancel();
    await _player.dispose();
    await _snapshots.close();
  }
}
