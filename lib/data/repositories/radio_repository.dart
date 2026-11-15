import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/app_constants.dart';
import '../models/radio_database.dart';
import '../models/radio_station.dart';
import '../services/download_service.dart';
import '../services/json_service.dart';
import '../../services/storage_service.dart';

enum RefreshStatus { updated, upToDate, offline, failed }

class RefreshResult {
  RefreshResult(this.status, {this.message, this.database});
  final RefreshStatus status;
  final String? message;
  final RadioDatabase? database;
}

/// Loads stations from (in order) the cached download, then the bundled
/// asset; refreshes from GitHub when a newer version is published.
/// The local database is never deleted when a download fails.
class RadioRepository {
  RadioRepository({
    required this.storage,
    required this.downloadService,
    this.jsonService = const JsonService(),
    Future<String> Function(String key)? assetLoader,
  }) : _assetLoader = assetLoader ?? rootBundle.loadString;

  final StorageService storage;
  final DownloadService downloadService;
  final JsonService jsonService;
  final Future<String> Function(String key) _assetLoader;

  RadioDatabase? _current;
  RadioDatabase? get current => _current;

  Future<RadioDatabase> loadLocal() async {
    RadioDatabase? cached;
    final text = await storage.readCachedDatabase();
    if (text != null) {
      try {
        cached = jsonService.parse(text,
            from: DatabaseSource.cache, fetchedAt: await storage.cachedDatabaseModified());
      } catch (_) {
        cached = null; // corrupt cache: ignore but keep file until a valid download replaces it
      }
    }
    RadioDatabase? bundled;
    try {
      bundled = jsonService.parse(await _assetLoader(AppConstants.bundledDatabaseAsset));
    } catch (_) {
      bundled = null;
    }
    // Prefer whichever is newer (an app update may ship a newer bundled DB).
    if (cached != null && (bundled == null || cached.version >= bundled.version)) {
      _current = cached;
    } else if (bundled != null) {
      _current = bundled;
    } else {
      throw StateError('Tiada pangkalan data tempatan yang sah');
    }
    return _current!;
  }

  bool shouldAutoRefresh(DateTime now) {
    final last = storage.lastDatabaseCheck;
    return last == null || now.difference(last) >= AppConstants.autoRefreshInterval;
  }

  Future<RefreshResult> refresh({bool force = false, bool online = true}) async {
    if (!online) {
      return RefreshResult(RefreshStatus.offline, message: 'Tiada sambungan internet. Menggunakan data tempatan.');
    }
    final local = _current;
    final res = await downloadService.fetchIfNewer(
      localVersion: local?.version,
      etag: storage.databaseEtag,
      force: force,
    );
    switch (res.outcome) {
      case DownloadOutcome.updated:
        try {
          await storage.writeCachedDatabase(res.body!);
          await storage.setDatabaseEtag(res.etag);
        } catch (_) {
          // Could not persist; still use the new data in memory.
        }
        await storage.setLastDatabaseCheck(DateTime.now());
        _current = res.database!.copyWith(source: DatabaseSource.remote);
        return RefreshResult(RefreshStatus.updated,
            message: 'Pangkalan data dikemas kini ke versi ${_current!.version}.', database: _current);
      case DownloadOutcome.notModified:
      case DownloadOutcome.sameVersion:
        await storage.setLastDatabaseCheck(DateTime.now());
        return RefreshResult(RefreshStatus.upToDate, message: 'Pangkalan data sudah terkini.', database: local);
      case DownloadOutcome.failed:
        return RefreshResult(RefreshStatus.failed,
            message: 'Gagal memuat turun pangkalan data. Data tempatan dikekalkan.', database: local);
    }
  }

  RadioStation? byId(String id) {
    for (final s in _current?.stations ?? const <RadioStation>[]) {
      if (s.id == id) return s;
    }
    return null;
  }
}
