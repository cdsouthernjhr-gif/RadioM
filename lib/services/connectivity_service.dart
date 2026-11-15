import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether *any* network interface is up. This does not guarantee
/// internet reachability; the player still handles stream errors.
abstract class ConnectivityService {
  bool get isOnline;
  Stream<bool> get onlineChanges;
  Future<bool> checkNow();
  void dispose();
}

class PlusConnectivityService implements ConnectivityService {
  PlusConnectivityService({Connectivity? connectivity}) : _c = connectivity ?? Connectivity() {
    _sub = _c.onConnectivityChanged.listen(_update, onError: (_) {});
    checkNow();
  }

  final Connectivity _c;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  final _controller = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  void _update(List<ConnectivityResult> r) {
    final online = r.any((e) => e != ConnectivityResult.none);
    if (online != _online) {
      _online = online;
      _controller.add(online);
    }
  }

  @override
  Future<bool> checkNow() async {
    try {
      _update(await _c.checkConnectivity());
    } catch (_) {
      // Assume online if the platform check fails.
    }
    return _online;
  }

  @override
  void dispose() {
    _sub.cancel();
    _controller.close();
  }
}
