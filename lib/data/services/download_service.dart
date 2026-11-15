import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/network/retry.dart';
import '../models/radio_database.dart';
import 'json_service.dart';

enum DownloadOutcome { updated, notModified, sameVersion, failed }

class DownloadResult {
  DownloadResult(this.outcome, {this.body, this.database, this.etag, this.error});
  final DownloadOutcome outcome;
  final String? body;
  final RadioDatabase? database;
  final String? etag;
  final Object? error;
}

/// Downloads the remote database only when the remote version is newer.
///
/// Flow: GET version.json -> compare with local version -> GET full database
/// (with If-None-Match) -> validate. Any failure returns [DownloadOutcome.failed]
/// and the caller keeps the existing local database.
class DownloadService {
  DownloadService({
    required http.Client client,
    this.databaseUrl = AppConstants.remoteDatabaseUrl,
    this.versionUrl = AppConstants.remoteVersionUrl,
    this.jsonService = const JsonService(),
    this.timeout = AppConstants.httpTimeout,
    this.maxRetries = AppConstants.httpMaxRetries,
    this.retryDelay = const Duration(milliseconds: 800),
  }) : _client = client;

  final http.Client _client;
  final String databaseUrl;
  final String versionUrl;
  final JsonService jsonService;
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;

  Map<String, String> get _headers => {
        'User-Agent': AppConstants.userAgent,
        'Accept': 'application/json',
      };

  Future<DatabaseVersionInfo?> fetchRemoteVersion() async {
    try {
      final res = await withRetry(
        () => _client.get(Uri.parse(versionUrl), headers: _headers).timeout(timeout),
        maxAttempts: maxRetries,
        initialDelay: retryDelay,
      );
      if (res.statusCode != 200) return null;
      return jsonService.parseVersion(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null; // version.json is optional; fall back to full download.
    }
  }

  Future<DownloadResult> fetchIfNewer({int? localVersion, String? etag, bool force = false}) async {
    try {
      if (!force && localVersion != null) {
        final remote = await fetchRemoteVersion();
        if (remote != null && remote.version <= localVersion) {
          return DownloadResult(DownloadOutcome.sameVersion);
        }
      }
      final headers = Map<String, String>.from(_headers);
      if (!force && etag != null && etag.isNotEmpty) headers['If-None-Match'] = etag;
      final res = await withRetry(
        () async {
          final r = await _client.get(Uri.parse(databaseUrl), headers: headers).timeout(timeout);
          if (r.statusCode >= 500) throw HttpStatusException(r.statusCode, databaseUrl);
          return r;
        },
        maxAttempts: maxRetries,
        initialDelay: retryDelay,
      );
      if (res.statusCode == 304) return DownloadResult(DownloadOutcome.notModified, etag: etag);
      if (res.statusCode != 200) {
        return DownloadResult(DownloadOutcome.failed, error: HttpStatusException(res.statusCode, databaseUrl));
      }
      if (res.bodyBytes.length > AppConstants.maxDatabaseBytes) {
        return DownloadResult(DownloadOutcome.failed, error: const FormatException('Fail terlalu besar'));
      }
      final body = utf8.decode(res.bodyBytes);
      final db = jsonService.parse(body, from: DatabaseSource.remote, fetchedAt: DateTime.now());
      if (!force && localVersion != null && db.version <= localVersion) {
        return DownloadResult(DownloadOutcome.sameVersion, etag: res.headers['etag']);
      }
      return DownloadResult(DownloadOutcome.updated, body: body, database: db, etag: res.headers['etag']);
    } catch (e) {
      return DownloadResult(DownloadOutcome.failed, error: e);
    }
  }
}
