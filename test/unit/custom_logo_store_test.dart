import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:malaysia_radio_player/services/custom_logo_store.dart';

final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4]);
final jpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('logo_test'));
  tearDown(() async => dir.delete(recursive: true));

  CustomLogoStore make({http.Client? client, bool decodes = true}) => CustomLogoStore(
        baseDirectory: () async => dir,
        client: client,
        canDecode: (_) async => decodes,
      );

  test('detects image formats from magic bytes, not file names', () {
    expect(CustomLogoStore.detectFormat(png), 'png');
    expect(CustomLogoStore.detectFormat(jpg), 'jpg');
    expect(CustomLogoStore.detectFormat(Uint8List.fromList('GIF89a....'.codeUnits)), 'gif');
    expect(CustomLogoStore.detectFormat(Uint8List.fromList('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits)), 'webp');
    expect(CustomLogoStore.detectFormat(Uint8List.fromList('<svg xmlns=...'.codeUnits)), isNull);
    expect(CustomLogoStore.detectFormat(Uint8List.fromList('<html>'.codeUnits)), isNull);
    expect(CustomLogoStore.detectFormat(Uint8List(0)), isNull);
  });

  test('add, replace, persist across restart and delete a logo', () async {
    final s = make();
    await s.init();
    expect(s.has('rtm-nasional-fm'), isFalse);

    await s.setFromBytes('rtm-nasional-fm', png);
    final first = s.fileFor('rtm-nasional-fm')!;
    expect(first.existsSync(), isTrue);
    expect(first.path, endsWith('.png'));
    expect(await first.readAsBytes(), png);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await s.setFromBytes('rtm-nasional-fm', jpg); // replace
    final second = s.fileFor('rtm-nasional-fm')!;
    expect(second.path, isNot(first.path));
    expect(second.path, endsWith('.jpg'));
    expect(first.existsSync(), isFalse, reason: 'old file is removed');

    final restarted = make();
    await restarted.init();
    expect(restarted.fileFor('rtm-nasional-fm')!.path, second.path);
    expect(restarted.count, 1);

    await restarted.remove('rtm-nasional-fm');
    expect(restarted.has('rtm-nasional-fm'), isFalse);
    expect(second.existsSync(), isFalse);
  });

  test('rejects non-images, oversized and undecodable files', () async {
    final s = make();
    await s.init();
    await expectLater(s.setFromBytes('a', Uint8List.fromList('hello'.codeUnits)), throwsA(isA<LogoException>()));
    await expectLater(s.setFromBytes('a', Uint8List(0)), throwsA(isA<LogoException>()));
    final big = Uint8List(CustomLogoStore.maxBytes + 1)..setAll(0, png);
    await expectLater(s.setFromBytes('a', big), throwsA(isA<LogoException>()));
    final broken = make(decodes: false);
    await broken.init();
    await expectLater(broken.setFromBytes('a', png), throwsA(isA<LogoException>()));
    expect(s.count, 0);
  });

  test('station ids cannot escape the logo folder', () async {
    final s = make();
    await s.init();
    await s.setFromBytes('../../etc/passwd', png);
    final f = s.fileFor('../../etc/passwd')!;
    expect(f.parent.path, endsWith('custom_logos'));
    expect(f.uri.pathSegments.last.contains('/'), isFalse);
  });

  test('clearAll removes every custom logo', () async {
    final s = make();
    await s.init();
    await s.setFromBytes('a', png);
    await s.setFromBytes('b', jpg);
    await s.clearAll();
    expect(s.count, 0);
    expect(Directory('${dir.path}/custom_logos').listSync(), isEmpty);
  });

  group('from URL', () {
    test('downloads and saves a valid image', () async {
      final s = make(client: MockClient((r) async => http.Response.bytes(png, 200, headers: {'content-type': 'image/png'})));
      await s.init();
      await s.setFromUrl('hitz', 'https://example.com/logo.png');
      expect(s.has('hitz'), isTrue);
    });

    test('only http/https URLs are accepted', () async {
      final s = make(client: MockClient((r) async => http.Response.bytes(png, 200)));
      await s.init();
      for (final u in ['file:///sdcard/a.png', 'javascript:alert(1)', 'ftp://x/a.png', 'not a url', 'https://user:pw@x.com/a.png']) {
        await expectLater(s.setFromUrl('hitz', u), throwsA(isA<LogoException>()), reason: u);
      }
      expect(s.has('hitz'), isFalse);
    });

    test('HTTP errors and HTML pages are rejected', () async {
      final s404 = make(client: MockClient((r) async => http.Response('nope', 404)));
      await s404.init();
      await expectLater(s404.setFromUrl('a', 'https://x.com/a.png'), throwsA(isA<LogoException>()));
      final html = make(client: MockClient((r) async => http.Response('<html></html>', 200)));
      await html.init();
      await expectLater(html.setFromUrl('a', 'https://x.com/a.png'), throwsA(isA<LogoException>()));
    });

    test('download larger than 3 MB is aborted', () async {
      final big = Uint8List(CustomLogoStore.maxBytes + 10)..setAll(0, png);
      final s = make(client: MockClient((r) async => http.Response.bytes(big, 200)));
      await s.init();
      await expectLater(s.setFromUrl('a', 'https://x.com/a.png'), throwsA(isA<LogoException>()));
      expect(s.has('a'), isFalse);
    });
  });
}
