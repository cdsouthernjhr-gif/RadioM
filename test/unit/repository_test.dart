import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/data/models/radio_database.dart';
import 'package:malaysia_radio_player/data/repositories/radio_repository.dart';

import '../helpers.dart';

void main() {
  group('Offline database', () {
    test('falls back to bundled JSON when there is no cache', () async {
      final storage = await makeStorage();
      final repo = makeRepository(storage, MockRemote(), bundled: sampleWithVersion(1));
      final db = await repo.loadLocal();
      expect(db.source, DatabaseSource.bundled);
      expect(db.version, 1);
    });

    test('offline refresh keeps local data', () async {
      final storage = await makeStorage();
      final remote = MockRemote(version: 9);
      final repo = makeRepository(storage, remote);
      await repo.loadLocal();
      final r = await repo.refresh(online: false);
      expect(r.status, RefreshStatus.offline);
      expect(repo.current!.version, 1);
      expect(remote.dbRequests + remote.versionRequests, 0);
    });

    test('successful download is cached and used offline next launch', () async {
      final storage = await makeStorage();
      final remote = MockRemote(version: 9);
      final repo = makeRepository(storage, remote);
      await repo.loadLocal();
      final r = await repo.refresh();
      expect(r.status, RefreshStatus.updated);
      expect(repo.current!.version, 9);

      // New app start, no network.
      final repo2 = makeRepository(storage, MockRemote(failDb: true, failVersion: true));
      final db = await repo2.loadLocal();
      expect(db.version, 9);
      expect(db.source, DatabaseSource.cache);
    });

    test('failed download never deletes the cached database', () async {
      final storage = await makeStorage();
      await storage.writeCachedDatabase(sampleWithVersion(4));
      final repo = makeRepository(storage, MockRemote(version: 9, failDb: true));
      await repo.loadLocal();
      final r = await repo.refresh();
      expect(r.status, RefreshStatus.failed);
      expect(repo.current!.version, 4);
      expect(await storage.readCachedDatabase(), isNotNull);
      expect((await makeRepository(storage, MockRemote()).loadLocal()).version, 4);
    });

    test('corrupt cache falls back to bundled', () async {
      final storage = await makeStorage();
      await storage.writeCachedDatabase('{garbage');
      final db = await makeRepository(storage, MockRemote()).loadLocal();
      expect(db.source, DatabaseSource.bundled);
    });

    test('newer bundled DB (app update) wins over older cache', () async {
      final storage = await makeStorage();
      await storage.writeCachedDatabase(sampleWithVersion(2));
      final db = await makeRepository(storage, MockRemote(), bundled: sampleWithVersion(3)).loadLocal();
      expect(db.version, 3);
    });

    test('same version -> upToDate, no full download', () async {
      final storage = await makeStorage();
      final remote = MockRemote(version: 1);
      final repo = makeRepository(storage, remote);
      await repo.loadLocal();
      expect((await repo.refresh()).status, RefreshStatus.upToDate);
      expect(remote.dbRequests, 0);
      expect(storage.lastDatabaseCheck, isNotNull);
      expect(repo.shouldAutoRefresh(DateTime.now()), isFalse);
      expect(repo.shouldAutoRefresh(DateTime.now().add(const Duration(days: 1))), isTrue);
    });
  });
}
