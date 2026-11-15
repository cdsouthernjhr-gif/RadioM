import '../../core/utils/text_utils.dart';
import '../../data/models/radio_station.dart';

enum SortOrder { az, za }

/// Pure filtering/sorting logic for the directory (unit-tested).
class StationFilter {
  const StationFilter({
    this.query = '',
    this.category,
    this.state,
    this.language,
    this.sort = SortOrder.az,
  });

  final String query;
  final StationCategory? category;
  final String? state; // '__national__' = national stations only
  final String? language;
  final SortOrder sort;

  static const national = '__national__';

  StationFilter copyWith({
    String? query,
    StationCategory? category,
    bool clearCategory = false,
    String? state,
    bool clearState = false,
    String? language,
    bool clearLanguage = false,
    SortOrder? sort,
  }) =>
      StationFilter(
        query: query ?? this.query,
        category: clearCategory ? null : (category ?? this.category),
        state: clearState ? null : (state ?? this.state),
        language: clearLanguage ? null : (language ?? this.language),
        sort: sort ?? this.sort,
      );

  bool matches(RadioStation s) {
    if (category != null && s.category != category) return false;
    if (state != null) {
      if (state == national) {
        if (s.state != null) return false;
      } else if (s.state != state) {
        return false;
      }
    }
    if (language != null && !s.languages.contains(language)) return false;
    final q = TextUtils.normalize(query);
    if (q.isNotEmpty) {
      final hay = TextUtils.normalize(
          [s.name, s.network ?? '', s.state ?? '', ...s.frequencies.map((f) => f.mhz), ...s.tags].join(' '));
      if (!hay.contains(q)) return false;
    }
    return true;
  }

  List<RadioStation> apply(Iterable<RadioStation> stations) {
    final list = stations.where(matches).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sort == SortOrder.az ? list : list.reversed.toList();
  }

  static List<String> statesOf(Iterable<RadioStation> s) =>
      (s.map((e) => e.state).whereType<String>().toSet().toList()..sort());

  static List<String> languagesOf(Iterable<RadioStation> s) =>
      (s.expand((e) => e.languages).toSet().toList()..sort());
}
