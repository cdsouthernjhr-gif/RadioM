import '../../core/utils/url_validator.dart';

/// How a station can be listened to.
enum StreamType {
  /// At least one direct audio stream (MP3/AAC/HLS) was verified.
  direct,

  /// Only an official web player / website is available. Never played as audio.
  webPlayer,

  /// Streams exist but have not been verified. Must not be shown as "on air".
  unverified;

  static StreamType parse(String? v) {
    switch (v) {
      case 'direct':
        return StreamType.direct;
      case 'web_player':
        return StreamType.webPlayer;
      default:
        return StreamType.unverified;
    }
  }

  String get jsonValue => switch (this) {
        StreamType.direct => 'direct',
        StreamType.webPlayer => 'web_player',
        StreamType.unverified => 'unverified',
      };
}

enum StationCategory {
  rtm,
  commercial,
  internet;

  static StationCategory? parse(String? v) {
    for (final c in StationCategory.values) {
      if (c.name == v) return c;
    }
    return null;
  }
}

enum StreamFormat {
  mp3,
  aac,
  aacPlus,
  hls,
  playlist,
  unknown;

  static StreamFormat parse(String? v) {
    switch (v?.toLowerCase()) {
      case 'mp3':
        return StreamFormat.mp3;
      case 'aac':
        return StreamFormat.aac;
      case 'aac+':
      case 'he-aac':
        return StreamFormat.aacPlus;
      case 'hls':
      case 'm3u8':
        return StreamFormat.hls;
      case 'pls':
      case 'm3u':
        return StreamFormat.playlist;
      default:
        return StreamFormat.unknown;
    }
  }

  String get label => switch (this) {
        StreamFormat.mp3 => 'MP3',
        StreamFormat.aac => 'AAC',
        StreamFormat.aacPlus => 'AAC+',
        StreamFormat.hls => 'HLS',
        StreamFormat.playlist => 'Playlist',
        StreamFormat.unknown => '?',
      };
}

class Frequency {
  const Frequency({required this.area, required this.mhz});
  final String area;
  final String mhz;

  factory Frequency.fromJson(Map<String, dynamic> j) =>
      Frequency(area: (j['area'] ?? '').toString(), mhz: (j['mhz'] ?? '').toString());

  Map<String, dynamic> toJson() => {'area': area, 'mhz': mhz};

  @override
  String toString() => area.isEmpty ? '$mhz MHz' : '$mhz MHz ($area)';
}

class StreamSource {
  const StreamSource({
    required this.url,
    required this.format,
    this.bitrate,
    this.verificationStatus = 'untested',
    this.verificationDetail,
    this.checkedAt,
  });

  final String url;
  final StreamFormat format;
  final int? bitrate;
  final String verificationStatus; // verified | failed | untested
  final String? verificationDetail;
  final DateTime? checkedAt;

  bool get isVerified => verificationStatus == 'verified';
  bool get isFailed => verificationStatus == 'failed';

  factory StreamSource.fromJson(Map<String, dynamic> j) {
    final v = j['verification'];
    final vm = v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
    return StreamSource(
      url: (j['url'] as String).trim(),
      format: StreamFormat.parse(j['format'] as String?),
      bitrate: (j['bitrate'] as num?)?.toInt(),
      verificationStatus: (vm['status'] as String?) ?? 'untested',
      verificationDetail: vm['detail'] as String?,
      checkedAt: DateTime.tryParse((vm['checked_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'format': format.name,
        if (bitrate != null) 'bitrate': bitrate,
        'verification': {
          'status': verificationStatus,
          if (verificationDetail != null) 'detail': verificationDetail,
          if (checkedAt != null) 'checked_at': checkedAt!.toIso8601String(),
        },
      };
}

class RadioStation {
  const RadioStation({
    required this.id,
    required this.name,
    required this.category,
    required this.streamType,
    this.network,
    this.state,
    this.languages = const [],
    this.frequencies = const [],
    this.logo,
    this.website,
    this.streams = const [],
    this.featured = false,
    this.tags = const [],
    this.statusNote,
  });

  final String id;
  final String name;
  final StationCategory category;
  final StreamType streamType;
  final String? network;
  final String? state;
  final List<String> languages;
  final List<Frequency> frequencies;
  final String? logo;
  final String? website;
  final List<StreamSource> streams;
  final bool featured;
  final List<String> tags;
  final String? statusNote;

  bool get isNational => state == null;

  /// Streams ordered by preference: verified first, then untested; failed last.
  List<StreamSource> get playableStreams => [
        ...streams.where((s) => s.isVerified),
        ...streams.where((s) => !s.isVerified && !s.isFailed),
      ];

  bool get canPlayInApp => streamType != StreamType.webPlayer && playableStreams.isNotEmpty;

  String? get primaryFrequency => frequencies.isEmpty ? null : frequencies.first.toString();

  /// Lenient parser; schema validation happens in JsonService beforehand.
  factory RadioStation.fromJson(Map<String, dynamic> j) {
    final streams = <StreamSource>[];
    for (final s in (j['streams'] as List? ?? const [])) {
      if (s is Map && UrlValidator.isValidHttpUrl(s['url'] as String?)) {
        streams.add(StreamSource.fromJson(Map<String, dynamic>.from(s)));
      }
    }
    final logo = j['logo'] as String?;
    final website = j['website'] as String?;
    return RadioStation(
      id: j['id'] as String,
      name: (j['name'] as String).trim(),
      category: StationCategory.parse(j['category'] as String?) ?? StationCategory.internet,
      streamType: StreamType.parse(j['stream_type'] as String?),
      network: j['network'] as String?,
      state: (j['state'] as String?)?.trim().isEmpty ?? true ? null : (j['state'] as String).trim(),
      languages: (j['languages'] as List? ?? const []).map((e) => e.toString()).toList(),
      frequencies: (j['frequencies'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Frequency.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      logo: UrlValidator.isValidHttpUrl(logo) ? logo : null,
      website: UrlValidator.isValidHttpUrl(website) ? website : null,
      streams: streams,
      featured: j['featured'] == true,
      tags: (j['tags'] as List? ?? const []).map((e) => e.toString()).toList(),
      statusNote: j['status_note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'stream_type': streamType.jsonValue,
        'network': network,
        'state': state,
        'languages': languages,
        'frequencies': frequencies.map((f) => f.toJson()).toList(),
        'logo': logo,
        'website': website,
        'streams': streams.map((s) => s.toJson()).toList(),
        'featured': featured,
        'tags': tags,
        'status_note': statusNote,
      };

  @override
  bool operator ==(Object other) => other is RadioStation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
