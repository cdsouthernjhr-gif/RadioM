import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/features/home/library_controller.dart';

import '../helpers.dart';

void main() {
  Future<LibraryController> make() async {
    final storage = await makeStorage(prefs: {'db_last_check': DateTime.now().millisecondsSinceEpoch});
    final lib = LibraryController(
      repository: makeRepository(storage, MockRemote(version: 1), bundled: fixture('sample_db.json')),
      storage: storage,
      connectivity: FakeConnectivity(),
    );
    await lib.init();
    return lib;
  }

  test('favorites: add, persist, reorder, remove', () async {
    final lib = await make();
    await lib.toggleFavorite('astro-hitz');
    await lib.toggleFavorite('rtm-nasional-fm');
    await lib.toggleFavorite('ai-fm');
    expect(lib.favorites.map((s) => s.id), ['astro-hitz', 'rtm-nasional-fm', 'ai-fm']);
    await lib.reorderFavorite(2, 0); // move ai-fm to top
    expect(lib.favorites.map((s) => s.id), ['ai-fm', 'astro-hitz', 'rtm-nasional-fm']);
    await lib.reorderFavorite(0, 3); // move to bottom (ReorderableListView semantics)
    expect(lib.favorites.map((s) => s.id), ['astro-hitz', 'rtm-nasional-fm', 'ai-fm']);
    expect(lib.storage.favorites, ['astro-hitz', 'rtm-nasional-fm', 'ai-fm']);
    await lib.toggleFavorite('astro-hitz');
    expect(lib.isFavorite('astro-hitz'), isFalse);
  });

  test('recently played is most-recent-first, de-duplicated and capped', () async {
    final lib = await make();
    await lib.addRecent('ai-fm');
    await lib.addRecent('astro-hitz');
    await lib.addRecent('ai-fm');
    expect(lib.recent.map((s) => s.id), ['ai-fm', 'astro-hitz']);
    expect(lib.storage.lastStationId, 'ai-fm');
  });

  test('home sections', () async {
    final lib = await make();
    expect(lib.featured.map((s) => s.id), containsAll(['rtm-nasional-fm', 'astro-hitz']));
    expect(lib.national.map((s) => s.id), containsAll(['rtm-nasional-fm', 'ai-fm']));
    expect(lib.stateRadio.map((s) => s.id), ['rtm-kelantan-fm']);
    expect(lib.commercial, hasLength(2));
    expect(lib.internet, hasLength(1));
  });
}
