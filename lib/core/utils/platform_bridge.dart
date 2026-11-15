import 'package:flutter/services.dart';

/// Small native bridge implemented in MainActivity.kt.
/// Every Android-version-specific API is guarded on the native side.
class PlatformBridge {
  PlatformBridge._();
  static const _channel = MethodChannel('my.radiom/platform');

  static bool? _isTv;

  /// True on Android TV / TV boxes (UI_MODE_TYPE_TELEVISION or leanback feature).
  static Future<bool> isTv() async {
    if (_isTv != null) return _isTv!;
    try {
      _isTv = await _channel.invokeMethod<bool>('isTv') ?? false;
    } catch (_) {
      _isTv = false;
    }
    return _isTv!;
  }

  /// Requests POST_NOTIFICATIONS on Android 13+ (API 33). No-op on Android 6–12.
  static Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<int> sdkInt() async {
    try {
      return await _channel.invokeMethod<int>('sdkInt') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
