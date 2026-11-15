import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/data/services/download_service.dart';

import '../helpers.dart';

void main() {
  group('Download database', () {
    test('downloads when remote version is newer', () async {
      final remote = MockRemote(version: 7, etag: '"abc"');
      final res = await remote.service().fetchIfNewer(localVersion: 5);
      expect(res.outcome, DownloadOutcome.updated);
      expect(res.database!.version, 7);
      expect(res.etag, '"abc"');
      expect(remote.dbRequests, 1);
    });

    test('does NOT download full DB when version unchanged', () async {
      final remote = MockRemote(version: 5);
      final res = await remote.service().fetchIfNewer(localVersion: 5);
      expect(res.outcome, DownloadOutcome.sameVersion);
      expect(remote.versionRequests, 1);
      expect(remote.dbRequests, 0);
    });

    test('uses ETag (304 Not Modified) when version.json unavailable', () async {
      final remote = MockRemote(version: 9, etag: '"same"', failVersion: true);
      final res = await remote.service().fetchIfNewer(localVersion: 5, etag: '"same"');
      expect(res.outcome, DownloadOutcome.notModified);
    });

    test('server error -> failed after retries', () async {
      final remote = MockRemote(version: 9, failDb: true);
      final res = await remote.service().fetchIfNewer(localVersion: 1);
      expect(res.outcome, DownloadOutcome.failed);
      expect(remote.dbRequests, 2, reason: 'retried maxRetries times');
    });

    test('invalid JSON -> failed (never accepted)', () async {
      final remote = MockRemote(version: 9, dbBody: '{"schema_version": 1, "broken": ');
      final res = await remote.service().fetchIfNewer(localVersion: 1);
      expect(res.outcome, DownloadOutcome.failed);
    });

    test('schema-invalid JSON -> failed', () async {
      final remote = MockRemote(version: 9, dbBody: '{"schema_version": 42, "version": 9, "stations": []}');
      final res = await remote.service().fetchIfNewer(localVersion: 1);
      expect(res.outcome, DownloadOutcome.failed);
    });

    test('force downloads even if same version', () async {
      final remote = MockRemote(version: 5);
      final res = await remote.service().fetchIfNewer(localVersion: 5, force: true);
      expect(res.outcome, DownloadOutcome.updated);
    });

    test('version.json lies (says newer) but DB is same version -> sameVersion', () async {
      final remote = MockRemote(version: 6, dbBody: sampleWithVersion(5));
      final res = await remote.service().fetchIfNewer(localVersion: 5);
      expect(res.outcome, DownloadOutcome.sameVersion);
    });
  });
}
