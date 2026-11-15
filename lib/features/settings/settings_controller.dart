import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/network/logo_cache.dart';

import '../../services/storage_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this.storage);
  final StorageService storage;

  ThemeMode get themeMode => switch (storage.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode m) async {
    await storage.setThemeMode(m.name);
    notifyListeners();
  }

  bool get autoReconnect => storage.autoReconnect;
  Future<void> setAutoReconnect(bool v) async {
    await storage.setAutoReconnect(v);
    notifyListeners();
  }

  bool get autoPlayLast => storage.autoPlayLast;
  Future<void> setAutoPlayLast(bool v) async {
    await storage.setAutoPlayLast(v);
    notifyListeners();
  }

  /// Clears the logo image cache (memory + disk). The station database is kept.
  Future<void> clearCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      await DefaultCacheManager().emptyCache();
      await LogoCache.clear();
    } catch (_) {}
  }
}
