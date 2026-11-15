import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/utils/url_validator.dart';
import '../data/models/radio_station.dart';

enum StreamKind { directAudio, hls, playlist, webPage, unknown }

class NotAudioException implements Exception {
  NotAudioException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ResolvedStream {
  ResolvedStream(this.uri, this.kind, this.format);
  final Uri uri;
  final StreamKind kind;
  final StreamFormat format;
}

/// Distinguishes direct audio, HLS, playlists and HTML pages.
/// Playlists (.pls/.m3u) published by the broadcaster are expanded to the
/// first http(s) entry. HTML is never handed to the audio player.
/// No scraping, token extraction or access-control bypass is performed.
class StreamResolver {
  StreamResolver({required http.Client client}) : _client = client;
  final http.Client _client;

  static const _audioExt = ['.mp3', '.aac', '.m4a', '.ogg', '.opus', '.adts'];
  static const _htmlExt = ['.html', '.htm', '.php', '.aspx', '.jsp'];

  /// Classification from URL + declared format, without network access.
  static StreamKind classify(String url, [StreamFormat declared = StreamFormat.unknown]) {
    final uri = UrlValidator.parseHttpUrl(url);
    if (uri == null) return StreamKind.unknown;
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8') || declared == StreamFormat.hls) return StreamKind.hls;
    if (path.endsWith('.pls') || path.endsWith('.m3u') || declared == StreamFormat.playlist) {
      return StreamKind.playlist;
    }
    if (_htmlExt.any(path.endsWith)) return StreamKind.webPage;
    if (_audioExt.any(path.endsWith)) return StreamKind.directAudio;
    if (declared == StreamFormat.mp3 || declared == StreamFormat.aac || declared == StreamFormat.aacPlus) {
      return StreamKind.directAudio;
    }
    return StreamKind.unknown;
  }

  /// Classification from an HTTP Content-Type header.
  static StreamKind classifyContentType(String? contentType) {
    final ct = (contentType ?? '').toLowerCase();
    if (ct.isEmpty) return StreamKind.unknown;
    if (ct.contains('text/html') || ct.contains('application/xhtml')) return StreamKind.webPage;
    if (ct.contains('vnd.apple.mpegurl') || ct.contains('application/x-mpegurl')) return StreamKind.hls;
    if (ct.contains('audio/x-scpls') || ct.contains('audio/x-mpegurl') || ct.contains('audio/mpegurl')) {
      return StreamKind.playlist;
    }
    if (ct.startsWith('audio/') || ct.contains('application/ogg') || ct.contains('video/mp2t') ||
        ct.contains('application/octet-stream') || ct.contains('audio/aacp')) {
      return StreamKind.directAudio;
    }
    return StreamKind.unknown;
  }

  /// Extracts the first http(s) URL from PLS or M3U text.
  static Uri? parsePlaylist(String text) {
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('[')) continue;
      final m = RegExp(r'^File\d+\s*=\s*(.+)$', caseSensitive: false).firstMatch(line);
      final candidate = m != null ? m.group(1)!.trim() : line;
      final uri = UrlValidator.parseHttpUrl(candidate);
      if (uri != null) return uri;
    }
    return null;
  }

  Future<ResolvedStream> resolve(StreamSource source) async {
    final uri = UrlValidator.parseHttpUrl(source.url);
    if (uri == null) throw NotAudioException('URL tidak sah (hanya http/https dibenarkan)');
    final kind = classify(source.url, source.format);
    switch (kind) {
      case StreamKind.hls:
        return ResolvedStream(uri, StreamKind.hls, StreamFormat.hls);
      case StreamKind.directAudio:
        return ResolvedStream(uri, StreamKind.directAudio, source.format);
      case StreamKind.webPage:
        throw NotAudioException('URL ialah laman web, bukan strim audio');
      case StreamKind.playlist:
        return _expandPlaylist(uri);
      case StreamKind.unknown:
        return _probe(uri, source.format);
    }
  }

  Future<ResolvedStream> _expandPlaylist(Uri uri) async {
    final res = await _client
        .get(uri, headers: {'User-Agent': AppConstants.userAgent})
        .timeout(AppConstants.httpTimeout);
    if (res.statusCode != 200) throw NotAudioException('Playlist HTTP ${res.statusCode}');
    final body = res.bodyBytes.length > 65536 ? res.bodyBytes.sublist(0, 65536) : res.bodyBytes;
    final inner = parsePlaylist(utf8.decode(body, allowMalformed: true));
    if (inner == null) throw NotAudioException('Playlist tidak mengandungi URL strim');
    final innerKind = classify(inner.toString());
    if (innerKind == StreamKind.webPage || innerKind == StreamKind.playlist) {
      throw NotAudioException('Playlist menunjuk kepada kandungan bukan audio');
    }
    return ResolvedStream(inner, innerKind == StreamKind.hls ? StreamKind.hls : StreamKind.directAudio,
        innerKind == StreamKind.hls ? StreamFormat.hls : StreamFormat.unknown);
  }

  /// Reads only the response headers to decide what the URL serves.
  Future<ResolvedStream> _probe(Uri uri, StreamFormat declared) async {
    final req = http.Request('GET', uri)
      ..headers['User-Agent'] = AppConstants.userAgent
      ..headers['Icy-MetaData'] = '0';
    http.StreamedResponse? res;
    try {
      res = await _client.send(req).timeout(AppConstants.httpTimeout);
      final kind = classifyContentType(res.headers['content-type']);
      if (res.statusCode >= 400) throw NotAudioException('Pelayan strim HTTP ${res.statusCode}');
      switch (kind) {
        case StreamKind.webPage:
          throw NotAudioException('Pelayan memulangkan HTML, bukan audio');
        case StreamKind.playlist:
          return _expandPlaylist(uri);
        case StreamKind.hls:
          return ResolvedStream(uri, StreamKind.hls, StreamFormat.hls);
        case StreamKind.directAudio:
        case StreamKind.unknown:
          // Unknown content-types are passed to the player, which will report
          // a decode error if the data is not audio.
          return ResolvedStream(uri, StreamKind.directAudio, declared);
      }
    } finally {
      // Cancel the body download; only headers were needed.
      unawaited(res?.stream.listen((_) {}).cancel());
    }
  }
}
