import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/radio_database.dart';
import '../../data/models/radio_station.dart';
import '../../data/repositories/radio_repository.dart';
import '../../services/connectivity_service.dart';
import '../../services/storage_service.dart';

/// Station database + favorites + recently played.
class LibraryController extends ChangeNotifier {
  LibraryController({required this.repository, required this.storage, required this.connectivity}) {
    _favorites = List.of(storage.favorites);
    _recent = List.of(storage.recent);
  }

  final RadioRepository repository;
  final StorageService storage;
  final ConnectivityService connectivity;

  RadioDatabase? _db;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _lastMessage;
  late List<String> _favorites;
  late List<String> _recent;

  RadioDatabase? get database => _db;
  List<RadioStation> get stations => _db?.stations ?? const [];
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  String? get lastMessage => _lastMessage;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      _db = await repository.loadLocal();
      _error = null;
    } catch (e) {
      _error = 'Pangkalan data tidak dapat dimuatkan: $e';
    }
    _loading = false;
    notifyListeners();
    if (repository.shouldAutoRefresh(DateTime.now())) {
      unawaited(refresh());
    }
  }

  Future<RefreshResult> refresh({bool force = false}) async {
    if (_refreshing) return RefreshResult(RefreshStatus.upToDate, message: 'Sedang dikemas kini…');
    _refreshing = true;
    notifyListeners();
    final online = await connectivity.checkNow();
    final res = await repository.refresh(force: force, online: online);
    if (res.database != null) _db = res.database;
    _lastMessage = res.message;
    _refreshing = false;
    notifyListeners();
    return res;
  }

  RadioStation? byId(String id) => repository.byId(id);

  List<RadioStation> _resolve(List<String> ids) =>
      ids.map(byId).whereType<RadioStation>().toList(growable: false);

  // ---- favorites ----
  List<RadioStation> get favorites => _resolve(_favorites);
  bool isFavorite(String id) => _favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id);
    notifyListeners();
    await storage.setFavorites(_favorites);
  }

  /// Moves a favorite using ReorderableListView semantics.
  Future<void> reorderFavorite(int oldIndex, int newIndex) async {
    final visible = favorites.map((s) => s.id).toList();
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, visible.length - 1);
    final id = visible.removeAt(oldIndex);
    visible.insert(newIndex, id);
    // keep ids of stations missing from the current DB at the end
    _favorites = [...visible, ..._favorites.where((f) => !visible.contains(f))];
    notifyListeners();
    await storage.setFavorites(_favorites);
  }

  // ---- recent ----
  List<RadioStation> get recent => _resolve(_recent);

  Future<void> addRecent(String id) async {
    _recent.remove(id);
    _recent.insert(0, id);
    if (_recent.length > AppConstants.recentLimit) _recent = _recent.sublist(0, AppConstants.recentLimit);
    notifyListeners();
    await storage.setRecent(_recent);
    await storage.setLastStationId(id);
  }

  // ---- home sections ----
  List<RadioStation> get featured => stations.where((s) => s.featured).toList();
  List<RadioStation> get national =>
      stations.where((s) => s.category == StationCategory.rtm && s.state == null).toList();
  List<RadioStation> get stateRadio =>
      stations.where((s) => s.category == StationCategory.rtm && s.state != null).toList()
        ..sort((a, b) => a.state!.compareTo(b.state!));
  List<RadioStation> get commercial => stations.where((s) => s.category == StationCategory.commercial).toList();
  List<RadioStation> get internet => stations.where((s) => s.category == StationCategory.internet).toList();
}
