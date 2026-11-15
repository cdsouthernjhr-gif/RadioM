import 'radio_station.dart';

enum DatabaseSource { remote, cache, bundled }

class RadioDatabase {
  const RadioDatabase({
    required this.schemaVersion,
    required this.version,
    required this.lastUpdated,
    required this.stations,
    this.verificationCheckedAt,
    this.source = DatabaseSource.bundled,
    this.fetchedAt,
  });

  final int schemaVersion;
  final int version;
  final DateTime? lastUpdated;
  final DateTime? verificationCheckedAt;
  final List<RadioStation> stations;
  final DatabaseSource source;
  final DateTime? fetchedAt;

  RadioDatabase copyWith({DatabaseSource? source, DateTime? fetchedAt}) => RadioDatabase(
        schemaVersion: schemaVersion,
        version: version,
        lastUpdated: lastUpdated,
        verificationCheckedAt: verificationCheckedAt,
        stations: stations,
        source: source ?? this.source,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  int get directCount => stations.where((s) => s.streamType == StreamType.direct).length;
  int get unverifiedCount => stations.where((s) => s.streamType == StreamType.unverified).length;
  int get webPlayerCount => stations.where((s) => s.streamType == StreamType.webPlayer).length;
}

/// Lightweight manifest (data/version.json).
class DatabaseVersionInfo {
  const DatabaseVersionInfo({required this.schemaVersion, required this.version, this.lastUpdated});
  final int schemaVersion;
  final int version;
  final DateTime? lastUpdated;

  factory DatabaseVersionInfo.fromJson(Map<String, dynamic> j) => DatabaseVersionInfo(
        schemaVersion: (j['schema_version'] as num?)?.toInt() ?? 0,
        version: (j['version'] as num?)?.toInt() ?? 0,
        lastUpdated: DateTime.tryParse((j['last_updated'] ?? '').toString()),
      );
}
