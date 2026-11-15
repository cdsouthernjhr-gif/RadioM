// Host-side integration test of the full data flow
// (download -> validate -> cache -> offline restart -> search).
// Device-level playback tests live in integration_test/.
import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/data/models/radio_database.dart';
import 'package:malaysia_radio_player/data/repositories/radio_repository.dart';
import 'package:malaysia_radio_player/features/directory/station_filter.dart';

import '../helpers.dart';

void main() {
  test('bundled DB -> remote update -> offline restart -> search', () async {
    final storage = await makeStorage();
    final bundled = bundledDb();
    final repo = makeRepository(storage, MockRemote(version: 1000), bundled: bundled);
    final first = await repo.loadLocal();
    expect(first.source, DatabaseSource.bundled);

    final r = await repo.refresh();
    expect(r.status, RefreshStatus.updated);
    expect(repo.current!.version, 1000);

    // Offline restart uses the cached copy.
    final offline = makeRepository(storage, MockRemote(failDb: true, failVersion: true), bundled: bundled);
    final db = await offline.loadLocal();
    expect(db.source, DatabaseSource.cache);
    expect((await offline.refresh(online: false)).status, RefreshStatus.offline);

    // Search on the real bundled data.
    final real = makeRepository(await makeStorage(), MockRemote(), bundled: bundled);
    final stations = (await real.loadLocal()).stations;
    expect(const StationFilter(query: 'nasional').apply(stations).map((s) => s.id), contains('rtm-nasional-fm'));
    expect(const StationFilter(state: 'Sabah').apply(stations).length, greaterThanOrEqualTo(3));
  });
}
