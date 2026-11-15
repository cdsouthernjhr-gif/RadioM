import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/url_validator.dart';

/// Thrown when an image cannot be used as a station logo. [message] is
/// user-facing (Malay).
class LogoException implements Exception {
  LogoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// User-chosen station logos, stored as files in the app's private support
/// directory (`custom_logos/<stationId>_<millis>.<ext>`).
///
/// Images are untrusted input: only PNG / JPEG / GIF / WebP (detected from the
/// file's magic bytes, not its name), at most [maxBytes], and the image must
/// decode. A new file name is used on every change so cached images refresh.
class CustomLogoStore extends ChangeNotifier {
  CustomLogoStore({
    Future<Directory> Function()? baseDirectory,
    http.Client? client,
    Future<bool> Function(Uint8List bytes)? canDecode,
  })  : _baseDir = baseDirectory ?? getApplicationSupportDirectory,
        _client = client,
        _canDecode = canDecode ?? _decodes;

  static const maxBytes = 3 * 1024 * 1024;

  final Future<Directory> Function() _baseDir;
  final http.Client? _client;
  final Future<bool> Function(Uint8List) _canDecode;
  final Map<String, File> _files = {};
  Directory? _dir;

  /// Custom logo file for [stationId], or null.
  File? fileFor(String stationId) => _files[_safeId(stationId)];
  bool has(String stationId) => _files.containsKey(_safeId(stationId));
  int get count => _files.length;

  Future<Directory> _logoDir() async {
    final d = _dir ??= Directory('${(await _baseDir()).path}${Platform.pathSeparator}custom_logos');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Loads the existing logos from disk (call once at start-up).
  Future<void> init() async {
    try {
      final d = await _logoDir();
      final newest = <String, File>{};
      await for (final e in d.list()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        final m = RegExp(r'^([a-z0-9-]+)_(\d+)\.(png|jpg|gif|webp)$').firstMatch(name);
        if (m == null) continue;
        final id = m.group(1)!;
        final prev = newest[id];
        if (prev == null || prev.path.compareTo(e.path) < 0) newest[id] = e;
      }
      _files
        ..clear()
        ..addAll(newest);
    } catch (_) {
      // Storage unavailable: run without custom logos.
    }
    notifyListeners();
  }

  /// Detects the image format from its first bytes. Returns the file
  /// extension, or null for anything that is not PNG / JPEG / GIF / WebP.
  static String? detectFormat(Uint8List b) {
    bool starts(List<int> sig, [int offset = 0]) {
      if (b.length < offset + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (b[offset + i] != sig[i]) return false;
      }
      return true;
    }

    if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'png';
    if (starts(const [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits)) return 'gif';
    if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8)) return 'webp';
    return null;
  }

  static Future<bool> _decodes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _safeId(String id) => id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');

  /// Validates and saves [bytes] as the logo for [stationId].
  Future<void> setFromBytes(String stationId, Uint8List bytes) async {
    if (bytes.isEmpty) throw LogoException('Fail gambar kosong.');
    if (bytes.length > maxBytes) throw LogoException('Gambar terlalu besar (maksimum 3 MB).');
    final ext = detectFormat(bytes);
    if (ext == null) throw LogoException('Format tidak disokong. Gunakan PNG, JPG, GIF atau WebP.');
    if (!await _canDecode(bytes)) throw LogoException('Gambar rosak atau tidak dapat dibaca.');
    final id = _safeId(stationId);
    final d = await _logoDir();
    final file = File('${d.path}${Platform.pathSeparator}${id}_${DateTime.now().millisecondsSinceEpoch}.$ext');
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    final old = _files[id];
    _files[id] = file;
    if (old != null && old.path != file.path) await _deleteQuietly(old);
    notifyListeners();
  }

  /// Downloads an image from an http(s) [url] and saves it as the logo.
  Future<void> setFromUrl(String stationId, String url) async {
    final uri = UrlValidator.parseHttpUrl(url.trim());
    if (uri == null) throw LogoException('URL tidak sah. Hanya alamat http:// atau https://.');
    final client = _client;
    if (client == null) throw LogoException('Muat turun tidak tersedia.');
    final req = http.Request('GET', uri)..headers['User-Agent'] = AppConstants.userAgent;
    late http.StreamedResponse res;
    try {
      res = await client.send(req).timeout(AppConstants.httpTimeout);
    } on TimeoutException {
      throw LogoException('Pelayan gambar tidak menjawab.');
    } catch (_) {
      throw LogoException('Gambar tidak dapat dimuat turun.');
    }
    if (res.statusCode != 200) {
      unawaited(res.stream.listen(null, onError: (Object _) {}).cancel());
      throw LogoException('Pelayan gambar menjawab HTTP ${res.statusCode}.');
    }
    if ((res.contentLength ?? 0) > maxBytes) {
      unawaited(res.stream.listen(null, onError: (Object _) {}).cancel());
      throw LogoException('Gambar terlalu besar (maksimum 3 MB).');
    }
    final buf = BytesBuilder(copy: false);
    try {
      await for (final chunk in res.stream.timeout(AppConstants.httpTimeout)) {
        buf.add(chunk);
        if (buf.length > maxBytes) throw LogoException('Gambar terlalu besar (maksimum 3 MB).');
      }
    } on LogoException {
      rethrow;
    } catch (_) {
      throw LogoException('Muat turun gambar terputus.');
    }
    await setFromBytes(stationId, buf.takeBytes());
  }

  /// Removes the custom logo for [stationId] (the original logo returns).
  Future<void> remove(String stationId) async {
    final f = _files.remove(_safeId(stationId));
    if (f == null) return;
    await _deleteQuietly(f);
    notifyListeners();
  }

  /// Removes every custom logo.
  Future<void> clearAll() async {
    final all = _files.values.toList();
    _files.clear();
    for (final f in all) {
      await _deleteQuietly(f);
    }
    notifyListeners();
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
