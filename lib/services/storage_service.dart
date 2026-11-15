import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import 'player_types.dart';

/// Local persistence: user preferences (SharedPreferences) and the cached
/// database file (app documents directory). Nothing sensitive is stored.
class StorageService implements StreamPreferenceStore {
  StorageService(this._prefs, {Future<Directory> Function()? directoryProvider})
      : _dirProvider = directoryProvider ?? getApplicationSupportDirectory;

  final SharedPreferences _prefs;
  final Future<Directory> Function() _dirProvider;

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  static const _kTheme = 'theme_mode';
  static const _kAutoReconnect = 'auto_reconnect';
  static const _kAutoPlayLast = 'auto_play_last';
  static const _kShowNowPlaying = 'show_now_playing';
  static const _kFavorites = 'favorites';
  static const _kRecent = 'recent';
  static const _kLastStation = 'last_station';
  static const _kVolume = 'volume';
  static const _kEtag = 'db_etag';
  static const _kLastCheck = 'db_last_check';

  // ---- settings ----
  String get themeMode => _prefs.getString(_kTheme) ?? 'system';
  Future<void> setThemeMode(String v) => _prefs.setString(_kTheme, v);

  bool get autoReconnect => _prefs.getBool(_kAutoReconnect) ?? true;
  Future<void> setAutoReconnect(bool v) => _prefs.setBool(_kAutoReconnect, v);

  bool get autoPlayLast => _prefs.getBool(_kAutoPlayLast) ?? false;
  Future<void> setAutoPlayLast(bool v) => _prefs.setBool(_kAutoPlayLast, v);

  /// Show song / programme text from the stream metadata (RDS-like).
  bool get showNowPlaying => _prefs.getBool(_kShowNowPlaying) ?? true;
  Future<void> setShowNowPlaying(bool v) => _prefs.setBool(_kShowNowPlaying, v);

  double get volume => (_prefs.getDouble(_kVolume) ?? 1.0).clamp(0.0, 1.0);
  Future<void> setVolume(double v) => _prefs.setDouble(_kVolume, v.clamp(0.0, 1.0));

  // ---- favorites / recent ----
  List<String> get favorites => _prefs.getStringList(_kFavorites) ?? const [];
  Future<void> setFavorites(List<String> ids) => _prefs.setStringList(_kFavorites, ids);

  List<String> get recent => _prefs.getStringList(_kRecent) ?? const [];
  Future<void> setRecent(List<String> ids) => _prefs.setStringList(_kRecent, ids);

  String? get lastStationId => _prefs.getString(_kLastStation);
  Future<void> setLastStationId(String id) => _prefs.setString(_kLastStation, id);

  // ---- per-station working stream (device-specific) ----
  @override
  String? preferredStream(String stationId) => _prefs.getString('pref_stream_$stationId');
  @override
  Future<void> setPreferredStream(String stationId, String url) =>
      _prefs.setString('pref_stream_$stationId', url);

  // ---- database cache ----
  String? get databaseEtag => _prefs.getString(_kEtag);
  Future<void> setDatabaseEtag(String? v) =>
      v == null ? _prefs.remove(_kEtag) : _prefs.setString(_kEtag, v);

  DateTime? get lastDatabaseCheck {
    final ms = _prefs.getInt(_kLastCheck);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastDatabaseCheck(DateTime t) => _prefs.setInt(_kLastCheck, t.millisecondsSinceEpoch);

  Future<File> _dbFile() async {
    final dir = await _dirProvider();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${AppConstants.cachedDatabaseFile}');
  }

  Future<String?> readCachedDatabase() async {
    try {
      final f = await _dbFile();
      if (!await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Atomic write: a failed/partial write never corrupts the existing copy.
  Future<void> writeCachedDatabase(String json) async {
    final f = await _dbFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }

  Future<DateTime?> cachedDatabaseModified() async {
    try {
      final f = await _dbFile();
      return await f.exists() ? await f.lastModified() : null;
    } catch (_) {
      return null;
    }
  }
}
