import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/utils/url_validator.dart';
import '../models/radio_database.dart';
import '../models/radio_station.dart';

class SchemaValidationException implements Exception {
  SchemaValidationException(this.errors);
  final List<String> errors;
  @override
  String toString() => 'SchemaValidationException: ${errors.take(5).join('; ')}';
}

class ValidationResult {
  ValidationResult(this.errors, this.warnings, this.validStationIndexes);
  final List<String> errors;
  final List<String> warnings;
  final Set<int> validStationIndexes;
  bool get isValid => errors.isEmpty;
}

/// Parses and validates malaysia_radio.json (schema_version 1).
class JsonService {
  const JsonService({this.supportedSchemaVersion = AppConstants.supportedSchemaVersion});

  final int supportedSchemaVersion;

  static const _categories = {'rtm', 'commercial', 'internet'};
  static const _streamTypes = {'direct', 'web_player', 'unverified'};
  static const _formats = {'mp3', 'aac', 'aac+', 'he-aac', 'hls', 'm3u8', 'pls', 'm3u'};

  /// Validates the decoded JSON. Root-level problems are errors (database is
  /// rejected); individual broken stations are dropped with a warning.
  ValidationResult validate(Object? decoded) {
    final errors = <String>[];
    final warnings = <String>[];
    final valid = <int>{};
    if (decoded is! Map) {
      return ValidationResult(['Root mesti objek JSON'], warnings, valid);
    }
    final sv = decoded['schema_version'];
    if (sv is! int) {
      errors.add('schema_version mesti integer');
    } else if (sv < 1 || sv > supportedSchemaVersion) {
      errors.add('schema_version $sv tidak disokong (maks $supportedSchemaVersion)');
    }
    final v = decoded['version'];
    if (v is! int || v < 1) errors.add('version mesti integer >= 1');
    final lu = decoded['last_updated'];
    if (lu is! String || DateTime.tryParse(lu) == null) errors.add('last_updated mesti tarikh ISO-8601');
    final stations = decoded['stations'];
    if (stations is! List) {
      errors.add('stations mesti senarai');
      return ValidationResult(errors, warnings, valid);
    }
    if (stations.isEmpty) errors.add('stations tidak boleh kosong');

    final ids = <String>{};
    for (var i = 0; i < stations.length; i++) {
      final problems = _validateStation(stations[i], ids);
      if (problems.isEmpty) {
        valid.add(i);
      } else {
        warnings.add('stations[$i]: ${problems.join(', ')}');
      }
    }
    if (stations.isNotEmpty && valid.length * 2 < stations.length) {
      errors.add('Terlalu banyak stesen tidak sah (${stations.length - valid.length}/${stations.length})');
    }
    return ValidationResult(errors, warnings, valid);
  }

  List<String> _validateStation(Object? s, Set<String> ids) {
    final p = <String>[];
    if (s is! Map) return ['bukan objek'];
    final id = s['id'];
    if (id is! String || id.trim().isEmpty) {
      p.add('id kosong');
    } else if (!ids.add(id)) {
      p.add('id berulang "$id"');
    }
    final name = s['name'];
    if (name is! String || name.trim().isEmpty) p.add('name kosong');
    if (!_categories.contains(s['category'])) p.add('category tidak sah');
    final type = s['stream_type'];
    if (!_streamTypes.contains(type)) p.add('stream_type tidak sah');
    final langs = s['languages'];
    if (langs != null && (langs is! List || langs.any((e) => e is! String))) p.add('languages tidak sah');
    for (final key in const ['logo', 'website']) {
      final val = s[key];
      if (val != null && !UrlValidator.isValidHttpUrl(val is String ? val : null)) {
        p.add('$key bukan URL http/https');
      }
    }
    final streams = s['streams'];
    if (streams is! List) {
      p.add('streams mesti senarai');
    } else {
      for (final st in streams) {
        if (st is! Map || !UrlValidator.isValidHttpUrl(st['url'] is String ? st['url'] as String : null)) {
          p.add('URL strim tidak sah');
          break;
        }
        final f = st['format'];
        if (f is! String || !_formats.contains(f.toLowerCase())) {
          p.add('format strim tidak sah');
          break;
        }
      }
      if (type == 'direct' && streams.isEmpty) p.add('direct tanpa strim');
    }
    if (type == 'web_player' && s['website'] == null) p.add('web_player tanpa website');
    return p;
  }

  /// Parses [source] text into a [RadioDatabase]. Throws [FormatException]
  /// for invalid JSON and [SchemaValidationException] for schema errors.
  RadioDatabase parse(String source, {DatabaseSource from = DatabaseSource.bundled, DateTime? fetchedAt}) {
    final decoded = jsonDecode(source);
    final result = validate(decoded);
    if (!result.isValid) throw SchemaValidationException(result.errors);
    final map = decoded as Map;
    final raw = map['stations'] as List;
    final stations = <RadioStation>[
      for (var i = 0; i < raw.length; i++)
        if (result.validStationIndexes.contains(i)) RadioStation.fromJson(Map<String, dynamic>.from(raw[i] as Map)),
    ];
    return RadioDatabase(
      schemaVersion: map['schema_version'] as int,
      version: map['version'] as int,
      lastUpdated: DateTime.tryParse(map['last_updated'] as String),
      verificationCheckedAt: DateTime.tryParse((map['verification_checked_at'] ?? '').toString()),
      stations: stations,
      source: from,
      fetchedAt: fetchedAt,
    );
  }

  DatabaseVersionInfo parseVersion(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('version.json bukan objek');
    return DatabaseVersionInfo.fromJson(Map<String, dynamic>.from(decoded));
  }
}
