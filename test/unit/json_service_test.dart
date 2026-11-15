import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/data/models/radio_station.dart';
import 'package:malaysia_radio_player/data/services/json_service.dart';

import '../helpers.dart';

void main() {
  const svc = JsonService();

  group('JSON parsing', () {
    test('parses sample database fields', () {
      final db = svc.parse(fixture('sample_db.json'));
      expect(db.schemaVersion, 1);
      expect(db.version, 5);
      expect(db.lastUpdated, DateTime.utc(2026, 11, 15));
      expect(db.stations, hasLength(6));
      final n = db.stations.firstWhere((s) => s.id == 'rtm-nasional-fm');
      expect(n.category, StationCategory.rtm);
      expect(n.streamType, StreamType.direct);
      expect(n.streams.single.format, StreamFormat.mp3);
      expect(n.streams.single.isVerified, isTrue);
      expect(n.primaryFrequency, '88.5 MHz (Lembah Klang)');
      expect(n.isNational, isTrue);
      final era = db.stations.firstWhere((s) => s.id == 'astro-era');
      expect(era.streamType, StreamType.webPlayer);
      expect(era.canPlayInApp, isFalse);
    });

    test('bundled production database parses and validates', () {
      final db = svc.parse(bundledDb());
      expect(db.stations.length, greaterThan(50));
      expect(db.stations.map((s) => s.id).toSet().length, db.stations.length, reason: 'ids unique');
      for (final s in db.stations) {
        for (final st in s.streams) {
          expect(Uri.parse(st.url).scheme, anyOf('http', 'https'));
        }
        if (s.streamType == StreamType.direct) {
          expect(s.streams.any((x) => x.isVerified), isTrue, reason: '${s.id} direct must have verified stream');
        }
      }
    });

    test('invalid JSON text throws FormatException', () {
      expect(() => svc.parse('{not json'), throwsFormatException);
    });
  });

  group('Schema validation', () {
    Map<String, dynamic> base() => jsonDecode(fixture('sample_db.json')) as Map<String, dynamic>;

    test('valid sample passes', () {
      expect(svc.validate(base()).isValid, isTrue);
    });

    test('rejects unsupported schema_version', () {
      final m = base()..['schema_version'] = 99;
      final r = svc.validate(m);
      expect(r.isValid, isFalse);
      expect(r.errors.join(), contains('schema_version'));
      expect(() => svc.parse(jsonEncode(m)), throwsA(isA<SchemaValidationException>()));
    });

    test('rejects missing version / last_updated / stations', () {
      for (final key in ['version', 'last_updated', 'stations']) {
        final m = base()..remove(key);
        expect(svc.validate(m).isValid, isFalse, reason: key);
      }
    });

    test('rejects non-object root', () {
      expect(svc.validate([1, 2]).isValid, isFalse);
    });

    test('drops a station with a non-http stream URL but keeps others', () {
      final m = base();
      (m['stations'] as List)[0]['streams'][0]['url'] = 'ftp://bad/stream';
      final r = svc.validate(m);
      expect(r.isValid, isTrue);
      expect(r.warnings, hasLength(1));
      final db = svc.parse(jsonEncode(m));
      expect(db.stations.any((s) => s.id == 'rtm-nasional-fm'), isFalse);
    });

    test('drops javascript: website and duplicate ids', () {
      final m = base();
      final st = (m['stations'] as List);
      st[1]['website'] = 'javascript:alert(1)';
      st[2]['id'] = st[0]['id'];
      final r = svc.validate(m);
      expect(r.validStationIndexes.contains(1), isFalse);
      expect(r.validStationIndexes.contains(2), isFalse);
    });

    test('rejects web_player without website and direct without streams', () {
      final m = base();
      final st = (m['stations'] as List);
      st[3]['website'] = null; // ERA web_player
      st[0]['streams'] = []; // direct without streams
      final r = svc.validate(m);
      expect(r.validStationIndexes.containsAll([0, 3]), isFalse);
    });

    test('rejects database when most stations are invalid', () {
      final m = base();
      for (final s in (m['stations'] as List)) {
        s['category'] = 'bogus';
      }
      expect(svc.validate(m).isValid, isFalse);
    });
  });
}
