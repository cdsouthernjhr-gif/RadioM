import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/network/http_client_factory.dart';
import 'core/utils/platform_bridge.dart';
import 'data/repositories/radio_repository.dart';
import 'data/services/download_service.dart';
import 'features/home/library_controller.dart';
import 'features/player/player_controller.dart';
import 'features/settings/settings_controller.dart';
import 'services/audio_service.dart';
import 'services/connectivity_service.dart';
import 'services/custom_logo_store.dart';
import 'services/storage_service.dart';
import 'services/stream_resolver.dart';

/// All long-lived services, created once at startup.
class AppServices {
  AppServices({
    required this.storage,
    required this.connectivity,
    required this.handler,
    required this.library,
    required this.settings,
    required this.player,
    required this.isTv,
    required this.logos,
  });

  final StorageService storage;
  final ConnectivityService connectivity;
  final RadioAudioHandler handler;
  final LibraryController library;
  final SettingsController settings;
  final PlayerController player;
  final bool isTv;
  final CustomLogoStore logos;

  Widget buildApp() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: library),
          ChangeNotifierProvider.value(value: player),
          ChangeNotifierProvider.value(value: logos),
        ],
        child: MalaysiaRadioApp(isTv: isTv),
      );
}

Future<AppServices> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HttpClientFactory.init();

  final storage = await StorageService.create();
  final connectivity = PlusConnectivityService();
  final client = HttpClientFactory.create();
  final logos = CustomLogoStore(client: client);
  await logos.init();

  final handler = await AudioService.init<RadioAudioHandler>(
    builder: () => RadioAudioHandler(
      resolver: StreamResolver(client: client),
      connectivity: connectivity,
      preferences: storage,
      // The user's own logo is shown in the notification / lock screen too.
      artUriFor: (st) => logos.fileFor(st.id)?.uri,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'my.radiom.malaysia_radio_player.playback',
      androidNotificationChannelName: 'Pemain Radio',
      androidNotificationChannelDescription: 'Kawalan main balik radio',
      androidNotificationIcon: 'drawable/ic_stat_radio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  final repository = RadioRepository(storage: storage, downloadService: DownloadService(client: client));
  final library = LibraryController(repository: repository, storage: storage, connectivity: connectivity);
  final settings = SettingsController(storage);
  final player = PlayerController(playback: handler, storage: storage, library: library);
  logos.addListener(handler.refreshMediaItem);
  final isTv = await PlatformBridge.isTv();
  return AppServices(
    storage: storage,
    connectivity: connectivity,
    handler: handler,
    library: library,
    settings: settings,
    player: player,
    isTv: isTv,
    logos: logos,
  );
}
