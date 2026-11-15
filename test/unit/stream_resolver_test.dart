import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:malaysia_radio_player/data/models/radio_station.dart';
import 'package:malaysia_radio_player/services/stream_resolver.dart';

void main() {
  group('classify', () {
    test('by extension / declared format', () {
      expect(StreamResolver.classify('https://x/live.mp3'), StreamKind.directAudio);
      expect(StreamResolver.classify('https://x/live.aac'), StreamKind.directAudio);
      expect(StreamResolver.classify('https://x/a/hls.m3u8'), StreamKind.hls);
      expect(StreamResolver.classify('http://x/listen.pls'), StreamKind.playlist);
      expect(StreamResolver.classify('http://x/radio.m3u'), StreamKind.playlist);
      expect(StreamResolver.classify('https://x/player.html'), StreamKind.webPage);
      expect(StreamResolver.classify('https://x/abc', StreamFormat.aac), StreamKind.directAudio);
      expect(StreamResolver.classify('https://x/abc'), StreamKind.unknown);
      expect(StreamResolver.classify('ftp://x/a.mp3'), StreamKind.unknown);
    });
    test('by content-type', () {
      expect(StreamResolver.classifyContentType('audio/mpeg'), StreamKind.directAudio);
      expect(StreamResolver.classifyContentType('audio/aacp'), StreamKind.directAudio);
      expect(StreamResolver.classifyContentType('text/html; charset=utf-8'), StreamKind.webPage);
      expect(StreamResolver.classifyContentType('application/vnd.apple.mpegurl'), StreamKind.hls);
      expect(StreamResolver.classifyContentType('audio/x-scpls'), StreamKind.playlist);
    });
  });

  group('playlist parsing', () {
    test('PLS', () {
      const pls = '[playlist]\nNumberOfEntries=1\nFile1=http://radio.example:8000/stream\nTitle1=x\n';
      expect(StreamResolver.parsePlaylist(pls).toString(), 'http://radio.example:8000/stream');
    });
    test('M3U skips comments and invalid lines', () {
      const m3u = '#EXTM3U\n#EXTINF:-1,Radio\nnot a url\nhttps://radio.example/live.aac\n';
      expect(StreamResolver.parsePlaylist(m3u).toString(), 'https://radio.example/live.aac');
    });
    test('rejects playlist with only non-http entries', () {
      expect(StreamResolver.parsePlaylist('File1=rtsp://x/y\n'), isNull);
    });
  });

  group('resolve', () {
    StreamSource src(String url, [String fmt = 'unknown']) =>
        StreamSource(url: url, format: StreamFormat.parse(fmt));

    test('expands a .pls playlist', () async {
      final r = StreamResolver(
          client: MockClient((_) async => http.Response('[playlist]\nFile1=http://a.example:8000/live\n', 200)));
      final res = await r.resolve(src('http://a.example/listen.pls', 'pls'));
      expect(res.uri.toString(), 'http://a.example:8000/live');
      expect(res.kind, StreamKind.directAudio);
    });

    test('never plays HTML: rejects a page served for an unknown URL', () async {
      final r = StreamResolver(
          client: MockClient((_) async =>
              http.Response('<html></html>', 200, headers: {'content-type': 'text/html'})));
      expect(() => r.resolve(src('https://a.example/player')), throwsA(isA<NotAudioException>()));
    });

    test('rejects .html URL without network', () async {
      final r = StreamResolver(client: MockClient((_) async => fail('no request expected')));
      expect(() => r.resolve(src('https://a.example/live.html')), throwsA(isA<NotAudioException>()));
    });

    test('HLS returned as hls without probing', () async {
      final r = StreamResolver(client: MockClient((_) async => fail('no request expected')));
      final res = await r.resolve(src('https://a.example/x/hls.m3u8', 'hls'));
      expect(res.kind, StreamKind.hls);
    });

    test('unknown URL with audio content-type is direct audio', () async {
      final r = StreamResolver(
          client: MockClient((_) async => http.Response('xx', 200, headers: {'content-type': 'audio/mpeg'})));
      final res = await r.resolve(src('https://a.example/stream'));
      expect(res.kind, StreamKind.directAudio);
    });

    test('HTTP error is reported', () async {
      final r = StreamResolver(client: MockClient((_) async => http.Response('', 404)));
      expect(() => r.resolve(src('https://a.example/stream')), throwsA(isA<NotAudioException>()));
    });
  });
}
