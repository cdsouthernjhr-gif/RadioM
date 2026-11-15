import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/app.dart';
import 'package:malaysia_radio_player/features/home/library_controller.dart';
import 'package:malaysia_radio_player/features/player/player_controller.dart';
import 'package:malaysia_radio_player/features/settings/settings_controller.dart';
import 'package:malaysia_radio_player/services/custom_logo_store.dart';
import 'package:provider/provider.dart';

import '../helpers.dart';

class Harness {
  Harness(this.library, this.player, this.playback, this.logos);
  final CustomLogoStore logos;
  final LibraryController library;
  final PlayerController player;
  final FakePlayback playback;
}

Future<Harness> pumpApp(WidgetTester tester, {bool isTv = false, Size size = const Size(400, 800)}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  late Harness h;
  await tester.runAsync(() async {
    final storage = await makeStorage(prefs: {'db_last_check': DateTime.now().millisecondsSinceEpoch});
    final lib = LibraryController(
      repository: makeRepository(storage, MockRemote(version: 1), bundled: fixture('sample_db.json')),
      storage: storage,
      connectivity: FakeConnectivity(),
    );
    await lib.init();
    final playback = FakePlayback();
    final player = PlayerController(playback: playback, storage: storage, library: lib);
    final logos = CustomLogoStore(
      baseDirectory: () async => Directory.systemTemp.createTemp('logos'),
      canDecode: (_) async => true,
    );
    await logos.init();
    h = Harness(lib, player, playback, logos);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SettingsController(storage)),
        ChangeNotifierProvider.value(value: lib),
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider.value(value: logos),
      ],
      child: MalaysiaRadioApp(isTv: isTv),
    ));
  });
  await tester.pumpAndSettle();
  return h;
}
