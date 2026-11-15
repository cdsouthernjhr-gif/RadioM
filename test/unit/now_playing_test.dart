import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/core/utils/now_playing.dart';

void main() {
  group('NowPlaying.parse (ICY StreamTitle, RDS RadioText equivalent)', () {
    test('splits "Artist - Title"', () {
      final np = NowPlaying.parse('Siti Nurhaliza - Cindai')!;
      expect(np.artist, 'Siti Nurhaliza');
      expect(np.title, 'Cindai');
      expect(np.headline, 'Cindai');
      expect(np.text, 'Siti Nurhaliza - Cindai');
    });

    test('accepts en/em dash separators and keeps hyphens inside words', () {
      expect(NowPlaying.parse('Dato\' Sri Siti – Bukan Cinta Biasa')!.title, 'Bukan Cinta Biasa');
      expect(NowPlaying.parse('Search — Isabella')!.artist, 'Search');
      final np = NowPlaying.parse('Jay-Z')!;
      expect(np.artist, isNull);
      expect(np.text, 'Jay-Z');
    });

    test('text without separator is kept as programme text', () {
      final np = NowPlaying.parse('Berita Nasional 8 Pagi')!;
      expect(np.artist, isNull);
      expect(np.headline, 'Berita Nasional 8 Pagi');
    });

    test('drops empty and placeholder values', () {
      for (final v in [null, '', '   ', '-', ' - ', 'Unknown', 'untitled', 'N/A', 'LIVE', 'Iklan', 'advertisement']) {
        expect(NowPlaying.parse(v), isNull, reason: '"$v"');
      }
    });

    test('drops a title that only repeats the station name (PS, not RadioText)', () {
      expect(NowPlaying.parse('HITZ', stationName: 'HITZ'), isNull);
      expect(NowPlaying.parse('Nasional FM', stationName: 'Nasional FM'), isNull);
      expect(NowPlaying.parse('Nasional FM - Lagu Baru', stationName: 'Nasional FM')!.title, 'Lagu Baru');
    });

    test('drops bare URLs', () {
      expect(NowPlaying.parse('https://www.example.com'), isNull);
      expect(NowPlaying.parse('www.radio.my'), isNull);
    });

    test('one-sided "Artist - " keeps the meaningful part', () {
      expect(NowPlaying.parse('Unknown - Cindai')!.text, 'Cindai');
      expect(NowPlaying.parse('Faizal Tahir - unknown')!.text, 'Faizal Tahir');
    });

    test('sanitises untrusted server text', () {
      final np = NowPlaying.parse('  Ella\u0000 -\tPergi\u202E   Untuk\nKembali ')!;
      expect(np.text, 'Ella - Pergi Untuk Kembali');
      expect(np.text.codeUnits.any((c) => c < 0x20), isFalse);
      expect(NowPlaying.parse("'Quoted - Song'")!.title, 'Song');
    });

    test('caps very long text', () {
      final np = NowPlaying.parse('A' * 500)!;
      expect(np.text.length, NowPlaying.maxLength);
      expect(np.text.endsWith('…'), isTrue);
    });

    test('equality is by text (avoids redundant UI / notification updates)', () {
      expect(NowPlaying.parse('A - B'), NowPlaying.parse('A  -  B'));
    });
  });
}
