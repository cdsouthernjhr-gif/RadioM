import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:malaysia_radio_player/data/models/radio_station.dart';
import 'package:malaysia_radio_player/data/repositories/radio_repository.dart';
import 'package:malaysia_radio_player/data/services/download_service.dart';
import 'package:malaysia_radio_player/services/connectivity_service.dart';
import 'package:malaysia_radio_player/services/player_types.dart';
import 'package:malaysia_radio_player/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();
String bundledDb() => File('assets/data/malaysia_radio.json').readAsStringSync();

/// Returns a copy of the sample DB with a different version.
String sampleWithVersion(int v) {
  final m = jsonDecode(fixture('sample_db.json')) as Map<String, dynamic>;
  m['version'] = v;
  return jsonEncode(m);
}

Future<StorageService> makeStorage({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final dir = await Directory.systemTemp.createTemp('mrp_test');
  return StorageService(await SharedPreferences.getInstance(), directoryProvider: () async => dir);
}

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({this.online = true});
  bool online;
  final _c = StreamController<bool>.broadcast();
  @override
  bool get isOnline => online;
  @override
  Stream<bool> get onlineChanges => _c.stream;
  @override
  Future<bool> checkNow() async => online;
  void set(bool v) {
    online = v;
    _c.add(v);
  }

  @override
  void dispose() => _c.close();
}

class FakePlayback implements RadioPlayback {
  final _c = StreamController<PlayerSnapshot>.broadcast();
  PlayerSnapshot _s = const PlayerSnapshot();
  final List<String> calls = [];
  double _volume = 1;

  @override
  bool autoReconnect = true;
  @override
  PlayerSnapshot get snapshot => _s;
  @override
  Stream<PlayerSnapshot> get snapshots => _c.stream;
  @override
  double get volume => _volume;

  void emit(PlayerSnapshot s) {
    _s = s;
    _c.add(s);
  }

  @override
  Future<void> playStation(RadioStation station) async {
    calls.add('play:${station.id}');
    emit(PlayerSnapshot(station: station, status: PlayerStatus.playing));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(_s.copyWith(status: PlayerStatus.paused));
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    emit(_s.copyWith(status: PlayerStatus.playing));
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emit(_s.copyWith(status: PlayerStatus.idle));
  }

  @override
  Future<void> setVolume(double v) async => _volume = v;
}

/// Mock HTTP server for version.json + database.
class MockRemote {
  MockRemote({this.version = 5, this.dbBody, this.failDb = false, this.failVersion = false, this.etag});
  int version;
  String? dbBody;
  bool failDb;
  bool failVersion;
  String? etag;
  int dbRequests = 0;
  int versionRequests = 0;

  http.Client client() => MockClient((req) async {
        if (req.url.path.endsWith('version.json')) {
          versionRequests++;
          if (failVersion) throw const SocketException('offline');
          return http.Response(jsonEncode({'schema_version': 1, 'version': version}), 200);
        }
        dbRequests++;
        if (failDb) return http.Response('error', 500);
        if (etag != null && req.headers['If-None-Match'] == etag) return http.Response('', 304);
        return http.Response.bytes(utf8.encode(dbBody ?? sampleWithVersion(version)), 200,
            headers: {if (etag != null) 'etag': etag!, 'content-type': 'application/json; charset=utf-8'});
      });

  DownloadService service() => DownloadService(
        client: client(),
        databaseUrl: 'https://raw.example.com/data/malaysia_radio.json',
        versionUrl: 'https://raw.example.com/data/version.json',
        maxRetries: 2,
        retryDelay: Duration.zero,
      );
}

RadioRepository makeRepository(StorageService storage, MockRemote remote, {String? bundled}) => RadioRepository(
      storage: storage,
      downloadService: remote.service(),
      assetLoader: (_) async => bundled ?? sampleWithVersion(1),
    );
